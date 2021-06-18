;;; krunk.el -- bare-bones jsp mode
;; copyleft (c) 2000 john manoogian III <jm3>

;; Author: john manoogian III <jm3>
;; Created: July, 2000
;; Keywords: languages, JSP, HTML
;; $Revision: 1.1 $
;; $Date: 2004/05/14 17:23:50 $

;;; Commentary:
; requires: lightning completion [ https://github.com/jhpalmieri/ultratex/blob/master/lisp/light.el ]

; TODO:
; add 'check-for-new-version'
; add font-locking on TAG(xxx) tags
; add compile-page-with-request-context defuns...
;   add request-parsing code, using props-mode
;   add harness-gen routines
; add compilation of pages outside the appserver-root via tmp-file creation
; handle server errors better
;   eg. appserver down, etc.
;   also include capability for handling custom error pages, eg.
;   "blah blah your page is down", etc.
;   add exception-in-pagecompile detection:
;   token: "The servlet named pageCompile at the requested URL"

(defgroup krunk nil
  "cc"
  :prefix "krunk-"
  :group 'languages)

(defun krunk ()
  "Emacs/XEmacs Major mode for editing jsp code, by jm3.
\\<krunk-mode-map>
Overview:
A jsp [java/javascript/html] editing mode, krunk provides a
power-editor's toolkit approach to jsp editing - no bullshit, quick
access to what you commonly use.

All of krunk's major commands are accessible from the krunk
menu -- click the 3rd button of your mouse to access it.

'krunk-compile-page'
'krunk-view-pagecompile'
'krunk-next-pagecompile-error'
'krunk-prev-pagecompile-error'

'krunk-insert-page'
'krunk-insert-runat-server-block'
'krunk-insert-table'
'krunk-insert-javascript'

\\[krunk-lightning-tag]   invokes completion of html/javascript/jsp primitives

Features:
In-line jsp compilation [test your code *inside your editor!*],
view-pagecompile popup menu, step forward/backward through pagecompile
errors, completion of Java types, HTML primitives [common tags, useful
constructs], and JSP primitives [request.getXXX(), import
declarations... ], popup menu for inserting code skeletons for pages,
tables, and script blocks.

Syntax highlighting via font-lock of:
    Java types,
    jsp declarations,
    jsp expression tags,
    html tags [needs work],
    Java line comments, and
    cvs/rcs $Id: ident strings.
    [note that html attributes are NOT highlighted -- i think that makes
    for total confetti code, something we want to avoid.]

Highlights:
Amount of servers needed to be installed on your box:        zero.
Number of Java classpath variables and other crap to set up: none.
Databases, web-servers and JDKs required for use:            nada.

History:
krunk began as a bastard child of several more complex modes,
including 'html-mode' and 'perl-mode' and whatever else looked
promising.  The first features were the font-locking regexps [syntax
colouring] and lightning completion tables [tab completion].  With
frequent use, the tab-key binding proved to be too disorienting, and
was re-mapped to ctl-c tab.

To Do: ???

Comments, Compliments, Complaints: @jm3 on Twitter>.

I hope that you enjoy krunk as much as i do."

;;; various syntax table defs and other chicanery
(defvar krunk-map nil
  "Keymap for Javascript (ECMAScript) major mode.")

(if krunk-map
    nil                             ; Leave it alone if it exists
  (progn                            ; Otherwise...
    (setq krunk-map (make-sparse-keymap))
    (define-key krunk-map "\C-c\C-a" 'setup-buffer)))

;; do not change these! use M-x customize instead.
(defcustom krunk-appserver-name  "devwas1.organic.com"
  "Name [in DNS] of your dev appserver"
  :type 'string
  :group 'krunk)

(defcustom krunk-appserver-port "80"
  "Port that your appserver listens on [defaults to 80]"
  :type 'string
  :group 'krunk)

(defcustom krunk-appserver-root "/clocal/www/web-data/websphere/"
  "Location in your filesystem where your appserver looks for pages"
  :type 'string
  :group 'krunk)

(defcustom krunk-appserver-sloth 10
  "Relative slowness of your appserver, on a scale of 1-20"
  :type 'integer
  :group 'krunk)

(defcustom krunk-correlate-errors-against-jsp nil
  "Attempt to match errors found in the pagecompile to the actual JSP source.
Note: this is quite tricky, and may require you to mess about with
'krunk-guess-next-error' and 'krunk-guess-prev-error'"
  :type 'boolean
  :group 'krunk)

(defcustom krunk-likes-to-debug t
  "Whether pagecompilation and viewing pagecompiled src should handle errors
[t / nil, defaults to t]"
  :type 'boolean
  :group 'krunk)

(defcustom krunk-pagecompile-path "/global/site/vendor/WebSphere/AppServer1/servlets/pagecompile/"
  "Location of your system's dev pagecompile dir
[string, defaults to nil]"
  :type 'string
  :group 'krunk)

(defcustom krunk-compile-page-if-uncompiled t
  "Whether krunk should try to compile the current buffer
if its pagecompiled source is missing or out of date
[t / nil, defaults to t]"
  :type 'boolean
  :group 'krunk)

(defcustom krunk-compile-pages-in-separate-buffers t
  "Whether krunk should use a separate buffers for compiling different JSP,
or whether there should be a single buffer, named *pagecompiles*
[t / nil, defaults to t]"
  :type 'boolean
  :group 'krunk)

(defcustom krunk-requests-dir "~/.requests"
  "Location krunk should use for saving your request sets
[string, defaults to \"~/.requests\""
  :type 'string
  :group 'krunk)

(defun krunk-newline-and-indent ()
  "Insert a newline, then indent appropriately.
Indentation is done using the value of `indent-line-function'."
  (interactive "*")
  (delete-region (point) (progn (skip-chars-backward " \t") (point)))
  (newline)
  (indent-relative-maybe))

  ;; misc crap that should be moved elsewhere
  (global-set-key (kbd "<return>") 'krunk-newline-and-indent)
  (interactive)
  (kill-all-local-variables)
  ;; this will make sure spaces are used instead of tabs
  (setq tab-width 2
    indent-tabs-mode nil)
  (setq mode-name "krunk")
  (setq major-mode 'krunk)
  (setq comment-start "//")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; menu-ing gook.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar krunk-mode-map (make-sparse-keymap)
  "Keymap for krunk mode.")
(defvar krunk-mode-menu nil)

(defun krunk-insert-page ()
  "Insert a skeleton html page at point.  Cursor is positioned
between the <body></body> tags."
  (interactive)
  (insert krunk-insert-page-str)
  (backward-char 17))

(defun krunk-insert-runat-server-block ()
  "Insert a skeleton jsp runat=\"server\" at point.
Cursor is positioned between the <script> tags."
  (interactive)
  (insert krunk-insert-runat-server-block)
  (backward-char 16))

(defun krunk-insert-table ()
  "Insert a skeleton html table at point.
Cursor is positioned between the <td></td> tags."
  (interactive)
  (insert krunk-insert-table-str)
  (backward-char 23))

(defun krunk-insert-javascript ()
  "Insert a skeleton javascript block at point.
Cursor is positioned within the browser-hiding <!-- // --> tags."
  (interactive)
  (insert krunk-insert-javascript-str)
  (backward-char 21))


(require 'easymenu)

(easy-menu-define
 krunk-mode-menu krunk-mode-map
 "Menu used in Crackhead mode"
 `("krunk"
   ["compile page"                       (krunk-compile-page) t]
   ["view pagecompile"                   (krunk-view-pagecompile t) t]
   ["jump to next error"                 (krunk-next-pagecompile-error) t]
   ["jump to previous error"             (krunk-prev-pagecompile-error) t]
    "---"
   ("insert code chunk" ["code chunklet insertion" beep t]
     ["html page"                        (krunk-insert-page) t]
     ["table"                            (krunk-insert-table) t]
     ["javascript block"                 (krunk-insert-javascript) t])
   ["help with krunk-mode"           (describe-mode) t]
   ["enable debugging"                   (setq krunk-likes-to-debug (not krunk-likes-to-debug))
     :style toggle :selected krunk-likes-to-debug]
   ["use JSP buffer for locating errors" (setq krunk-correlate-errors-against-jsp (not krunk-correlate-errors-against-jsp))
     :style toggle :selected krunk-correlate-errors-against-jsp]
))

(easy-menu-add krunk-mode-menu)

(define-key krunk-mode-map [(shift mouse-2)]
      'krunk-mouse-view-crossref)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compilation shite.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar krunk-last-error nil
"Holds the last page-compilation error seen.")



;; intended to be a primitive for use in generating request templates
;; and associating them with pages to be sent to the appserver.
;; ...
(defun krunk-build-request-harness ()
  "Not yet implemented -- use at your own risk."
  (interactive)
  ;; first ensure that krunk-requests-dir exists
  ;; then check for and create-if-missing request-harness.html
  (message "make-temp-name: %s" (concat (file-name-sans-extension (file-name-nondirectory (buffer-file-name))) ".html"))
)

(defun crack-get ( page-to-get &optional krunk-token-table)
  "Retrieve a page via HTTP.
PAGE-TO-GET: either the URI or the filesystem path.
CRACKHEAD-TOKEN-TABLE: alist of alternative tokens to use.
Useful for using krunk with different appservers and web servers.
Currently not used."

  (require 'telnet)
  (let (
    (crackproc "crack-telnet-proc")
    ;;symbol denoting that telnet buffer is ready to send [RTS]
    (krunk-telnet-rts-token  "Escape character")
    ;; symbol denoting that the http transaction has completed
    (krunk-http-stop-token "^HTTP/.* 400 Bad Request")
    ;; symbol denoting that the page didn't compile
    (krunk-pagecompile-had-errors-token "^Error getting compiled page.")
    (krunk-proc-buf-name (krunk-get-proc-buf-name page-to-get))
    (buf (get-buffer krunk-proc-buf-name))
    (page-within-appserver-scope nil)
  )

  ;; make sure that page lives within the appserver root -- if not, exit with error
  (if (string-match krunk-appserver-root page-to-get)
      (setq page-within-appserver-scope t))
  (if page-within-appserver-scope (progn

    (setq page-to-get (replace-in-string page-to-get krunk-appserver-root "/" ))
    (if (buffer-live-p buf)
      (progn
        (kill-buffer buf)
        (message "buffer %s extant, killing and re-creating" krunk-proc-buf-name)
      )
    )
    (setq buf (get-buffer-create krunk-proc-buf-name))
    (start-process-shell-command crackproc buf "telnet" (concat krunk-appserver-name " " krunk-appserver-port ))

    (setq count 0)
    (while (not (or
             (search-forward  krunk-telnet-rts-token nil t 1 buf)
             (search-backward krunk-telnet-rts-token nil t 1 buf)))
      (progn
        (message "[%s] no output yet, punting" count)
        (accept-process-output (get-process crackproc) 1)
        (setq count (1+ count))
      )
    )
    (message "fetching page")
    (telnet-simple-send buf (concat "GET " page-to-get ))
    (telnet-simple-send buf "QUIT")  ;; not correct, but it does the job
    (setq count 0)
    (while (and (not (or
                       (re-search-forward  krunk-http-stop-token nil t 1 buf)   ;; http still workin it.
                       (re-search-backward krunk-http-stop-token nil t 1 buf))) ;; ""
                (< count (+ 1 krunk-appserver-sloth))) ;; appserver took too long -- time out.

      (progn
        (message  "[%s] waiting on appserver to compile page... (ctl-g to cancel)" count)
        (accept-process-output (get-process crackproc) 1)
        (setq count (1+ count))
      )
    )
    (if (> count krunk-appserver-sloth)
      (message "timed out while waiting for appserver.")
      (progn
        (message "page loaded! [%s seconds]" count)
        ;; strip \r's, cause term is in raw mode, cause we're not using the telnet- primitives, cause we suck, cause...
        (goto-char (point-min buf) buf)
        (while (search-forward "\r" nil t 1 buf) (replace-match ""))

        ;; delete the telnet header crap.
        (goto-char (point-min buf) buf)
        (delete-region (point-min buf) (search-forward "QUIT" nil t 1 buf) buf)

        ;; delete the telnet/HTTP/proc-buffer footer crap
        (goto-char (point-max buf) buf)
        (delete-region (point-max buf) (re-search-backward krunk-http-stop-token (point-min buf) 1 1 buf) buf)

        ;; check if the compile succeeded or not
        (if (re-search-backward krunk-pagecompile-had-errors-token nil t 1 buf)
          (if krunk-likes-to-debug
            (krunk-next-pagecompile-error)  ;;page didn't compile -- time to debug."
            (message "your page didn't compile. turn on debugging to see the error.")
          )
          (message "your page compiled successfully!"))
      )
    )
  )
  (message "make sure that your page is within the appserver's root: %s" krunk-appserver-root))
))

;; for some reason, &optional isn't working here...
(defun krunk-find-pagecompile-error ( reverse-direction )
  "Internal Function.
Foundation for `krunk-next-pagecompile-error' and
`krunk-prev-pagecompile-error'.
REVERSE-DIRECTION: if t, krunk will search backwards for the next error."
  (let (
    (user-lames nil)
    (page-to-get (buffer-file-name))
    (pagecompile-error-token (concat "\\(" (file-name-nondirectory (krunk-get-pagecompile-name page-to-get)) "\\):\\([0-9]+\\):\\(.*\\)$"))
  ;;(pagecompile-error-token (concat "^\\(" (krunk-get-pagecompile-name page-to-get) "\\):\\([0-9]+\\):\\(.*\\)$"))
    (current-error nil)
    (current-error-mesg nil)
    (oldbuf (current-buffer))
    ;; this is the output of the compiled page
    (buf (get-buffer (krunk-get-proc-buf-name page-to-get)))
    ) ;; end locals

    ;; first check if the page is compiled within krunk
    (if (buffer-live-p buf)
      (setq user-lames nil)
      (if (y-or-n-p "Page is not currently compiled within krunk -- compile it?")
  	(progn
	(krunk-compile-page)
	(krunk-view-pagecompile)
	)
  	(setq user-lames t)))

    (if (not user-lames)
    (progn
      (save-excursion
      (if buf
        (set-buffer buf))
      (if reverse-direction
  	(if (re-search-backward pagecompile-error-token nil t) ;; t is needed for NO-ERROR
  	  (progn
  	    (setq current-error (string-to-number (match-string 2)))
  	    (message "found previous error at line: %s of compiled java source" current-error)
  	    (setq current-error-mesg (match-string 3)))
  	(message "No more errors."))
  	(if (re-search-forward pagecompile-error-token nil t) ;; t is needed for NO-ERROR
  	  (progn
  	    (setq current-error (string-to-number (match-string 2)))
  	    (message "found next error at line %s of compiled java source" current-error)
  	    (setq current-error-mesg (match-string 3)))
  	  (message "No more errors."))))

      (if current-error
      (progn
  	(message "have an error")
  	(if (not (buffer-live-p (get-buffer (file-name-nondirectory (krunk-get-pagecompile-name page-to-get)))))
  	  (krunk-view-pagecompile)
  	)
  	(setq buf (get-buffer (file-name-nondirectory (krunk-get-pagecompile-name page-to-get))))
  	(set-buffer buf) ;; this is the pre-compiled java output
  	(switch-to-buffer buf)
  	;; show the error in the compiled source [not currently in the jsp buffer....next iteration]
  	(goto-line current-error)
  	(recenter)
  	(krunk-highlight-line)
  	;; show the error in the minibuffer
  	(message current-error-mesg)

  	(if krunk-correlate-errors-against-jsp
  	  (progn
  	    ;; now, for the balls-out part -- try to correlate error match with JSP buffer
  	    (looking-at "\\s-*\\(.*\\)$")
  	    (setq krunk-error-to-match (match-string 1))
  	    (setq buf oldbuf)
  	    (switch-to-buffer buf)
  	    (if krunk-last-error
  	    (goto-char krunk-last-error))
  	    (if reverse-direction
  	      (setq krunk-last-error (search-backward krunk-error-to-match nil t))
  	      (setq krunk-last-error (search-forward  krunk-error-to-match nil t))
  	    )
  	    (krunk-highlight-line)
  	)
      )
    ))))))

(defun krunk-next-pagecompile-error ()
  "Step to next error in pagecompile."
  (interactive "*")
  (krunk-find-pagecompile-error nil)
)

(defun krunk-prev-pagecompile-error ()
  "Step to next error in pagecompile."
  (interactive "*")
  (krunk-find-pagecompile-error t)
)

(defun krunk-get-proc-buf-name ( page-to-get )
  "Internal Function.
Return the appropriate pagecompile buffer for the current jsp.
PAGE-TO-GET: filename for which to retreive process buffer."

  (if krunk-compile-pages-in-separate-buffers
    (setq krunk-proc-buf-name (concat (file-name-nondirectory page-to-get) " (results)"))
    (setq krunk-proc-buf-name "*pagecompiles*")
  )
)

(defun krunk-get-pagecompile-name ( page-to-get )
  "Internal Function.
Compute the name of pagecompiled java servlet source for the current buffer,
as the appserver would [assuming it is a .jsp file].
PAGE-TO-GET: filename of the JSP to compile."
(let (
  (page-file-name (replace-in-string page-to-get krunk-appserver-root "" ))
  (munged-file-name nil)
  )
  (setq munged-file-name
    (concat
      krunk-pagecompile-path
      "_"
      (replace-in-string
       (replace-in-string
        (replace-in-string page-file-name "/" "/_" )
        "\\." "_x" )
       "-" "_s" )
       ".java")
    )
))

(defun krunk-view-pagecompile ( &optional switch-to-pagecompile-p )

"View the page-compiled [technically, pre-compiled] Java source of the
current buffer's JSP.  If the page has not been compiled yet,
krunk prompt you, asking if you would like to compile it.

SWITCH-TO-PAGECOMPILE-P: if t, switch the the pagecompiled
buffer when done."

  (interactive)
  (let (
    (user-lames t)
    (page-to-get buffer-file-name))


  (if (string-match "\\.jsp$" (downcase page-to-get))
    (if (not (file-readable-p (krunk-get-pagecompile-name page-to-get)))
      (if (y-or-n-p "Page is not currently compiled within krunk -- compile it?")
        (progn
          (krunk-compile-page)
          (setq user-lames nil))
        (setq user-lames t)) ;; else user doesn't want to compile -- bail
      (setq user-lames nil)) ;; else page is readable
    (message "Sorry, %s doesn't appear to be a jsp file." (file-name-nondirectory page-to-get)))

  (unless user-lames
    (progn
      (find-file-noselect (krunk-get-pagecompile-name page-to-get)) ;; noselect : pasv open
      (if switch-to-pagecompile-p
       (switch-to-buffer (file-name-nondirectory (krunk-get-pagecompile-name page-to-get))))))))

(defun krunk-compile-page ()
  "Compile the Java Server Page contained in the current buffer."
  (interactive)
  (setq page-to-get buffer-file-name)
  (crack-get page-to-get)
)

(defun krunk-clear-highlighting ()
  "Internal function.
Wipe all error formatting from buffer."
  (interactive)
  (put-text-property (point-min) (point-max) 'face 'default)
)

(defun krunk-highlight-line ()
  "Internal function.
Use font-lock to highlight the current line -- used for showing errors."
  (krunk-clear-highlighting)
  (end-of-line)
  (setq eol (point))
  (beginning-of-line)
  (put-text-property (point) eol 'face 'highlight)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; completion shite.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; use [ctl-c tab] key for completion, since overriding tab is too annoying
(global-unset-key "\C-c\t")    (global-set-key "\C-c\t" 'krunk-lightning-tag)

(defun krunk-lightning-tag nil
  "Invoke krunk lightning completion."
  (interactive)
  (insert "")
  (completing-insert krunk-light-alist nil 1 'point-adjust-hook
                     "jm3 jsp tags"))

(defvar krunk-light-alist
  '(
    ('krunk-insert-foo-str -2)

    ;; Cunningly, tab now only sort of works. so hit space first. Shut up.
    ("    " -1)

    ;; JM3 STEEZE
    ;;;;;;;;;;;;;
    ("// DEBUG" 1)
    ("// PENDING(jm3)" 1)

    ;; BASIC FREEDOMS
    ("<a href=\"\"></a>" -6)
    ("<!--   -->" -5)
    ("<link rel=\"stylesheet\" href=\"\" type=\"text/css\">" -18)
    ("<img src=\"\" border=\"0\">" -13)

    ;; JSP TAGS
    ("<%=  %>" -3)
    ("<%@ import = \"\" %>" -4)
    ("request.getParameter( \"\" )" -3)
    ("request.getRequestURI()" 0)
    ("response.redirect(  )" -2)
    ("out.print(  );" -3)
    ("out.println(  );" -3)
    ("<script runAt=\"server\">

</script>" -11 )

    ;; JAVA FXXK
    ;;;;;;;;;;;;;;;;
    ("Boolean " 0)
    ("Double " 0)
    ("Enumeration " 0)
    ("Exception " 0)
    ("Hashtable " 0)
    ("Integer " 0)
    ("Object " 0)
    ("String " 0)

("function  () {

}
" -11)

    ;; HTML LISTS ARE NOT JUST FOR IDIOTS.
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ("<ol>\n<li> \n</ol>" -6)
    ("<ul>\n<li> \n</ul>" -6)
    ("<dl>\n  <dt> \n  <dd> \n</dl>" -12)
    ("<dt> \n<dd> " -6)

    ;; MISC GOOP.
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ("
<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">
  <tr>
    <td></td>
  </tr>
</table>
" -22)
    ("
  <tr>
    <td></td>
  </tr>
" -11)
    ("
<script language=\"javascript\">
<!--


// -->
</script>
"
 -18)

    ("<html>
<!-- $Id: krunk.el,v 1.1 2004/05/14 17:23:50 jm3 Exp $ -->
<head>
  <title> jm3 |  </title>
</head>
<body bgcolor=\"white\" text=\"black\" link=\"red\">

</body>
</html>
" -84)

    ;; these don't seem to work unless they're string literals, which blows
    ;;(krunk-insert-table-str -22)
    ;;(krunk-insert-table-row-str -11)
    ;;(krunk-insert-javascript-str -18)
    ;;(krunk-insert-page-str -84)
)
  "Lightning completion tags for doing completion on commonly
used JSP and HTML primitives.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; syntax-highlighting.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst krunk-font-lock-keywords
  '(;;
    ;; Fontify preprocessor statements as we do in `c-font-lock-keywords'.
    ;; Ilya Zakharevich <ilya@math.ohio-state.edu> thinks this is a bad idea.

    ;; from the javadox:
    ;; types
    ("\\<\\(Array\\|Boolean\\|boolean\\|Byte\\|Character\\|Class\\|ClassLoader\\|Double\\|Enumeration\\|Exception\\|Float\\|Math\\|Number\\|Properties\\|RE\\|String\\|StringBuffer\\|System\\|Vector\\|Object\\|Package\\|Short\\|Thread\\|ThreadGroup\\|ThreadLocal\\|Throwable\\|Hashtable\\|Integer\\|int\\|true\\|false\\|null\\|void\\|Void\\)\\>[ \t]*\\(\\sw+\\)?"
     (1 font-lock-type-face) (2 font-lock-variable-name-face nil t)
     )

    ;; html tags [now correctly does *not* font-lock text between tag pairs!]
   ("<[^%@!>].+?>" 0 font-lock-keyword-face t)

   ;; java line comments
   ("[^:]//.+$" 0 font-lock-comment-face t)

   ;; jsp declarations
   ("<%@ \\<\\(import\\)\\>[^%!>]+%>"
    (1 font-lock-preprocessor-face nil t)
    (2 font-lock-variable-face nil t)
   )

    ;; jsp expression tags
    ("<%=[^@%>]+%>" 0 font-lock-function-name-face t)

    ;; cvs/rcs ident strings, optionally within html comments
    ("\\(<!--\\)? *\\$\\(Id[^$]+\\)\\$ *\\(-->\\)?"
      (1 font-lock-comment-face      nil t)
      (2 font-lock-preprocessor-face nil t)
      (3 font-lock-comment-face      nil t)
    )

    ;; plain html comments
    ("<!.+>" 0 font-lock-comment-face nil nil)

    ;; keywords
    ("\\<\\(for\\|if\\|else\\|while\\|do\\|case\\|function\\|package\\|try\\|catch\\|throw\\|throws\\|return\\)\\>"
    (1 font-lock-function-name-face nil t)
    )

    )
  "Keywords for doing font-locking within krunk.")

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '((krunk-font-lock-keywords)
			     nil nil ((?\_ . "w"))))


;; code chunks used in both menu insertion and tab-completion


;; this shite is still not working; is lightning-mode not expanding
;; variable refs within krunk-light-alist??
(defvar krunk-insert-foo-str "foo foo foo!" )

(defvar krunk-insert-page-str "<html>
<!-- $Id: krunk.el,v 1.1 2004/05/14 17:23:50 jm3 Exp $ -->
<head>
  <title> jm3 |  </title>`
</head>
<body bgcolor=\"white\" text=\"black\" link=\"red\">

</body>
</html>
")

(defvar krunk-insert-table-str "
<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">
  <tr>
    <td></td>
  </tr>
</table>
")

(defvar krunk-insert-table-row-str "
  <tr>
    <td></td>
  </tr>
")

(defvar krunk-insert-runat-server-block-str "
<script runAt=\"server\">



</script>
")

(defvar krunk-insert-javascript-str "
<script language=\"javascript\">
<!--



// -->
</script>
")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(run-hooks 'krunk-hook))
(fset 'html-mode 'krunk)
(provide 'krunk)

;;; krunk.el ends here
