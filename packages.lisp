#+xcvb
(module
 (:depends-on
  ("fare-utils/package" "fare-matcher/packages" "scribble/package")))

(in-package :cl)

(defpackage :scheme-makeup
  #-allegro
  (:documentation "a poor emulation of Scheme in CL.
Meant to leverage simple code with Scheme syntax,
not to actually implement deep Scheme semantics.")
  (:use :common-lisp)
  (:shadow #:map)
  (:export
   ;;; Standard scheme stuff
   #:define #:set! #:begin #:else
   #:substring #:string-append #:string-length
   #:symbol->string #:string->symbol #:number->string
   #:for-each
   #:display
   #:string? #:symbol? #:number? #:pair? #:null? #:integer? #:zero? #:list?
   #:eq? #:eqv? #:equal? #:remainder #:modulo
   ;;; Standard scheme, but would requires shadowing
   ; #:map
   ;;; Stuff that we don't support: #:let #:call/cc
   ;;; bigloo-specific stuff
   #:file-exists?
   #:keyword? #:keyword->string #:define-macro
   ;;; Scribe stuff
   #:*scribe-background* #:*scribe-foreground* #:*scribe-tbackground*
   #:*scribe-format* #:*scribe-header* #:*scribe-footer*))

(defpackage :scheme-compat
  #-allegro
  (:documentation "innards of the Scheme in CL emulation")
  (:use :scheme-makeup :fare-utils :common-lisp)
  ;(:shadowing-import-from :scheme-makeup :map)
  (:export
   #:set-scheme-macro-characters))

(defpackage :exscribe
  #-allegro
  (:documentation "core infrastructure for exscribe")
  (:use :common-lisp :fare-utils :scribble)
  #+exscribe-typeset
  (:import-from :typeset
   #:*paper-size* #:*page-margins* #:*twosided* #:*toc-depth*
   #:*watermark-fn* #:*add-chapter-numbers*  ;;#:*verbose*
   #:*font-normal* #:*font-bold* #:*font-italic*
   #:*font-bold-italic* #:*font-monospace* #:*default-text-style*
   #:*chapter-styles*)
  #+exscribe-typeset
  (:export
   #:*paper-size* #:*page-margins* #:*twosided* #:*toc-depth*
   #:*watermark-fn* #:*add-chapter-numbers*  ;;#:*verbose*
   #:*font-normal* #:*font-bold* #:*font-italic*
   #:*font-bold-italic* #:*font-monospace* #:*default-text-style*
   #:*chapter-styles*)
  (:export
   ;;; scribble
   #:configure-scribble-for-exscribe
   #:klist #:*list
   ;;; macros
   #:xxtime
   ;;; globals
   #:*exscribe-version*
   #:*exscribe-path* #:*exscribe-mode* #:*exscribe-verbose*
   #:*exscribe-document-hook* #:*postprocess-hooks*
   #:*bibliography* #:*bibliography-location* #:*bibliography-options*
   #:*bibliography-header*
   #:*document* #:*document-title* #:*header* #:*footer*
   #:*footnotes* #:*footnote-counter* #:*footnotes-title*
   #:*section-counter* #:*subsection-counter* #:*subsubsection-counter*
   #:*section-name* #:*subsection-name* #:*subsubsection-name*
   #:*toc*
   #:*background* #:*foreground* #:*title-background* #:*section-title-background*
   ;;; the "markup" call syntax
   #:lambda-markup #:define-markup #:define-markup-macro
   ;;; Scribe stuff
   #:html #:pdf #:txt #:info
   #:document #:style))

(defpackage :exscribe-data
  #-allegro
  (:documentation "internal data representation for exscribe")
  (:use :exscribe :fare-utils :fare-matcher
	:common-lisp)
  (:export
   #:tag-attr #:tag #:xtag #:otag #:ctag
   #:make-xml-tag #:make-open-tag #:make-close-tag
   #:*list #:*list*
   #:id
   #:replace-tag! #:replace-cons! #:tag-contents #:copy-tag
   #:make-bib-table #:bib-sort/author #:get-bib-entry #:sort-bibliography
   #:make-document #:author #:ref
   #:table-of-contents #:footnote #:section #:subsection #:subsubsection
   #:bibliography
   #:book #:misc #:article
   #:title #:author #:year #:url #:journal #:month
   #:emph #:bold #:it #:underline #:center #:hr #:hrule #:footnote #:tt #:pre #:a
   #:blockquote #:sup #:sub
   #:p #:font #:table #:tr #:td #:th #:itemize #:item #:br #:span
   #:h1 #:h2 #:h3 #:h4 #:h5 #:h6
   #:small #:enumerate #:sc #:color #:code #:print-bibliography #:process-bibliography
   #:img #:image
   #:html #:head #:body
   #:brlist #:br* #:spacedlist #:spaced*
   #:walking-document #:walk #:recurse))

(defpackage :html-dumper
  #-allegro
  (:documentation "HTML dumping functions")
  (:use :common-lisp)
  (:export
   #:html #:html-stream #:html-escape
   #:html-string #:html-escape-stream
   #:html-tag-attr #:html-close-tag))

(defpackage :exscribe-html
  #-allegro
  (:documentation "HTML backend for exscribe")
  (:shadowing-import-from :exscribe-data #:html)
  (:use :exscribe-data :exscribe :fare-utils :fare-matcher
	:html-dumper :common-lisp))

(defpackage :exscribe-txt
  #-allegro
  (:documentation "Text backend for exscribe")
  (:use :exscribe-data :exscribe :fare-utils :fare-matcher :common-lisp)
  (:export #:extract-text #:normalize-text))

#+exscribe-typeset
(defpackage :exscribe-typeset
  #-allegro
  (:documentation "CL-Typesetting backend for exscribe")
  (:shadowing-import-from :exscribe-data #:image #:hrule #:table)
  (:use :exscribe-data :exscribe :fare-utils :fare-matcher
        :common-lisp :typeset)
  (:export))

(defpackage :exscribe-user
  ;(:shadowing-import-from :scheme-makeup :map)
  (:use :exscribe-html :exscribe-data :exscribe
	:fare-utils :scheme-makeup :common-lisp))