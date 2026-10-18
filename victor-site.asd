;;;; victor-site.asd — tells ASDF (Lisp's build tool) which files make up the project
;;;; and in which order to load them. :serial t means "load them top to bottom".

(defsystem "victor-site"
  :description "Victor Henz's personal website, generated with Common Lisp."
  :author "Victor Henz"
  :serial t
  :components ((:module "src"
                :components ((:file "package")   ; the namespace everything lives in
                             (:file "html")      ; a tiny Lisp -> HTML renderer (~60 lines)
                             (:file "content")   ; YOUR text: bio, experience, projects
                             (:file "pages")     ; layout + page definitions
                             (:file "build"))))) ; writes everything into public/
