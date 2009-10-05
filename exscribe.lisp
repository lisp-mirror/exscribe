;;; -*- Mode: Lisp ; Base: 10 ; Syntax: ANSI-Common-Lisp -*-

#+xcvb
(module
 (:depends-on
  ("fare-utils/package"
   "fare-utils/basic-macros"
   "scribble/package"
   "scribble/scribble"
   "exscribe/packages"
   "exscribe/macros"
   "exscribe/specials")))

(in-package :exscribe)

;;; pathname munging

(defun add-exscribe-path (d)
  (setf *exscribe-path* (append *exscribe-path* (list (ensure-directory-pathname d)))))

(defun maybe-error (user-default if-error)
  (flet ((f (x)
	     (typecase x
	       (function (funcall x))
	       (t x))))
    (if (eq user-default :error) (f if-error) (f user-default))))

(defmacro on-error (user-default &body body)
  `(maybe-error ,user-default #'(lambda () ,@body)))

(defun find-file-in-path (f l &optional types (if-error :error))
  (let ((p (parse-namestring f))
	(tp (mapcar #'(lambda (type) (make-pathname :type type))
		    (typecase types
		      (list types)
		      ((or string pathname) (list types))))))
    (if (absolute-pathname-p p) p
	(or
	 (loop for d in l
	       for x = (merge-pathnames p d)
	       thereis (or (probe-file x)
			   (loop for tx in tp
				 thereis (probe-file (merge-pathnames x tx)))))
	 (on-error if-error
		   (error "Cannot find file ~A in search path ~A" f l))))))

(defun find-exscribe-file (f &optional (if-error :error))
  (etypecase f
    (stream f)
    (symbol (find-exscribe-file (string-downcase (symbol-name f))))
    ((or string pathname)
     (find-file-in-path f *exscribe-path* "scr" if-error))))

(defun read-eval-stream (s &key &allow-other-keys)
  (let ((forms (xxtime ("<== reading ~A~%" s)
		(loop with eof = '#:eof
		      for i = (read s nil eof) until (eq i eof)
		      collect i))))
    (xxtime ("<== evaluating ~A~%" s)
	   (loop for i in forms do (eval i)))))

(defun do-load (s &key &allow-other-keys)
  (typecase s
    (stream (read-eval-stream s))
    ((or string pathname)
     (with-open-file (i s :direction :input :if-does-not-exist :error)
       (read-eval-stream i)))))

(defun file-optimization ()
  (proclaim `(optimize (speed 1) (space 2)
              #-sbcl (debug 2)
              #+sbcl (compilation-speed 3)
              ,@(if *exscribe-verbose*
                    '((safety 3) #+sbcl (debug 2))
                    '((safety 1) #+sbcl (debug 1))))))
(defun style-optimization ()
  (proclaim `(optimize (speed 3) (space 2)
              #-sbcl (debug 2)
              #+sbcl (compilation-speed 3)
              ,@(if *exscribe-verbose*
                    '((safety 3) #+sbcl (debug 2))
                    '((safety 1) #+sbcl (debug 1))))))

(defun exscribe-load-file (file)
  (file-optimization)
  ;;(cl-launch:compile-and-load-file
  (load
   (find-exscribe-file file)
   :print *exscribe-verbose*
   :verbose *exscribe-verbose*))

(defun exscribe-load-style (style)
  (unless (member style *loaded-styles*)
    (push style *loaded-styles*)
    #+ecl (load (find-exscribe-file style)) #-ecl ;; recursive calls to compile-file seem to fail silently
    (let* ((file (find-exscribe-file style))
           (date (file-write-date file))
           (force (and *latest-style-date* (< date *latest-style-date*)))
           (object (cl-launch:compile-and-load-file
                    file :force-recompile force :verbose *exscribe-verbose*))
           (object-date (file-write-date object)))
      (setf *latest-style-date*
            (if *latest-style-date*
                (max *latest-style-date* object-date)
                object-date)))))

(defmacro style (f)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
    (exscribe-load-style ,f)))


;;; Syntax setup

(defun recreate-user-package ()
  (let ((use-list '(:exscribe-data :exscribe :fare-utils :scheme-makeup))
	(eu (find-package :exscribe-user)))
    (case *exscribe-mode*
      (html (push :exscribe-html use-list))
      (pdf (push :exscribe-typeset use-list)))
    (dolist (p (package-use-list eu)) (unuse-package p eu))
    (do-all-symbols (x eu) (unintern x eu))
    (dolist (p use-list) (use-package p eu))
    ;(shadowing-import 'scheme-makeup:map eu)
    (use-package :common-lisp eu)
    (setf *scribble-package* eu)
    (setf *loaded-styles* nil)
    (setf *latest-style-date* nil)
    t))

(defun klist (&rest r) (cons 'list r))

(defun configure-scribble-for-exscribe ()
  "This will make Scribble work with exscribe"
  (configure-scribble :package :exscribe-user
		      :cons 'default-scribble-cons
		      :list 'default-scribble-list
		      :default-head 'klist
		      :preprocess nil))

(defun init-exscribe ()
  (recreate-user-package)
  (configure-scribble-for-exscribe)
  (enable-scribble-syntax)
  (scheme-compat::set-scheme-macro-characters)
  (setf *exscribe-initialized* t))

(defun ensure-exscribe ()
  (unless *exscribe-initialized* (init-exscribe)))

(defun reset-exscribe ()
  (ensure-exscribe)
  (recreate-user-package)
  (reenable-scribble-syntax)
  (set-exscribe-mode *exscribe-mode*)
  t)

(defun set-exscribe-mode (mode)
  (ecase mode
      (html (exscribe-html::init))
      (txt (exscribe-txt::init))
      #+exscribe-typeset (pdf (exscribe-typeset::init))))

(defun call-with-exscribe-environment (thunk)
  (let ((*package* (find-package :exscribe-user))
	(*footnotes* nil)
	(*footnote-counter* 0)
	(*footnotes-title* "Notes")
	(*header* nil)
	(*footer* nil)
	(*section-counter* 0)
	(*bibliography* (exscribe-data::make-bib-table))
	(*bibliography-options* nil)
	(*bibliography-location* nil)
	(*bibliography-header* nil)
	(*toc* nil)
	(*postprocess-hooks* nil)
	(*print-pretty* nil)
	(*document* nil))
    (reset-exscribe)
    (funcall thunk)))

(defmacro with-exscribe-environment (&body body)
  `(call-with-exscribe-environment #'(lambda () ,@body)))

(defun exscribe-load-document (f)
  (with-exscribe-environment ()
    (exscribe-load-file f)))

(defun process-file (from
		     &key into translator
		     (verbose *exscribe-verbose*) (mode *exscribe-mode*))
  (let* ((input (find-exscribe-file from))
	 (suffix (second (assoc mode *mode-suffixes*)))
	 (output (or into
		     (let ((pn (make-pathname :type suffix :defaults input)))
		       (if translator (funcall translator pn) pn)))))
    (if (equal output "-")
	(exscribe-load-document input)
      (progn
	(ensure-directories-exist output :verbose verbose)
	(when verbose
	  (format t "Exscribe: compiling~%  ~A~%   into ~A~%" input output))
	(with-open-file (*standard-output*
			 output
			 :direction :output
			 :if-exists :supersede
                         :element-type #+pdf-binary #+sbcl :default #-sbcl '(unsigned-byte 8)
                                       #-pdf-binary #+sbcl 'character #-sbcl 'base-char
                         )
	  (exscribe-load-document input))))))

(defparameter *wild-path*
   (make-pathname :directory '(:relative :wild-inferiors)
		  :name :wild :type :wild :version :wild))
(defun wilden (path)
   (merge-pathnames *wild-path* path))

(defun process-many (src dst &rest files)
  (add-exscribe-path src)
  (loop with source = (wilden (ensure-directory-pathname src))
	with destination = (wilden (ensure-directory-pathname dst))
	with translator = #'(lambda (pn) (translate-pathname pn source destination))
	for f in files
	for input = (find-exscribe-file f) do
	(process-file input :translator translator :verbose t)))

(defun help (&optional (s *standard-output*))
  (format s
	  "exscribe ~A -- Lisp-programmable document authoring system.
Usage: exscribe [-I include]... [-v]~A [-o output] input
Homepage: http://www.cliki.net/Exscribe

Options:
 -h -?  --help                          show some help
 -v     --verbose                       output some information along the way
 -I     --include   /PATH/to/style/     add directory to include path
 -o     --output    destination-file    which file to create
 -H     --html                          select the html backend
 -P     --pdf                           select the PDF backend
 -M     --many      src dst files...    compile files from src to dst
 -D     --debug                         enable the Lisp debugger
        --repl                          provide the user a REPL
" *exscribe-version*
#+exscribe-typeset " [-H|-P]" #-exscribe-typeset ""))


(defun enable-debugging ()
  #+sbcl (sb-ext:enable-debugger)
  #+cmu (setf ext:*batch-mode* nil)
  nil)

(defun repl ()
  (enable-debugging)
  (loop do
      (format t "~&* ") (finish-output)
      (format t "~&~S~%" (eval (read)))))

(defun process-command-line (args)
  (if (null args)
      (help)
    (loop
      with inputs = nil with output = nil
      for a = (pop args) while a do
      (macrolet ((x (&rest l) `(member a ',l :test 'equal)))
	(cond
	 ((x "-h" "-?" "--help") (return (help)))
	 ((x "-H" "--html")
	  (setf *exscribe-mode* 'html))
	 #+exscribe-typeset
	 ((x "-P" "--pdf")
	  (setf *exscribe-mode* 'pdf))
	 ((x "-v" "--verbose")
	  (setf *exscribe-verbose* t))
	 ((x "-D" "--debug")
          (enable-debugging))
	 ((x "-M" "--many")
	  (when output (error "option --many invalid after option --output"))
	  (when inputs (error "option --many invalid after inputs are specified"))
	  (return (apply 'process-many args)))
	 ((x "-I" "--include")
	  (if args
	      (add-exscribe-path (pop args))
	    (error "missing include path argument")))
	 ((x "-o" "--output")
	  (if args (setf output (pop args))
	    (error "missing output argument")))
	 ((x "--repl")
          (let ((*standard-input* *terminal-io*)
                (*standard-output* *terminal-io*))
            (repl))
          (return))
	 ((equal (char a 0) #\-)
	  (error "Unrecognized option ~A" a))
	 (t (push a inputs))))
      finally
      (progn
	(unless (length=n-p inputs 1)
	  (error "Requiring a unique input, got ~A" inputs))
	(unless output
	  (error "No output specified"))
	(process-file (car inputs) :into output)))))

#+cl-launch
(defun main ()
  (add-exscribe-path *default-pathname-defaults*)
  (process-command-line cl-launch:*arguments*))