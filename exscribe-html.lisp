#+xcvb
(module
 (:depends-on
  ("fare-utils/package"
   "fare-utils/basic-macros"
   "fare-utils/basic-lists"
   "fare-matcher/packages"
   "fare-matcher/matcher"
   "scribble/package"
   "scribble/scribble"
   "exscribe/packages"
   "exscribe/macros"
   "exscribe/specials"
   "exscribe/exscribe-data"
   "exscribe/bibliography"
   "exscribe/html-dumper")))

(in-package :exscribe-html)

#| "
 :author (name url) => proper HTML header, footer, etc.
 :ref (bib ...) => bibliographic reference, section reference...
 :footnote (note) => list of footnotes
 :table-of-contents (section subsection subsubsection) => XXX
 :section (number title)
 :subsection (number title)
 :subsubsection (number title)
" |#

(defun sc (&rest x)
  (apply 'span :style "font-variant: small-caps" x))

(defun make-title (&key title author)
  (when title
    (table :width "100%"
	   (tr (td :bgcolor *title-background* :align 'center
		   (font :color *foreground*
			 :face "sans-serif" :size "10" (bold title))
		   (when author (*list (br) author)))))))

(defun make-author (&key name email affiliation url)
  (declare (ignore email))
  (center
   (br*
    (when name (font :size "+3" (it name)))
    (when affiliation (font :size "+1" affiliation))
    (when url (font :size "+1"
		    (tt (if (stringp url) (a :href url url) url)))))))

(defun edited-footnote (note num)
  (list
   (a :name (format nil "footnote~A" num))
   (a :href (format nil "#footnoteref~A" num) "[" num "]") ": "
   note))

(defun find-first-paragraph (x)
  (labels
      ((fail ()
	 (return-from find-first-paragraph nil))
       (walk (x)
	 (match x
	   ((tag :p * *) x)
	   ((tag :id * x) (walk x))
	   ((tag * * *) (fail))
	   ((of-type string) (fail))
	   ((cons x y) (or (walk x) (walk y)))
	   (* nil))))
    (walk x)))

(defun edit-footnote (note num)
  (aif (find-first-paragraph note)
       (prog1 note
	 (push (edited-footnote nil num) (tag-contents it)))
       (p :align 'justify (edited-footnote note num))))

(defun make-footnote (note)
  (let* ((num (incf *footnote-counter*))
	 (editednote (edit-footnote note num)))
    (push editednote *footnotes*)
    (id
     (a :name (format nil "footnoteref~A" num))
     (a :href (format nil "#footnote~A" num) (sup (small #\[ num #\]))))))

(defun title-font (&rest x)
  (font :size "+1" :face "sans-serif" (apply 'bold x)))

(defun make-xsection (type indent options index display)
  (let* ((title (getf options :title))
	 (toc (getf options :toc t))
	 (label (if index (id index (when title #\space) title) title))
	 (tag (or index (gensym)))
	 (name (format nil "~A_~A" type tag)))
    (when toc
      (push (cons type (id indent (a :href (format nil "#~A" name) label)))
	    *toc*))
    (id (a :name name) (funcall display label))))
(defun make-section (options)
  (let ((number (getf options :number t)))
    (when (eq number t) (setf number (incf *section-counter*)))
    (setf *section-name* number
	  *subsection-counter* 0 *subsubsection-counter* 0)
    (make-xsection :section nil options number
		   #'(lambda (x)
		       (table :width "100%"
			      (tr (td :bgcolor *section-title-background* :valign :top
				      (title-font x))))))))
(defun make-subsection (options)
  (let ((number (getf options :number t)))
    (when (eq number t)
      (setf number (format nil "~A.~A"
			   *section-name*
			   (incf *subsection-counter*))))
    (setf *subsection-name* number *subsubsection-counter* 0)
    (make-xsection :subsection  "&nbsp;&nbsp;&nbsp;" options number #'title-font)))
(defun make-subsubsection (options)
  (let ((number (getf options :number t)))
    (when (eq number t)
      (setf number (format nil "~A.~A"
			   *subsection-name*
			   (incf *subsubsection-counter*))))
    (setf *subsubsection-name* number)
    (make-xsection :subsubsection "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
		   options number
                   #'(lambda (x) (p :align 'left (bold x) " ")))))

(defun compute-toc (toc sec subsec subsubsec)
  (setf (tag-contents toc)
	(*list
	 (brlist
	  (loop for (ct . c) in *toc* collect
	    (case ct
	      (:section (when sec c))
	      (:subsection (when (and sec subsec) c))
	      (:subsubsection (when (and sec subsec subsubsec) c))
	      (t nil)))))))

(defun make-toc (&key (section t) (subsection t) (subsubsection t) &aux (toc (id)))
  (push #'(lambda () (compute-toc toc section subsection subsubsection))
	*postprocess-hooks*)
  toc)

(defun bib-ref-name (bibent)
  ;;; add more styles later
  ;;; it's ugly to use :ident instead of B and :index
  (id "[B" (gethash :index bibent) "]"))

(defun compute-bib-ref (doc bibent)
    (copy-tag doc
	      (a :href (format nil "#bibent-~A" (gethash :ident bibent))
		 (bib-ref-name bibent))))

(defun prepare-bib-ref (doc entry)
  (let ((bibent (get-bib-entry entry doc)))
    (push #'(lambda () (compute-bib-ref doc bibent))
	  *postprocess-hooks*)))

(defun show-bib-entry (e)
  (let* ((f (gethash :fields e))
	 (title (gethash 'title f))
	 (ititle (it title))
	 (author (gethash 'author f))
	 (year (gethash 'year f))
	 (url (gethash 'url f)))
    (id
     (a :name (format nil "bibent-~A" (gethash :ident e)))
     (bib-ref-name e) #\space
     (if url (a :href url ititle) ititle)
     (when author (id ", " author))
     (when year (id ", " year)))))

(defun display-bibliography (entries)
  (*list
   *bibliography-header*
   (brlist (mapcar 'show-bib-entry entries))))


(defun postprocess-document ()
  (let ((fnotes (id)))
    (setf *document*
	  (list 'list *header* *document* fnotes *footer*))

    (walking-document (doc *document*)
      (match doc
	((tag :ref (list :url url) body)
	  (replace-tag! doc :a (list :href url) body)
	  (walk doc))
	((tag :ref (list :bib entry) list)
	  (unless (null list) (error "bad bib ref ~A" doc))
	  (prepare-bib-ref doc entry))
; FIXME, NOW!
;	((tag :ref (list :section section) *)
;	  (replace-tag! doc :a (list :href url) body))
	((tag :document options list)
	  (replace-tag! doc :id ()
			`(,@(when options (list (apply #'make-title options)))
			  ,@list))
	  (walk doc))
	((tag :author options list)
	  (replace-tag! doc :id ()
			`(,@(when options (list (apply #'make-author options)))
			  ,@list))
	  (walk doc))
	((tag :footnote (list :note note) list)
	  (let ((fnote (id)))
	    (replace-tag! doc :id () (append list (list fnote)))
	    (walk doc)
	    (setf (tag-contents fnote) (list (make-footnote note)))
	    (walk note)))
	((vector :section options list)
	  (replace-tag! doc :id () (cons (make-section options) list))
	  (walk doc))
	((vector :subsection options list)
	  (replace-tag! doc :id () (cons (make-subsection options) list))
	  (walk doc))
	((vector :subsubsection options list)
	  (replace-tag! doc :id () (cons (make-subsubsection options) list))
	  (walk doc))
	((vector :table-of-contents options list)
	  (replace-tag! doc :id () (cons (apply #'make-toc options) list))
	  (walk doc))
	(* (walk doc))))

    (setf *toc* (nreverse *toc*))
    (when *footnotes*
      (setf (tag-contents fnotes)
	    (cons (id (hrule) (h4 *footnotes-title*))
		  (reverse *footnotes*))))
    (apply #'process-bibliography
           :display #'display-bibliography
           *bibliography-options*)
    (dolist (h (reverse *postprocess-hooks*))
      (funcall h))
    t))

(defun dump-document ()
  (html-dumper:html *document* *standard-output*)
  t)

(defun process-document ()
  (xxtime ("<== Postprocessing the document~%")
    (postprocess-document))
  (xxtime ("<== Dumping the document~%")
    (dump-document)))

(defun init ()
  (setf scribble:*scribble-preprocess* t
	scribble:*scribble-preprocessor* #'html-dumper:html-escape
	*exscribe-document-hook* 'process-document))