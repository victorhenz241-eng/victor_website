;;;; content.lisp — everything about YOU lives here, as plain Lisp data.
;;;;
;;;; This is the only file you need to touch to change the text on the site.
;;;; Everything marked TODO is a placeholder: rewrite it in your own words.
;;;; Anything set to NIL is simply not shown.
;;;;
;;;; This file is PUBLIC, comments included: the "(λ) source" button shows the
;;;; text of these forms to every visitor (see src/source.lisp). So:
;;;;   - a normal comment is part of the showcase: write it for a recruiter;
;;;;   - a comment that starts with "private:" is a note for you only. The build
;;;;     cuts it out of the site, but it stays here in the file:
;;;;       ;; private: DRAFT, check these numbers      <- whole line, dropped
;;;;       :url nil  ; private: repo not public yet   <- end of line, dropped
;;;;   - docstrings are code, not comments: they are always shown.
;;;; (These header lines are never shown: they sit outside every form.)

(in-package #:victor-site)

(defparameter *name* "Victor Henz")

(defparameter *domain* nil
  "Your custom domain, e.g. \"victorhenz.com\". Leave NIL until you've bought it
and pointed it at GitHub Pages — the build then writes the CNAME file for you.")

(defparameter *base-path* (if *domain* "/" "/victor_website/")
  "Where the site lives on its server. Without a domain, GitHub Pages serves it under
the repo's name (github.io/victor_website/); with a domain it sits at the root.
Only the 404 page uses this: normal pages keep relative links, which work anywhere.")

(defparameter *eyebrow* "AI engineering · CentraleSupélec × ESSEC"
  "The small monospace line above the big headline.")

(defparameter *headline*
  '("I build AI tools on top of " (:em "real data") ".")
  "The big serif headline. Notice it's an HTML tree, not a string: that's how
the italic part gets its own <em> tag. Lisp data and HTML are the same thing here.")

(defparameter *intro*
  "AI engineering student with a 4.0 GPA. I built and shipped two AI tools used in production at Canal+, and won first place among 120 participants at the Secure Horizons 2026 hackathon with a 4-person team. I'm looking for a Summer 2027 internship in applied AI or data science."
  "Also used as the page's meta description, the snippet search engines show.")

(defparameter *about*
  '("At Canal+ I built internal AI applications that let leadership and editorial teams query company data and assemble content selections in natural language."
    ;; private: DRAFT — Victor to review: written from CV facts only
    "I like taking a project from end to end and getting it into people's hands. That started with Parsed, the AI news app I co-founded, where I built the personalization engine and a political-bias detector. Away from the keyboard I run middle distance: I've represented Luxembourg in the 1500m at the European Youth Olympic Festival.")
  "Each string becomes one paragraph.")

(defparameter *about-photo*
  ;; private: Victor must supply a portrait: head and shoulders, face clearly visible,
  ;; private: plain background, ideally portrait-shaped (it is cropped to 4:5).
  ;; private: Prepare it with: scripts/prepare-media.sh photo ~/Desktop/IMG_xxxx.HEIC portrait.jpg
  ;; private: Don't use a race photo here: the first picture should say "engineer".
  '(:file "media/portrait.jpg"
    :alt "Portrait of Victor Henz.")
  "A portrait beside the About text. It only appears once the file exists in static/;
until then the section is text only. :alt describes it for people who can't see it.")

(defparameter *links*
  '(("GitHub"   "https://github.com/victorhenz241-eng")
    ("LinkedIn" "https://www.linkedin.com/in/victor-henz-158471267/")
    ("Email"    "mailto:victor.henz@essec.edu") ; mailto: makes the link open an email
    ;; private: NIL on purpose: the CV PDF has your phone number on it, and everything in
    ;; private: static/ is public. Export a copy without it, put that in static/, then write "cv.pdf".
    ("CV"       nil))
  "(label url) pairs. Links with a NIL url are hidden.")

(defparameter *repl*
  '((:in  "(victor:whoami)")
    (:out "(:study \"AI, Data & Management Sciences\" :at \"CentraleSupélec × ESSEC\" :gpa 4.0)")
    (:in  "(victor:shipped :at \"Canal+\")")
    (:out "(:ai-apps 2 :used-in :production :text-to-sql-eval \"35/36 (97%)\")")
    (:in  "(victor:wins)")
    (:out "(:hackathon \"Secure Horizons 2026\" :place 1 :participants 120 :prize \"€7,000\")")
    (:in  "(victor:next)")
    (:out "(:internship \"Summer 2027\" :fields (\"applied AI\" \"data science\") :in-dc-from \"Jan 2027\")"))
  "The animated terminal in the hero. :in lines get typed out, :out lines appear
at once. Every value is a fact from the CV. Four in/out pairs at most, so the
animation stays short.")

(defparameter *experience*
  '((:role "AI Engineer Intern"
     :org "Canal+ · Benelux Central Europe (BCE)"
     :place "Luxembourg"
     :dates "May 2026 · 3 months"
     :summary "Built and shipped two internal AI apps (Next.js, Cloud Run) for natural-language queries over company data. Designed the Snowflake Cortex Analyst semantic layer, and moved the curation agent to a text-to-SQL microservice that scored 35/36 on an automated eval suite. The Canal+ group CEO asked for a live demo.")
    (:role "Co-founder & Developer"
     :org "Parsed"
     :place "Luxembourg"
     :dates "Jan 2025 · 6 months"
     :summary "Co-founded and launched an AI news app on the App Store, personalized to each user's profession and location. Built the personalization engine and a political-bias detector. Grew it to 2,000+ users, with coverage in the Luxembourg press."))
  "Newest first, one plist per role.")

(defparameter *skills*
  ;; Each list is (group skill skill ...). The first two groups' skills come from
  ;; the CV; Claude, Neo4j, React, Supabase, n8n and Common Lisp come from the
  ;; projects on this site, where they were part of what I built myself.
  '(("AI & data"
     "LLM agents" "LLM evaluation" "Text-to-SQL" "Semantic modeling"
     "Snowflake Cortex Analyst" "Snowflake Cortex Agents" "Claude on Amazon Bedrock" "Neo4j")
    ("Languages & frameworks"
     "Python" "SQL" "TypeScript" "Next.js" "FastAPI" "React" "Common Lisp")
    ("Infrastructure & tools"
     "Docker" "Google Cloud Run" "Vercel" "Supabase" "n8n" "Git"))
  "The toolbox, grouped so a reader can scan it in a few seconds.")

(defparameter *languages*
  '(("French" "mother tongue")
    ("English" "bilingual")
    ("German" "proficient")
    ("Luxembourgish" "proficient"))
  "(language level) pairs, in the CV's words.")

(defparameter *education*
  '((:role "Exchange semester"
     :org "George Washington University"
     :place "Washington, D.C."
     :dates "Jan – May 2027"
     :summary nil)
    (:role "BSc AIDAMS — AI, Data & Management Sciences"
     :org "CentraleSupélec × ESSEC Business School"
     :place "France"
     :dates "2024 – 2028"
     :summary "GPA 4.0 / 4.0. Machine learning, computer vision, stochastic processes, algorithms, big data systems.")))

(defparameter *outside-work*
  '((:what "Track and field"
     :dates "2021 – present"
     :text "Represented Luxembourg in the 1500m at the European Youth Olympic Festival. National U18 champion in cross country and the 800m; runner-up at the senior indoor 800m nationals.")
    (:what "Football"
     :dates "2010 – 2024"
     :text "Over a decade at a high level with Racing FC Union Luxembourg. MVP at NECIS Varsity in Amsterdam (2023).")
    (:what "Class representative, AIDAMS"
     :dates "2024 – present"
     :text "Led a formal petition to the administration on how the GPA is computed.")
    (:what "Founder, ELA Charity Week"
     :dates "2023"
     :text "Launched my school's first charity week, which raised €1,200+ for the ELA."))
  "Sport and leadership, shown small under Education: a human detail, not a headline.")

(defparameter *outside-media*
  ;; A photo and a 4-second silent loop from the same day on the track. Like every
  ;; picture on the site, each one shows only once its file exists in static/.
  '(:photo (:file "media/outside-running.jpg"
            :alt "Victor on a blue running track in the red and light-blue Luxembourg team kit, bib number 82.")
    :video (:file "media/outside-running-finish.mp4"
            :poster "media/outside-running-finish-poster.jpg"
            :alt "Filmed from the stands: runners in the light-blue Luxembourg kit come down the home straight, and Victor, bib 82, crosses the finish line.")
    :caption "On the track, June 2024.")
  "The pictures beside the Outside work list. :alt describes each one.")

(defparameter *projects-intro* "Here are some of my projects."
  "The line under the Projects label. The cards are a selection, not everything.")

(defparameter *projects*
  ;; Strongest first: a recruiter may only read the first card or two.
  ;; :featured  gets a bigger card on the home page
  ;; :blurb     the one line on the card (the case-study page shows :summary)
  ;; :card      what fills the top of the card: (:video file :poster file) or
  ;;            (:image file :alt "..."), shown only once the file exists.
  ;;            Without it, or until then, the card draws something from the
  ;;            project's own data instead (:stat, :funnel or :diagram).
  '((:name "Cut the Line"
     :slug "cut-the-line"
     :url "https://github.com/Coachbet/projet_utopia"
     :featured t
     :blurb "Real-time protection against phone scams and AI-cloned voices. 1st of 120 at the Secure Horizons 2026 hackathon."
     :summary "Won first place among 120 participants at the Secure Horizons 2026 hackathon (ESSEC) and the €7,000 prize, with a 4-person team. We built a product that detects phone scams and AI-cloned voices while the call is happening."
     :tags ("hackathon winner" "Claude" "Twilio" "FastAPI" "wav2vec2")
     :links (("Code" "https://github.com/Coachbet/projet_utopia"))
     :stats (("1st" "of 120 participants, Secure Horizons 2026")
             ("€7,000" "prize")
             ("4" "people on the team"))
     ;; The card's still (shown under reduced motion) is a frame of the loop
     ;; itself, at 7.6 s: all four signals lit and the score at 89, "Danger".
     :card (:video "media/cut-the-line-card.mp4" :poster "media/cut-the-line-card-poster.jpg")
     :stat ("1st" "of 120")
     ;; The demo we made, with sound. Plays only when you press play.
     :video (:file "media/cut-the-line-demo.mp4"
             :poster "media/cut-the-line-poster.jpg"
             :sound t
             :caption "The product demo (1 min 10 s, with sound).")
     ;; Photos from the event: every .jpg in static/media/cut-the-line/, sorted by
     ;; name. One description per photo, in the same order. No photos, no section.
     :gallery (:folder "media/cut-the-line/"
               :heading "At the hackathon"
               :alts ("Our team on stage after the results, under a screen that reads: Cut the Line, winner of Secure Horizons 2026."
                      "Pitching the business model on stage."
                      "The team at work on laptops around a table during the hackathon."))
     :sections
     (("The challenge"
       "Phone scams aimed at older people follow the same script: a relative in trouble, a fake bank advisor or a fake police officer, pushing for an urgent payment and asking to keep it secret. A few seconds of public audio are now enough to clone a voice, and the number on screen can be spoofed."
       "Spam filters act before the call and bank checks act after the payment. Nothing protects the conversation itself.")
      ("What we built"
       "Cut the Line sits on the call path of the person it protects. Calls from people in their contact book pass through untouched: they are never listened to. An unknown caller first hears that the call is being analyzed. Only then does live transcription start, and four weighted signals feed a risk score."
       "The response is graduated: a warning on the screen, then a spoken warning only the callee hears and a text to the real relative, then the caller is put on hold. There is no automatic hang-up, by design: a false alarm on a real family emergency would be serious."
       "At any moment the callee can ask for an identity check. A 4-digit code is texted to the number the contact book holds for the claimed relative, never to the number on screen. A cloned voice on a spoofed number never receives it.")
      ("My part"
       "It was a team project, and I built the scoring side: the four risk signals, the scoring engine with its circuit breakers, and the live dashboard."
       "I tuned the content analyzer (Claude on Amazon Bedrock) against failures we measured on degraded phone speech, added French number normalization, and added a signal for when the real contact answers NO to \"is that you calling?\". I also integrated the two halves of the codebase into one shared event contract.")
      ("The pitch"
       "We pitched the product and its business plan, a paid subscription for all age groups, to a jury of industry professionals that included KPMG's Head of AI.")
      ("Stack"
       "Python 3.12 and FastAPI in a hexagonal architecture, Twilio (Media Streams, Conference, Voice JS SDK), Amazon Transcribe streaming, Claude on Amazon Bedrock, wav2vec2 for synthetic voices, SQLite for call metadata.")
      ("Result"
       "First place among 120 participants at the Secure Horizons 2026 hackathon at ESSEC, in October 2026, and the €7,000 prize. Built in 36 hours, chosen by 12 jury members."))
     ;; The score, drawn like the other diagrams (see DIAGRAM-SVG). The weights and
     ;; thresholds are the real ones from the project's README.
     :diagram
     (:heading "The score"
      :after "My part"
      :flow :right
      :title "Cut the Line risk score"
      :caption "Four weighted signals make one score; the score picks the response. Circuit breakers keep a strong signal from being averaged away, and a synthetic voice alone can never push the score above 64."
      :nodes ((content    :at (0 0) :label "Claude content" :note "weight 45")
              (keywords   :at (0 1) :label "Keywords" :note "weight 20")
              (voice      :at (0 2) :label "Synthetic voice" :note "weight 20")
              (reputation :at (0 3) :label "Reputation" :note "weight 15")
              (score      :at (1 1.5) :label "Risk score" :note "0 – 100")
              (caution    :at (2 0.5) :label "Caution" :note "40 – 64")
              (alert      :at (2 1.5) :label "Alert" :note "65 – 84")
              (hold       :at (2 2.5) :label "Intervention" :note "85 and up"))
      :edges ((content -> score)
              (keywords -> score)
              (voice -> score)
              (reputation -> score)
              (score -> caution "on screen")
              (score -> alert "warn + text")
              (score -> hold "on hold"))
      :pulse (content score hold)))
    (:name "Event-Market Graph"
     :slug "event-market-graph"           ; a :slug means "give this project its own page"
     :url "https://event-market-graph-ten.vercel.app"
     :featured t
     :blurb "A Neo4j knowledge graph linking geopolitical events to market moves, walked by a LangGraph agent."
     :summary "A Neo4j knowledge graph linking geopolitical events to market moves, with a LangGraph agent that walks it. Team project: I built the animated frontend and the infrastructure."
     :tags ("Neo4j" "LangGraph" "React" "Docker")
     ;; A 9-second silent loop for the home page card: the agent walking the graph,
     ;; cut from a screen recording of the live demo. Without the file, the card
     ;; would show a small copy of the schema diagram below instead.
     :card (:video "media/event-market-card.mp4" :poster "media/event-market-card-poster.jpg")
     :links (("Live demo" "https://event-market-graph-ten.vercel.app")
             ("Code" "https://github.com/victorhenz241-eng/graphdb-event-market"))
     :stats (("6" "market series: Brent, WTI, EURUSD, USDJPY, US 10Y, VIX")
             ("~4,500" "geopolitical and central-bank events")
             ("880" "daily price points")
             ("6 months" "of events and prices, Feb–Jul 2026"))
     ;; A screen recording of the live demo replaying one agent run. It is silent
     ;; (no :sound), so it loops while it's on screen, like the card videos; the
     ;; page adds a "Live demo" link after the caption.
     :video (:file "media/event-market-demo.mp4"
             :poster "media/event-market-poster.jpg"
             :caption "A recorded replay of the live demo. The agent answers: \"Why did the VIX move in June?\"")
     ;; Each section is (heading paragraph paragraph ...).
     :sections
     (("The question"
       "When oil or the VIX jumps, what happened in the days before? Geopolitical events and market prices live in separate datasets. This project puts them in one Neo4j graph, where events and prices meet on a shared trading-day node.")
      ("What I built"
       "It was a team project. I built the frontend and the infrastructure."
       "The frontend is a React page that lays the graph out as a timeline: markets on top, trading days in the middle, events, themes and countries below. When the agent answers a question, each step appears as it happens, the nodes it touches light up and the edges it walks are animated."
       "The infrastructure runs the whole stack with Docker Compose: Neo4j with Graph Data Science, a local Ollama model, the API and an Nginx reverse proxy. Every port is bound to localhost, the proxy rate-limits requests, and asking the model needs an API key.")
      ("How it works"
       "Events come from GDELT and from central-bank rate decisions; prices come from FRED. The API computes correlations, candidate events for a move, shortest paths and PageRank. A LangGraph agent answers questions in plain English and shows the graph paths and the Cypher it used.")
      ("Safety by design"
       "Every correlation is labelled a hypothesis, never a cause. Asked to \"delete all the events\", the model wrote a DELETE query; it was rejected before reaching Neo4j, which the API opens read-only anyway."
       "The public demo is a replay-only build with no backend, so nothing on it can reach the API, the model or the database."))
     ;; The schema as a picture, drawn by pages.lisp (DIAGRAM-SVG):
     ;;   :at (column row)    where a box sits on a grid; here rows run top to
     ;;                       bottom, like the frontend: markets, days, events
     ;;   (a -> b "LABEL")    an arrow from box a to box b
     ;; The names are the real ones from the project's graph contract.
     :diagram
     (:heading "The graph"
      :after "How it works"
      :flow :down
      :title "Event-Market Graph schema"
      :caption "Six of the graph's eight node labels, with their real relationship names."
      :nodes ((series  :at (1 0) :label "PriceSeries" :note "VIX, Brent, WTI…")
              (claim   :at (0 1) :label "Claim" :note "proposed relation")
              (day     :at (1 1) :label "TradingDay" :note "one node per date")
              (event   :at (1 2) :label "Event" :note "GDELT · Fed · ECB")
              (country :at (0 3) :label "Country" :note "ISO alpha-3")
              (theme   :at (2 3) :label "Theme" :note "CAMEO · monetary"))
      ;; :label-at moves a label along its arrow (0 = start, 1 = end; 0.5 if
      ;; not given) when it would sit on top of another one.
      :edges ((series -> day "PRICE_ON")
              (event -> day "ON_DAY")
              (event -> theme "HAS_THEME" :label-at 0.25)
              (event -> country "OCCURRED_IN" :label-at 0.25)
              (theme -> series "CORRELATES_WITH" :label-at 0.4)
              (claim -> series "ABOUT_SERIES" :label-at 0.3)
              (claim -> event "ABOUT_EVENT" :label-at 0.3))
      ;; An example walk, lit up one step at a time like the agent in the frontend.
      ;; It shows the kind of path the agent follows; it is not real data.
      :walk ((series "A move in a price series, say the VIX")
             (day "the TradingDay it happened on")
             (event "the events linked to that day")
             (theme "and the Theme of each event"))))
    (:name "Internship Radar"
     :slug "internship-radar"
     :url "https://github.com/victorhenz241-eng/intership_finder"
     :featured t
     :blurb "Turns ~16,000 internship listings into a short list worth applying to, every night, for about €0 a month."
     :summary "Turns ~16,000 internship listings into a short list worth applying to, every night. Six n8n workflows, a Rust dedup service and a Next.js app, for about €0 a month."
     :tags ("n8n" "Next.js" "Supabase" "Rust")
     :links (("Code" "https://github.com/victorhenz241-eng/intership_finder"))
     :stats (("~16,000" "listings scanned")
             ("~250" "roles kept in the table")
             ("6" "n8n workflows")
             ("≈ €0" "a month, all free tiers"))
     ;; An 8.5-second silent loop for the home page card: a role opens with its
     ;; fit score, goes into the pipeline, and the pipeline board appears. Cut from
     ;; a screen recording of the live app, with every company and person name
     ;; blurred (the recording itself stays private, on Victor's computer).
     :card (:video "media/internship-radar-card.mp4" :poster "media/internship-radar-card-poster.jpg")
     ;; The edited demo (25 s): inbox, eligibility, filters, a role's fit score,
     ;; the pipeline, then the people search. Silent (no :sound), so it loops
     ;; while it's on screen, with a Pause button, like Event-Market's.
     :video (:file "media/internship-radar-demo.mp4"
             :poster "media/internship-radar-poster.jpg"
             :caption "Recorded in the live app. Company and contact names are blurred.")
     :sections
     (("The problem"
       "Finding an internship has two hard parts. Aggregators list thousands of postings and most don't fit one person. And cold applications go through applicant-tracking systems where nothing comes back. The best channel is a warm contact at the company.")
      ("What I built"
       "Automations that run overnight with no one present: they fetch listings, score them against a fixed profile with an LLM, check eligibility (reading the full job description when the posting is on Greenhouse or Lever), and fold duplicates through a small Rust service. Everything lands in one Postgres table on Supabase."
       "A Next.js web app is the only thing I touch. It reads that table, lets me triage quickly, tracks each role through a pipeline, searches for people at the company and drafts outreach text. A Telegram bot with an AI agent answers questions about the table.")
      ("Two rules that shape it"
       "The automations write, the app updates a few columns, and nothing is ever deleted: a dismissed role stays in the table so the next night's sweep doesn't add it back."
       "The LinkedIn part stays manual. The app prepares text and tracks threads, but never sends a message, never connects and never fetches a LinkedIn page, because automating LinkedIn gets accounts restricted.")
      ("Stack"
       "Self-hosted n8n in Docker on a Google Cloud VM behind Caddy, a Rust dedup service, Groq for the LLM, Supabase (Postgres, auth, row-level security) and Next.js on Vercel."))
     ;; The real funnel, counted in the live system (no company names). The bars
     ;; grow when they scroll into view (FUNNEL in pages.lisp). Each step is
     ;; (shown-value count label): COUNT sets the bar's length.
     :funnel
     (:heading "The funnel"
      :after "What I built"
      :caption "Counted in the live system, as of October 2026. Bar lengths use a log scale, so the small steps stay visible."
      :steps (("~16,000" 16000 "listings scanned")
              ("~250" 250 "kept in the table")
              ("12" 12 "shortlisted")
              ("7" 7 "applications sent")))
     ;; The architecture as a picture, drawn by pages.lisp (DIAGRAM-SVG):
     ;;   :at (column row)    where a box sits on a grid; columns run left to right
     ;;   (a -> b "label")    an arrow from box a to box b, with what travels on it
     ;;   (a <-> b "label")   an arrow both ways
     ;; Arrows are drawn in the order written, so the list reads as the flow.
     ;; :pulse is the main pipeline: small dots travel along it, box to box.
     :diagram
     (:heading "Architecture"
      :after "What I built"
      :flow :right
      :title "Internship Radar architecture"
      :caption "Simplified from the architecture map in the project's README."
      :nodes ((listings :at (0 0) :label "SimplifyJobs" :note "~16k postings")
              (boards   :at (0 1) :label "Job-board APIs" :note "Greenhouse, Lever")
              (sweep    :at (1 0) :label "Sweep" :note "n8n · daily 02:00")
              (enrich   :at (1 1) :label "Enrich" :note "n8n · every 3 h")
              (dedup    :at (1 2) :label "Dedup" :note "n8n · daily 02:30")
              (groq     :at (2 0) :label "Groq LLM" :note "gpt-oss-120b")
              (db       :at (2 1) :label "Postgres" :note "Supabase · RLS")
              (rust     :at (2 2) :label "Rust dedup" :note "Docker, same VM")
              (app      :at (3 1) :label "Next.js app" :note "on Vercel")
              (bot      :at (3 2) :label "Telegram bot" :note "n8n · AI agent"))
      :edges ((listings -> sweep "JSON")
              (boards -> enrich "job text")
              (sweep -> groq "score")
              (enrich -> groq)
              (sweep -> db "insert")
              (enrich -> db "eligibility")
              (dedup <-> rust "all rows")
              (dedup -> db "groups")
              (db -> app "roles")
              (app -> groq "drafts")
              (db -> bot "reads"))
      :pulse (listings sweep db app)))
    (:name "This website"
     :url nil                           ; private: TODO: the victor_website repo is private — link it once public
     :blurb "Generated by Common Lisp, with a tiny HTML renderer written from scratch. No framework."
     :summary "Generated by a few hundred lines of Common Lisp, including a tiny HTML renderer written from scratch. No framework."
     :tags ("Common Lisp" "CSS" "vanilla JS")
     ;; :lines-of-lisp = "count them during the build" (the same number as the footer).
     :stat :lines-of-lisp))
  "The projects worth asking about in an interview.")

(defparameter *contact-line* "Let's build something.")
