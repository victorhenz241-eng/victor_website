;;;; make.lisp — one-shot build from the terminal:   sbcl --script make.lisp
;;;; (GitHub Actions runs exactly this to publish the site.)

(require :asdf)
(asdf:load-asd (make-pathname :name "victor-site" :type "asd" :defaults *load-truename*))
(asdf:load-system "victor-site")
(victor-site:build)
