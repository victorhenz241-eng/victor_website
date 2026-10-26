// media.swift — turns original photos and videos into small web versions.
//
// You don't need to run it by hand: scripts/prepare-media.sh calls it. It's
// written in Swift only because Swift comes with macOS (no install, no npm) and
// can use Apple's own image and video frameworks (ImageIO and AVFoundation).
//
// Three jobs:
//   swift scripts/media.swift photo IN OUT.jpg [--max 1600] [--quality 0.8]
//   swift scripts/media.swift video IN OUT.mp4 [--height 720] [--kbps 700]
//                                    [--start S] [--duration S] [--no-audio]
//   swift scripts/media.swift frame IN OUT.jpg --start S
//
// Why not just `sips` and `avconvert`, which also come with macOS?
//   - `sips -s format jpeg -Z 1600` resizes well, but it COPIES the photo's
//     metadata, GPS position included (we checked: an iPhone photo still had its
//     GPS block afterwards). A photo on a public site shouldn't say where it was taken.
//   - `avconvert` only has fixed presets. Its 720p preset kept a very high bitrate:
//     a 108-second screen recording came out at 98 MB. Here we choose the bitrate.

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

// ---- Reading the arguments ----

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}
func flag(_ name: String) -> Bool {
    let present = args.contains(name)
    args.removeAll { $0 == name }
    return present
}
func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

let maxSide = Double(option("--max") ?? "1600")!
let quality = Double(option("--quality") ?? "0.8")!
let targetHeight = Double(option("--height") ?? "720")!
let kbps = Double(option("--kbps") ?? "700")!
let start = Double(option("--start") ?? "0")!
let duration = option("--duration").map { Double($0)! }
let keepAudio = !flag("--no-audio")

guard args.count == 3, ["photo", "video", "frame"].contains(args[0]) else {
    fail("""
    usage: swift media.swift photo IN OUT.jpg [--max 1600] [--quality 0.8]
           swift media.swift video IN OUT.mp4 [--height 720] [--kbps 700] [--start S] [--duration S] [--no-audio]
           swift media.swift frame IN OUT.jpg --start S
    """)
}
let job = args[0]
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: output)

/// Save IMAGE as a JPEG with NO metadata: no GPS, no camera model, no date.
/// We pass only the compression quality, so nothing else is written.
/// (The color profile travels with the pixels, so colors stay right.)
func writeJPEG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { fail("Can't write \(url.path)") }
    CGImageDestinationAddImage(destination, image,
                               [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    if !CGImageDestinationFinalize(destination) { fail("Can't write \(url.path)") }
}

// ---- photo: resize, turn upright, drop the metadata ----
//
// A phone often stores a photo sideways plus a note "rotate me 90°" (the EXIF
// orientation). Since we drop all metadata, we must apply that rotation to the
// pixels first, or the photo would show up sideways: that's what
// kCGImageSourceCreateThumbnailWithTransform does. MaxPixelSize caps the long edge.

if job == "photo" {
    guard let source = CGImageSourceCreateWithURL(input as CFURL, nil) else { fail("Can't read \(input.path)") }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxSide,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { fail("Can't decode \(input.path)") }
    writeJPEG(image, to: output)
    print("Wrote \(output.lastPathComponent): \(image.width)x\(image.height), no metadata")
    exit(0)
}

let asset = AVURLAsset(url: input)

// ---- frame: one frame of a video, as a JPEG (a poster) ----

if job == "frame" {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    // image(at:) is async; the semaphore makes this script wait for it.
    let got = DispatchSemaphore(value: 0)
    var frame: CGImage?
    Task {
        frame = try? await generator.image(at: CMTime(seconds: start, preferredTimescale: 600)).image
        got.signal()
    }
    got.wait()
    guard let image = frame else { fail("No frame at \(start) s in \(input.path)") }
    writeJPEG(image, to: output)
    print("Wrote \(output.lastPathComponent): the frame at \(start) s, \(image.width)x\(image.height)")
    exit(0)
}

// ---- video: re-encode as H.264 at the size and bitrate we choose ----
//
//   1. AVAssetReader decodes the source frame by frame (and the sound, if kept).
//   2. AVAssetWriter encodes them again: H.264 at --height pixels tall (the width
//      follows the video's shape) and --kbps kilobits per second, AAC sound at 96 kbps.
//   3. shouldOptimizeForNetworkUse puts the file's index at its start ("fast
//      start"), so the browser can begin playing before the whole file arrives.
// No metadata is copied.

// Loading a track's properties is "async" in AVFoundation; the semaphore makes
// this small script wait for the answer, since it has nothing else to do.
let loaded = DispatchSemaphore(value: 0)
var videoTrack: AVAssetTrack?
var audioTrack: AVAssetTrack?
var naturalSize = CGSize.zero
var transform = CGAffineTransform.identity
var assetDuration = CMTime.zero
Task {
    videoTrack = try? await asset.loadTracks(withMediaType: .video).first
    audioTrack = try? await asset.loadTracks(withMediaType: .audio).first
    if let v = videoTrack {
        naturalSize = (try? await v.load(.naturalSize)) ?? .zero
        transform = (try? await v.load(.preferredTransform)) ?? .identity
    }
    assetDuration = (try? await asset.load(.duration)) ?? .zero
    loaded.signal()
}
loaded.wait()
guard let video = videoTrack else { fail("No video track in \(input.path)") }

// The output size: --height tall (never more than the source), the width keeping
// the shape, both even numbers (H.264 needs even sizes).
let shown = naturalSize.applying(transform)
let srcW = abs(shown.width), srcH = abs(shown.height)
let height = (min(targetHeight, srcH) / 2).rounded() * 2
let width = (srcW * height / srcH / 2).rounded() * 2
// The encoder works on the un-rotated frame; the transform rotates it on playback.
let rotated = abs(transform.b) == 1
let (encodeW, encodeH) = rotated ? (height, width) : (width, height)

let reader = try AVAssetReader(asset: asset)
let startTime = CMTime(seconds: start, preferredTimescale: 600)
let length = duration.map { CMTime(seconds: $0, preferredTimescale: 600) } ?? CMTimeSubtract(assetDuration, startTime)
reader.timeRange = CMTimeRange(start: startTime, duration: length)

let videoOut = AVAssetReaderTrackOutput(track: video, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
])
videoOut.alwaysCopiesSampleData = false
reader.add(videoOut)

var audioOut: AVAssetReaderTrackOutput?
if keepAudio, let audio = audioTrack {
    let out = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
    reader.add(out)
    audioOut = out
}

let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
writer.metadata = []

let videoIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: encodeW,
    AVVideoHeightKey: encodeH,
    AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: kbps * 1000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalDurationKey: 2,   // a keyframe every 2 s: quick seeking
    ],
])
videoIn.transform = transform
videoIn.expectsMediaDataInRealTime = false
writer.add(videoIn)

var audioIn: AVAssetWriterInput?
if audioOut != nil {
    let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 96000,
    ])
    input.expectsMediaDataInRealTime = false
    writer.add(input)
    audioIn = input
}

reader.startReading()
writer.startWriting()
writer.startSession(atSourceTime: startTime)

// Copy every sample from the reader to the writer, video and sound side by side.
let group = DispatchGroup()
func pump(_ from: AVAssetReaderTrackOutput, _ to: AVAssetWriterInput, _ label: String) {
    group.enter()
    to.requestMediaDataWhenReady(on: DispatchQueue(label: label)) {
        while to.isReadyForMoreMediaData {
            if let sample = from.copyNextSampleBuffer() {
                to.append(sample)
            } else {
                to.markAsFinished()
                group.leave()
                return
            }
        }
    }
}
pump(videoOut, videoIn, "video")
if let a = audioOut, let b = audioIn { pump(a, b, "audio") }
group.wait()

let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
if writer.status != .completed { fail("Failed: \(writer.error?.localizedDescription ?? "unknown error")") }

let bytes = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print("Wrote \(output.lastPathComponent): \(Int(width))x\(Int(height)), \(String(format: "%.1f", Double(bytes) / 1_000_000)) MB\(audioOut == nil ? ", no sound" : "")")
