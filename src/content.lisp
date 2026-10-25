;;;; content.lisp — everything about YOU lives here, as plain Lisp data.
;;;;
;;;; This is the only file you need to touch to change the text on the site.
;;;; Everything marked TODO is a placeholder: rewrite it in your own words.
;;;; Anything set to NIL is simply not shown.

(in-package #:victor-site)

(defparameter *name* "Victor Henz")

(defparameter *domain* nil
  "Your custom domain, e.g. \"victorhenz.com\". Leave NIL until you've bought it
and pointed it at GitHub Pages — the build then writes the CNAME file for you.")

(defparameter *base-path* (if *domain* "/" "/victor_website/")
  "Where the site lives on its server. Without a domain, GitHub Pages serves it under
the repo's name (github.io/victor_website/); with a domain it sits at the root.
Only the 404 page uses this: normal pages keep relative links, which work anywhere.")

(defparameter *eyebrow* "Data & AI · Luxembourg"
  "The small monospace line above the big headline.")

(defparameter *headline*
  '("I build AI tools on top of " (:em "real data") ".")
  "The big serif headline. Notice it's an HTML tree, not a string: that's how
the italic part gets its own <em> tag. Lisp data and HTML are the same thing here.")

(defparameter *intro*
  "AI engineering student at CentraleSupélec × ESSEC. I've built and shipped AI tools used in production at Canal+.")

(defparameter *about*
  '("At Canal+ I built internal AI applications that let leadership and editorial teams query company data in natural language, so people get numbers instead of tickets."
    "TODO: one or two sentences on what drives you — what you like building, what you want to work on next.")
  "Each string becomes one paragraph.")

(defparameter *links*
  '(("GitHub"   "https://github.com/victorhenz241-eng")
    ("LinkedIn" nil)                    ; TODO: your LinkedIn URL
    ("Email"    "mailto:victor.henz@essec.edu") ; mailto: makes the link open an email
    ("CV"       nil))                   ; TODO: put cv.pdf in static/ and write "cv.pdf"
  "(label url) pairs. Links with a NIL url are hidden.")

(defparameter *repl*
  '((:in  "(victor:whoami)")
    (:out "\"Victor Henz — AI engineering student\"")
    (:in  "(victor:studying)")
    (:out "(:program \"AIDAMS\" :schools (\"ESSEC\" \"CentraleSupélec\") :class 2028)")
    (:in  "(victor:currently)")
    (:out "(:building \"AI tools for business teams\" :learning \"Common Lisp\")")
    (:in  "(victor:next)")
    (:out "\"Summer 2027 internship — New York or San Francisco\""))
  "The animated terminal in the hero. :in lines get typed out, :out lines appear
at once. TODO: make these yours — they're the first thing a recruiter sees move.")

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
     :summary "Launched an AI news app on the App Store, personalized to each user's profession and location. Built the personalization engine and a political-bias detector. 2,000+ users and coverage in the Luxembourg press."))
  "Newest first. Add as many plists as you want.")

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
  '((:name "Event-Market Graph"
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
       "The public demo is a replay-only build with no backend, so nothing on it can reach the API, the model or the database.")))
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
       "Self-hosted n8n in Docker on a Google Cloud VM behind Caddy, a Rust dedup service, Groq for the LLM, Supabase (Postgres, auth, row-level security) and Next.js on Vercel.")))
    (:name "Cut the Line — 1st of 120"
     :url nil
     :summary "Won the Secure Horizons 2026 hackathon (ESSEC, €7,000 prize) with a 4-person team, building a product that detects phone scams and AI-cloned voices."
     :tags ("hackathon" "AI voice"))
    (:name "EFC Tracker"
     :url nil                           ; private repo
     :summary "An installable web app for the ESSEC Football Club's 9-week conditioning program, with iOS push reminders, now being extended to the whole club."
     :tags ("Next.js" "PWA" "Redis"))
    (:name "This website"
     :url nil                           ; TODO: the victor_website repo is private — link it once public
     :summary "Generated by a few hundred lines of Common Lisp, including a tiny HTML renderer written from scratch. No framework."
     :tags ("Common Lisp" "CSS" "vanilla JS")))
  "Pick the 3–5 projects you'd want an interviewer to ask you about.")

(defparameter *contact-line* "Let's build something.")
