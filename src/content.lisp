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

(defparameter *projects*
  ;; Strongest first: a recruiter may only read the first card or two.
  '((:name "Cut the Line — 1st of 120"
     :url nil
     :summary "Won first place among 120 participants at the Secure Horizons 2026 hackathon (ESSEC) and the €7,000 prize, with a 4-person team. We built a product that detects phone scams and AI-cloned voices, and pitched it to a jury that included KPMG's Head of AI."
     :tags ("hackathon winner" "AI voice" "scam detection"))
    (:name "Event-Market Graph"
     :slug "event-market-graph"           ; a :slug means "give this project its own page"
     :url "https://event-market-graph-ten.vercel.app"
     :summary "A Neo4j knowledge graph linking geopolitical events to market moves, with a LangGraph agent that walks it. Team project: I built the animated frontend and the infrastructure."
     :tags ("Neo4j" "LangGraph" "React" "Docker")
     :links (("Live demo" "https://event-market-graph-ten.vercel.app")
             ("Code" "https://github.com/victorhenz241-eng/graphdb-event-market"))
     :stats (("6" "market series: Brent, WTI, EURUSD, USDJPY, US 10Y, VIX")
             ("~4,500" "geopolitical and central-bank events")
             ("880" "daily price points")
             ("6 months" "of events and prices, Feb–Jul 2026"))
     ;; A screen recording of the demo. It only appears once static/event-market.mp4
     ;; exists (README, "Add the demo video"); until then the page has no video.
     :video (:file "event-market.mp4"
             :poster "event-market-poster.jpg"
             :caption "A screen recording of the public demo, replaying a recorded agent run.")
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
     :summary "Turns ~16,000 internship listings into a short list worth applying to, every night. Six n8n workflows, a Rust dedup service and a Next.js app, for about €0 a month."
     :tags ("n8n" "Next.js" "Supabase" "Rust")
     :links (("Code" "https://github.com/victorhenz241-eng/intership_finder"))
     :stats (("~16,000" "listings scanned")
             ("~250" "roles kept in the table")
             ("6" "n8n workflows")
             ("≈ €0" "a month, all free tiers"))
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
    (:name "EFC Tracker"
     :url nil                           ; private: private repo
     :summary "Built and deployed a progressive web app for the ESSEC Football Club's 9-week conditioning program, with iOS push reminders. Now extending it to the whole club."
     :tags ("Next.js" "TypeScript" "Redis" "PWA"))
    (:name "This website"
     :url nil                           ; private: TODO: the victor_website repo is private — link it once public
     :summary "Generated by a few hundred lines of Common Lisp, including a tiny HTML renderer written from scratch. No framework."
     :tags ("Common Lisp" "CSS" "vanilla JS")))
  "The projects worth asking about in an interview.")

(defparameter *contact-line* "Let's build something.")
