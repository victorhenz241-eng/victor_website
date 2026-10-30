# Photos and videos

How every picture and video on the site was made, and how to redo them.

Everything goes through one script, which only uses tools that come with macOS
(`sips`, and Swift for `scripts/media.swift`). Run it from the project folder. The
last argument is the file name inside `static/media/`: lowercase letters, digits and
dashes, **no spaces** (a space in a web address becomes `%20` and breaks easily).

```sh
# A photo (JPEG, HEIC, PNG): long edge 1600 px, JPEG quality 80, turned upright,
# and every bit of metadata removed: GPS position, phone model, date.
scripts/prepare-media.sh photo ~/Desktop/IMG_1234.HEIC portrait.jpg
mkdir -p static/media/cut-the-line
scripts/prepare-media.sh photo ~/Desktop/podium.jpg cut-the-line/01.jpg

# A demo with sound, for a case-study page: 720p H.264 at ~700 kbit/s (about 5 MB a minute).
scripts/prepare-media.sh video ~/Desktop/demo.mov my-demo.mp4

# A short silent loop for a card: 8 seconds starting at 0:59, no sound.
scripts/prepare-media.sh clip ~/Desktop/demo.mov my-card.mp4 59 8

# A poster: the frame at 1:04, shown before a video plays (and instead of it
# when someone asks their system for less motion).
scripts/prepare-media.sh poster ~/Desktop/demo.mov my-poster.jpg 64
```

After each picture the script prints its size and checks with `sips -g all` that no
GPS, camera or date is left. Then rebuild (`sbcl --script make.lisp`).

**Why not just `sips` and `avconvert`?** We tried both. `sips -s format jpeg -Z 1600`
resizes well but *keeps* an iPhone photo's GPS position. And `avconvert` only has
fixed presets: its 720p one turned the 108-second Cut the Line demo into 98 MB (the
1080p original is 27 MB). `media.swift` uses the same Apple frameworks but lets us
choose the bitrate: the same demo is 10.5 MB at 720p.

**Which file shows where.** Each file appears on the site as soon as it exists in
`static/media/` and you rebuild. Without it, the page falls back gracefully (no broken
image, no empty box):

| File in `static/media/` | Where it shows | Without it |
|---|---|---|
| `portrait.jpg` | beside the About text | text only |
| `outside-running.jpg`, `outside-running-finish.mp4` + `-poster.jpg` | under "Outside work", in Education | no pictures there |
| `cut-the-line/01.jpg`, `02.jpg`… | "At the hackathon", on the Cut the Line page (sorted by name) | no section |
| `cut-the-line-card.mp4` + `-poster.jpg` | the Cut the Line card on the home page | a big "1st" |
| `cut-the-line-demo.mp4` + `cut-the-line-poster.jpg` | under the header of the Cut the Line page, with sound | no video |
| `event-market-card.mp4` + `-poster.jpg` | the Event-Market card on the home page | a small copy of its diagram |
| `event-market-demo.mp4` + `event-market-poster.jpg` | under the header of the Event-Market page, looping | no video |
| `internship-radar-card.mp4` + `-poster.jpg` | the Internship Radar card on the home page | a small copy of its funnel |
| `internship-radar-demo.mp4` + `internship-radar-poster.jpg` | under the header of the Internship Radar page, looping | no video |

Each picture also needs a description for people who can't see it: `:alt` in
`*about-photo*` and `*outside-media*`, the `:alts` list of the Cut the Line `:gallery`
(one string per photo, same order), and `:alt` on each silent demo `:video`, all in
`content.lisp`.

**Keep the repo light.** GitHub warns about files over 50 MB and refuses them over
100 MB. Keep every file under 15 MB (for a long demo, lower the bitrate:
`scripts/prepare-media.sh video demo.mov my-demo.mp4 500`). `ls -lh static/media`
shows the sizes.

**The Event-Market videos** are a recording of the live demo replaying "Why did the
VIX move in June?" (light theme): `event-market-demo.mp4` is the whole run (15 s,
1280×800, silent, it loops on the page), `event-market-card.mp4` is 9 s of it cropped
to the graph and the agent's panel, and `event-market-poster.jpg` is the frame at 8 s.
To redo them from a new recording (⌘⇧5, *Record Selected Portion*, saved on the
Desktop as `recording.mov`; the card then shows the whole recorded area):

```sh
scripts/prepare-media.sh clip ~/Desktop/recording.mov event-market-card.mp4 4 9
swift scripts/media.swift video ~/Desktop/recording.mov static/media/event-market-demo.mp4 --no-audio --kbps 1500
swift scripts/media.swift frame ~/Desktop/recording.mov static/media/event-market-poster.jpg --start 8
```

**The Internship Radar videos** come from an 81-second screen recording of the live
app, edited down: `internship-radar-demo.mp4` (25 s, 1440×900, silent, it loops on
the page) shows the inbox, the eligibility check, the filters, a role's fit score,
the pipeline and the people search, with a short caption for each step;
`internship-radar-card.mp4` (8.5 s, 960×600) is the fit score → pipeline moment.
The demo was later re-encoded smaller (3.4 MB instead of 6 MB, same size and look) with
`ffmpeg -i in.mp4 -an -c:v libx264 -preset slow -tune animation -crf 24 -pix_fmt yuv420p -movflags +faststart -map_metadata -1 out.mp4`. In
both, every company name, person name and the people found by search are blurred,
for privacy. The edit (cuts, blur, slow zooms,
captions, the dissolve that makes the loop seamless) was done once with ffmpeg and a
throwaway script, not with `prepare-media.sh`: the blur boxes come from reading the
text in every frame (Apple's Vision framework), then each frame was checked again
for names. If you ever redo them, check every frame for names before publishing. The
posters are frames of the finished videos (`media.swift frame`, at 9.5 s and 3.2 s),
so they are blurred too.

**The race loop** (`outside-running-finish.mp4`, under "Outside work") is the last
4 seconds of a 4K iPhone video from June 2024, cropped towards the finish line
(1024×640, silent, about 1 MB). iPhones film in HDR ("HLG"), which looks washed out
once turned into a normal video, so this one was made with ffmpeg
(`brew install ffmpeg`), which can convert the colors:

```sh
ffmpeg -ss 6 -t 4 -i ~/Desktop/IMG_4937.MOV -map 0:v:0 -an \
  -vf "colorspace=all=bt709:iall=bt2020:itrc=bt2020-10:format=yuv420p,crop=2592:1620:600:60,scale=1024:640,fps=30" \
  -c:v libx264 -crf 27 -pix_fmt yuv420p -movflags +faststart -map_metadata -1 \
  static/media/outside-running-finish.mp4
ffmpeg -ss 3.8 -i static/media/outside-running-finish.mp4 -frames:v 1 -q:v 3 -map_metadata -1 \
  static/media/outside-running-finish-poster.jpg
```

`-map_metadata -1` drops the date, phone and GPS; `crop=W:H:X:Y` keeps a W×H box
whose top-left corner is at (X, Y).

**The link-preview picture** (`static/og.png`, what LinkedIn or Slack show when the
link is pasted) is made from `scripts/og.html` by `scripts/make-og.sh` (headless
Chrome). If you change the headline, change it in `og.html` too and run the script.

The build reads each video's width and height from the file, so the page reserves
its space before the video loads. Delete a file and rebuild to remove it again.
