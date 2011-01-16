;;; recipe-mode.el --- A mode to make writing, finding recipes easy

;; Copyright (C) 2008-2010  Shelagh Manton <shelagh.manton@gmail.com>

;; Author: Shelagh Manton <shelagh.manton@gmail.com>
;; Keywords: recipes, convenience

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;; 02111-1307, USA.

;;; Commentary: This mode is intended to make it easy to write recipes quickly in text
;;; format, entering ingredients (and if I can manage it, translate imperial measurements
;;; into standard international measurements.), and finding the recipes again according to
;;; tags placed in the file along the lines of org-modes use of :tags: and org-agenda or
;;; multi-occur. I hope to eventually develop an exporter so that you can develop webpages
;;; for recipes, or export to latex or somehow to access the pdf for nice printouts of the
;;; recipes.  To get nice output for printing text, use ps-print-buffer-with-faces. Does a
;;; fairly nice job with the faces as they are.

;;;8<-----------------------------------------------
;;;
;;; purpose, to set up a recipe-mode where recipes can be easily entered and formatted.
;;; where tags are used to identify recipes so that they can be easily retrieved at a
;;; later stage using a variant of lgrep.
;;; 8<-------------------------------------------------

;;;Code:

;; Setup the global variables and access to customise.

;;requires
(require 'font-lock)
(require 'calc-units)
;; for later

;;; History:
;; 


;;; Code:
(when (featurep 'xemacs)
  (require 'overlay)
  (setq font-lock-mode t))
(require 'grep)
(require 'iimage)

(defgroup recipe nil
  "Options group for `recipe-mode'."
  :group 'recipe
  :prefix "recipe-")

(defvar recipe-mode-hook nil
  "Hook to run in `recipe-mode'.")

(defcustom recipe-dir nil
  "The directory where all the recipes are stored."
  :group 'recipe
  :type 'string
  )
;; these will make the inline images work properly.
(setq iimage-mode-image-search-path 'recipe-dir) 
(add-hook 'recipe-mode-hook 'turn-on-iimage-mode)

;;; key-map

(define-prefix-command 'rec-map nil 'Recipes)
(defvar recipe-mode-map
  (let ((recipe-mode-map (make-sparse-keymap)))
    recipe-mode-map)
  "Keymap for `recipe-mode'.")
(define-key recipe-mode-map "\C-ct" 'rec-map)
(define-key recipe-mode-map "\C-ci" 'recipe-insert)
(define-key recipe-mode-map "\C-cx" 'recipe-new-recipe);this should really be a global key-chord
(define-key recipe-mode-map "\C-ca" 'recipe-add-tags)
(define-key recipe-mode-map "\C-cm" 'recipe-import)
(define-key recipe-mode-map "\C-cn" 'recipe-numbers)
(define-key recipe-mode-map "\C-cp" 'recipe-insert-picture)
(define-key recipe-mode-map "\C-ctg" 'recipe-ingred)
(define-key recipe-mode-map "\C-ctt" 'recipe-title)
(define-key recipe-mode-map "\C-cti" 'recipe-instruct)
(define-key recipe-mode-map "\C-ctn" 'recipe-notes)
(define-key recipe-mode-map "\C-ctc" 'recipe-cook)
(define-key recipe-mode-map "\C-ctp" 'recipe-prep)
(define-key recipe-mode-map "\C-cts" 'recipe-serves)
(define-key recipe-mode-map "<RET>" 'recipe-indent-line)
(define-key recipe-mode-map "\C-cr" 'recipe-renumber-list)
(define-key recipe-mode-map "\C-cu" 'recipe-convert-units1)
(define-key recipe-mode-map "\C-ce" 'recipe-convert-temp)
;(global-set-key  "\C-c\C-f" 'recipe-find-file);this should really be a global key-chord
;(global-set-key  "\C-c\C-s" 'recipe-search);this should really be a global key-chord in your .emacs file!

;;;syntax-table probably no need for anything special here.

;;;faces for syntax highlighting and general prettiness of the text file.

(defvar recipe-title-face 'recipe-title-face
  "Recipe title.")
(defface recipe-title-face
  '((t :foreground "forestgreen"
       :weight bold
       :underline t
       :height 1.8
       :inherit variable-pitch
       :family "AvantGarde-Demi" ))
  "Font face used to highlight Titles."
  :group 'recipe)

(defvar recipe-ingredients-face 'recipe-ingredients-face
  "Ingredients title.")
(defface recipe-ingredients-face
  '((t :foreground "indian red"
       :slant oblique
       :weight bold
       :height 1.2
       :inherit variable-pitch
       :family "AvantGarde-Demi"))
  "Font face for Ingredients title."
  :group 'recipe)

(defvar recipe-instructions-face 'recipe-instructions-face
  "Instructions title.")
(defface recipe-instructions-face
  '((t :foreground "medium blue"
       :slant oblique 
       :weight bold
       :height 1.2
       :inherit variable-pitch
       :family "AvantGarde-Demi"))
  "Font face for Instructions title"
  :group 'recipe)

(defvar recipe-notes-face 'recipe-notes-face
  "Notes title.")
(defface recipe-notes-face
  '((t :foreground "dark salmon"
       :slant oblique
       :weight bold
       :height 1.2
       :inherit variable-pitch
       :family "AvantGarde-Demi"))
  "Font face for Notes title"
  :group 'recipe)

(defvar recipe-tags-face 'recipe-tags-face
  "Tags face.")
(defface recipe-tags-face
  '((t :foreground "dark magenta"
       :slant oblique
       :weight bold
       :height 1.2
       :inherit variable-pitch
       :family "AvantGarde-Demi"))
  "Font face for Tags"
  :group 'recipe)

;;; keywords and font-lock level

(defconst recipe-font-lock-keywords-1
  (list
   '("\\(* Title:\\s-*.*$\\)" . recipe-title-face)
   '("\\(* Ingredients:\\)" . recipe-ingredients-face)
   '("\\(* \\(Instructions\\|Method\\|Directions\\):\\)" . recipe-instructions-face)
   '("\\(* Notes:\\)" . recipe-notes-face)
   '("\\(* Temp: *[0-9][0-9]*\\(F\\|C\\)\\)" . recipe-instructions-face)
   '("\\(* Prep time: *.*$\\)" . recipe-instructions-face)
   '("\\(* Cooking time: *.*$\\)" . recipe-instructions-face)
   '("\\(* \\(?:\\(?:Serv\\(?:e\\|ing\\)\\|Yeild\\)s\\): *.*$\\)" . recipe-notes-face)
   '("\\(* Tags: *.*$\\)" . recipe-tags-face)
   )
  "Only one level of font-locking for `recipe-mode'.")

(defcustom recipe-font-lock-keywords 'recipe-font-lock-keywords-1
  "Font-lock highlighting for `recipe-mode'."
  :group 'recipe
  :type '(choice (const :tag "None at all" nil)
		 (const :tag "Highlighting" 'recipe-font-lock-keywords-1)))

;;; the meat of the mode.

;; a filter function to be called by define-skeleton to change imperial measurements to
;; international. Should this be of the format 1 lb (345 g),or just straight out
;; substitution? I think the () format might be easier, just a straight insert.
;; or maybe this is something which should be customised? defcustom filter-format none, type a or type b

(define-skeleton recipe-insert
  "To be called on opening a new file with extension of .recipe.
The recipe directory is set using customize."
   nil
  '(setq v1 "0")
  '(setq v2 "0")				; check this syntax.
  "* Title: " (skeleton-read "Name of recipe? ")
  \n \n
 > "* Ingredients:" \n
;;this following needs to be tested thoroughly!!!
 > ((recipe-measure-filter (skeleton-read "Ingredient? ")) '(setq v1 (int-to-string (1+ (string-to-number v1))))
    v1 ". "  str \n)   \n
 >  "* Instructions:" \n
 >  ("Instruction? " '(setq v2 (int-to-string (1+ (string-to-number v2))))
 >   v2 ". " str \n)
   \n
 >  "* Notes:" \n
 >  (skeleton-read "Any notes? ")
   \n \n
 >   "* Prep time: "
 >  (skeleton-read "Preparation time? ") \n
 >  "* Cooking time: "
 >  (skeleton-read "Cooking time? ") \n \n
 >  "* Tags: "
   ((upcase (skeleton-read "Tag? Used for find-recipe: ")) ":"  str) ":" \n
   \n
   )

;;;indentation 

(defcustom recipe-indent 4
  "User definable indentation"
  :group 'recipe
  :type '(integer))

(defun recipe-indent-line ()
  "Simple indenting function for recipes."
  (interactive)
  (forward-line 0)
  (if (bobp)
      (indent-line-to 0) ;indent beginning of file
    (let ((indentp t)
	  (regexp "^ *\\([0-9]+\. \\)")
	  cur-indent
	  regex) ;set up vars
      (if (looking-at regexp) ;this is straight forward
	  (setq cur-indent recipe-indent)
	(save-excursion ;otherwise
	  (while indentp ;look backwards for
	    (forward-line -1)
	    (if (looking-at regexp); a hint
		(progn ; and do this
		  (setq regex (string-match regexp regexp))
		  (setq cur-indent (+ recipe-indent (length (match-string 1 regex))))
		  (setq indentp nil)) ;set to nil to stop the loop.
	      (setq cur-indent 0))))) ;everywhere else don't indent.
      (indent-line-to cur-indent)))) ;do it!
     

;;;recipe conversion utilities

;; two part function something that uses unit might end up being the easiest way for me
;; since I can't work out how calc-eval works.  something which does the calculation and
;; outputs text.  something which inserts the result.  do-something=forward-word
;; forward-char insert con So now to work out how to make unit2 become automatic. Wrapper
;; script with an assoc list that chooses it automatically. Keep this as an interactive
;; function but use it within the wrapper script as a filter function for skeleton. Enough
;; for today.

(defvar recipe-units-alist
  '(("gal" . "litre") ("litre" . "pint")
    ("gal" . "liter") ("liter" . "pint")
    ("qt" . "cup") ("pt" . "cup")
    ("quart" . "cup") ("pint" . "cup")
    ("tbsp" . "ml") ("ml" . "tbsp")
    ("cup" . "cup") ("floz" . "ml")
    ("g" . "oz") ("oz" . "g")
    ("ml" . "tsp") ("tsp" . "ml")
    ("lb" . "g") ("kg" . "oz")
    ("pinch" . "pinch")
    ("dash" . "dash")
    ("drizzle" . "drizzle")))

(defun recipe-convert-units1 (unit1 unit2)
"Converts a unit to another inserts the result into the buffer.

Depends on the units utility."
;;this works with a few glitches I can't work out.
(interactive "sFrom: \nsTo: ")	
(let* ((thisarray
	(split-string
		 (shell-command-to-string
		  (concat "units '"(downcase unit1) "' '" (downcase unit2) "'"))))
       (thisnumber
	(number-to-string (round (string-to-number (cadr thisarray))))))
  (insert (concat " (" thisnumber unit2 ") "))))

(defun recipe-convert-units (unit1 unit2)
"Converts a unit to another inserts the result into the buffer."

(interactive "sFrom: \nsTo: ")
(require 'calc-units)
(string-match "\\([1-9][0-9]*\.?[0-9]*\\) *\\([a-z]*\\)" unit1)
(let ((unit (match-string 2 unit1))
;the following does not have any effect. How can I get floats to show only 2 decimal points?
(calc-float-format '(float 2)))
(calc-units-simplify-mode t)
(calc-eval unit1 'push)                                 
(calc-convert-units unit unit2)    ;how to get the calc buffer but in the background?
(insert (concat " ("  (calc-eval 1 'top) ") "))))

(defun recipe-measure-filter (unit1)
  "Filter function to change measures from imp to metric and vice-versa.

You might like to change these measures to a more suitable conversion. Use
`recipe-convert-units' directly on the selected measure."
  (interactive "sMeasure? ")
  (string-match "\\([1-9][0-9]*\.?[0-9]*\\) *\\([a-z]*\\)" unit1)
  (let* ((unit (match-string 2 unit1))
	(unit2 (cdr (assoc unit recipe-units-alist))))
;    (message "unit is %s" unit)
;    (message "unit2 is %s" unit2)
    (when (not (equal unit unit2))
      (recipe-convert-units unit1 unit2))))

(defun recipe-convert-temp (temp)
  "Changes temp data to farenheit/celcius in file."
  (save-excursion
    (string-match "[^-.0-9]\\([-.0-9]+\\) *\\([FC]\\)" temp)
      (let* ((top1 (match-beginning 1))
	     (bot1 (match-end 1))
	     (number (buffer-substring top1 bot1))
	     (top2 (match-beginning 2))
	     (bot2 (match-end 2))
	     (type (buffer-substring top2 bot2))) 
	(if (equal type "F")
	    (setq type "C"
		  number (calc-eval '("($ - 32)*5/9" calc-internal-prec 8) nil number))
	  (setq type "F"                             ;^how to round numbers?
		number (calc-eval '("$*9/5 + 32" calc-internal-prec 8) nil number)))
	(goto-char bot2)
	(if (string-match "\\.$" number)   ; change "37." to "37"
	    (setq number (substring number 0 -1)))
	(insert (concat " (" number type ")")))))

;;; finding the right recipe

;;;###autoload
(defun recipe-find-file (filename)
  "Finds recipes FILENAME in `recipe-dir'.

Will use ido functionality if available, otherwise normal file completion."
  (interactive
   (list (if (ido-mode)
	     (ido-completing-read "File: "
				  (directory-files recipe-dir nil ".recipe" nil))
	   (completing-read "File: "
			    (directory-files recipe-dir nil ".recipe" nil)))))
  (cd recipe-dir)
  (find-file filename)(recipe-mode))

(defun recipe-insert-picture (filename)
  "Insert a picture named FILENAME in buffer.

It expects the images to be found in `recipe-dir'.
Will use ido functionality if available, otherwise normal file completion."
  (interactive
   (list (if (ido-mode)
	     (ido-completing-read "File: "
				  (directory-files recipe-dir nil (regexp-opt image-file-name-extensions) nil))
	   (completing-read "File: "
			    (directory-files recipe-dir nil (regexp-opt image-file-name-extensions) nil)))))
  (insert (concat "\`file://" filename "\'")))

;;;###autoload
(defun recipe-new-recipe (name)
  "Open a new file called NAME and insert a skeleton `recipe-insert'."
  (interactive "sRecipe name: ")
  (find-file (concat recipe-dir "/" name ".recipe"))
  (recipe-mode)
  (if (= (point-min)(point-max)) ; Make sure file is empty.
      (recipe-insert)
    (error "This filename is second-hand!")))
;; could use this one command for both ie recipe-insert here somehow? if current-yank is 0 use recipe-insert
;; no, better to use prefix arg
;    (error "`recipe-dir' is not set")

(defun recipe-numbers (start end)
  "Insert sequential numbers at bol in region.

This indents to the var `recipe-indent' which defaults to 4."
  (interactive "r")
  (setq end (copy-marker end)); thank you snogglethorpe!
  (save-excursion
    (save-restriction
      (let ((n 1))
	(goto-char start)
	(while (< (point) end)
	  (forward-line 0)
	  (if (looking-at "^$") (forward-line 1)
			  (progn 
			    (indent-to recipe-indent)
			    (insert (concat (number-to-string n) ". "))
			    (setq n (1+ n))
			    (forward-line 1))))))))

;;stolen from http://www.emacswiki.org/emacs/RenumberList
(defun recipe-renumber-list (start end &optional num)
  "Renumber the list items in the current region.

 If optional prefix arg NUM is given, start numbering from that number
 instead of 1. Useful if your numbered list gets out of sync for some reason."
   (interactive "*r\np")
   (save-excursion
     (goto-char start)
     (setq num (or num 1))
     (save-match-data
       (while (re-search-forward "^ *[0-9]+\." end t)
 	(replace-match (concat (make-string recipe-indent ? ) (number-to-string num)"."))
 	(setq num (1+ num))))))                        ;;  ^ this is a space char! not just a space
   
;; Helper functions to tidy up a yanked recipe. Make the following part of the builtin
;; abbrev table.
(defun recipe-title ()
  "Insert a Title: header."
  (interactive)
  (forward-line 0)
  (insert "* Title: ")
  (end-of-line) (newline))

(defun recipe-notes ()
  "Insert a Notes: header"
  (interactive)
  (forward-line 0)
  (insert "* Notes: ")
  (newline))

(defun recipe-ingred ()
  "Insert an Ingredients: header."
  (interactive)
  (forward-line 0)
  (insert "* Ingredients:")
  (newline))

(defun recipe-instruct ()
  (interactive)
  (forward-line 0)
  (insert "* Instructions:")
  (newline))

(defun recipe-cook ()
  (interactive)
  (forward-line 0)
  (insert "* Cooking time: "))

(defun recipe-prep ()
  (interactive)
  (forward-line 0)
  (insert "* Prep time: "))

(defun recipe-serves ()
  (interactive)
  (forward-line 0)
  (insert "* Serves: "))

(defun recipe-temp ()
  (interactive)
  (forward-line 0)
  (insert "* Temp: "))

;;; abbrevs

(defvar recipe-mode-abbrev-table nil
  "Abbrev table to use in `recipe-mode' buffers")

(if recipe-mode-abbrev-table ()
(let ((ac abbrevs-changed))
  (define-abbrev-table 'recipe-mode-abbrev-table ())
  (define-abbrev recipe-mode-abbrev-table "ing" "" 'recipe-ingred)
  (define-abbrev recipe-mode-abbrev-table "ins" "" 'recipe-instruct)
  (define-abbrev recipe-mode-abbrev-table "inp" "" 'recipe-insert-picture)
  (define-abbrev recipe-mode-abbrev-table "tt" "" 'recipe-title)
  (define-abbrev recipe-mode-abbrev-table "nt" "" 'recipe-notes)
  (define-abbrev recipe-mode-abbrev-table "ck" "" 'recipe-cook)
  (define-abbrev recipe-mode-abbrev-table "pt" "" 'recipe-prep)
  (define-abbrev recipe-mode-abbrev-table "sv" "" 'recipe-serves)
  (define-abbrev recipe-mode-abbrev-table "tg" "" 'recipe-add-tags)
  (setq abbrevs-changed ac)))


(define-skeleton recipe-add-tags
  "Small skeleton to add tags to recipe already made.

One tag at a time, it will repeat until you enter an empty tag."
 nil
"* Tags: "
 ((upcase (read-string "Tag? Used for find-recipe: ")) ":"  str) ":" \n)

(defun recipe-import (name)
  "Open a file NAME in `recipe-dir' and yank a recipe into it.

Doesn't insert a skeleton `recipe-insert'.  But does insert a
yank.  Good for quick recipe insertion from text sources.
Another useful thing would be to set up a bash alias
recipe='emacsclient -f recipe-import' if you want quick access
for this function.  Sets `x-select-enable-clipboard' to true."
  (interactive "sName of recipe? ")
  (let ((x-select-enable-clipboard t))
  (find-file (concat recipe-dir "/" name ".recipe"))(yank)))

;;;###autoload
(defun recipe-search (regexp) ; &optional rest)
  "Search the directory for recipes that have the tag TAG.

TAG is a REGEXP.  This is a very simple-minded function and can
only look at one term at a time. But you can run this function on
the grep buffer again to narrow the search choice."
  ;; One day when I grow up and become a real programmer, I want to make this function
  ;; look at the whole file to see if it has beef *and* mushrooms, beef *or* mushrooms, or
  ;; beef and mushrooms *but not* onions. 
  (interactive "sTag: ")
  (grep-compute-defaults); who'da thunk it?
  (lgrep (upcase regexp) "*.recipe" recipe-dir)); the upcase makes it so only the Tags: line is looked at.

;; (defun recipe-search-regexp (regexp &optional &rest)
;; "Takes a list and makes an regexp phrase to feed to grep.
;; Understands "and" and "or" and "butnot"
;; (interactive (list (

;;; exporting functions Not yet implemented
;; make an alist of tags and values to fit into tex template. Thanks Sam Gillespie for
;; this idea ('tho he was thinking about using perl)

;;parsing for the recipe file ":\n" for separator
;;(defun recipe-book (files) "Export a book full of recipes listed in FILES."
;; (interactive (list)) ;some function to get files from a directory?))  (do-something))
;; ;; use cuisine.cls as it seems like the most polished and well set out.

;; (defun recipe-card ()
;; "Exports the current buffer to a card sized pdf file."
;; (interactive)
;; (do-something))
;; ;; recipecard.cls

;;;menus

 (easy-menu-define Recipes recipe-mode-map "Recipes"
  (append '("Recipes"
     ["Finding recipes" recipe-find-file t]
     ["Start a new recipe" recipe-new-recipe t]
     ("Utilities"
      ["Convert a measure" recipe-convert-units1  :help "Useful for manually converting units"]
      ["Convert temperatures" recipe-convert-temp t]
      ["Add numbers to region" recipe-numbers t]
      ["Renumber lines" recipe-renumber-list :help "Useful for when your numbers get out of sync"])
     ("Editing recipes"
      ["Insert a title heading" recipe-title  :help "Abbrev: tt" ]
      ["Insert a ingredients heading" recipe-ingred  :help "Abbrev: ing"]
      ["Insert an instruction heading" recipe-instruct  :help "Abbrev: ins"]
      ["Insert the time it takes to cook" recipe-cook  :help "Abbrev: ck"]
      ["How many serves" recipe-serves  :help "Abbrev: sv"]
      ["How long to prepare" recipe-prep  :help "Abbrev: pt"]
      ["Insert a picture" recipe-insert-picture  :help "Abbrev: inp"]
      ["Insert a notes heading" recipe-notes  :help "Abbrev: nt"]
      ["Add tags" recipe-add-tags  :help "Abbrev: tg"]))))

(easy-menu-add Recipes recipe-mode-map)

;;; finally, setting up the mode.
;;;###autoload
(define-derived-mode recipe-mode text-mode "recipes"
  "Major mode for editing and finding text recipes.

\\{recipe-mode-map}"
  (set (make-local-variable 'font-lock-defaults) '(recipe-font-lock-keywords))
  (set (make-local-variable 'font-lock-keywords-case-fold-search) 't)
  (set (make-local-variable 'skeleton-end-hook) 'nil)
  (set (make-local-variable 'indent-line-function) 'recipe-indent-line)
  (use-local-map recipe-mode-map)
 )

  (provide 'recipe-mode)
;;; recipe-mode.el ends here
