;;;; html.lisp — turns Lisp lists into HTML.
;;;;
;;;; This is the heart of the project, and it's small on purpose so you can read
;;;; every line. A page is just a nested list:
;;;;
;;;;   (:a :href "https://github.com" :class "link" "My GitHub")
;;;;    ^tag ^attribute  ^value        ^attribute    ^child
;;;;
;;;; renders to:  <a href="https://github.com" class="link">My GitHub</a>
;;;;
;;;; Rules:
;;;;   - a list starting with a keyword is an element (:p, :div, :section ...)
;;;;   - right after the tag, keyword/value pairs are attributes
;;;;   - everything after that is children: strings, numbers, more elements
;;;;   - an attribute whose value is NIL is skipped, T renders as a bare attribute
;;;;   - NIL children are skipped (handy with WHEN), plain lists are flattened
;;;;     (handy with MAPCAR)
;;;;   - (:raw "<b>hi</b>") inserts HTML without escaping — use sparingly
;;;;
;;;; Later, you can swap this for the Spinneret library, which uses almost the
;;;; same syntax. Writing it yourself first is the better lesson.

(in-package #:victor-site)

(defparameter *void-elements*
  '(:area :base :br :col :embed :hr :img :input :link :meta :source :track :wbr)
  "Elements that never have a closing tag.")

(defun escape (string)
  "Replace the characters that have a meaning in HTML."
  (with-output-to-string (out)
    (loop for c across string
          do (case c
               (#\& (write-string "&amp;" out))
               (#\< (write-string "&lt;" out))
               (#\> (write-string "&gt;" out))
               (#\" (write-string "&quot;" out))
               (t (write-char c out))))))

(defun split-attributes (items)
  "Split (:href \"x\" :class \"y\" child ...) into an attribute plist and the children."
  (loop while (and (keywordp (first items)) (rest items))
        collect (pop items) into attributes
        collect (pop items) into attributes
        finally (return (values attributes items))))

(defun render-attributes (attributes out)
  (loop for (name value) on attributes by #'cddr
        when value
          do (format out " ~(~a~)" name)          ; ~( ~) lowercases :data-x -> data-x
             (unless (eq value t)
               (format out "=\"~a\"" (escape (princ-to-string value))))))

(defun render (node out)
  "Write NODE as HTML to the stream OUT."
  (cond ((null node))
        ((stringp node) (write-string (escape node) out))
        ((numberp node) (princ node out))
        ((and (consp node) (eq (first node) :raw))
         (dolist (s (rest node)) (write-string s out)))
        ((and (consp node) (keywordp (first node)))
         (let ((tag (first node)))
           (multiple-value-bind (attributes children) (split-attributes (rest node))
             (format out "<~(~a~)" tag)
             (render-attributes attributes out)
             (write-string ">" out)
             (unless (member tag *void-elements*)
               (dolist (child children) (render child out))
               (format out "</~(~a~)>" tag)))))
        ((consp node) (dolist (child node) (render child out)))
        (t (error "Don't know how to render ~s" node))))

(defun html (tree)
  "Render a whole document to a string."
  (with-output-to-string (out)
    (format out "<!doctype html>~%")
    (render tree out)))
