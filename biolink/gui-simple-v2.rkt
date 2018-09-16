#lang racket

;;; TODO FIXME

;;; NGLY1 in concept 2
;;; semmed
;;; interacts_with
;;; FAF1 gene


;;; Extract Pubmed ids from the alist of properties in the full path

;;; semmed:
;;; ("pmids" . "27748395")

;;; rtx:
;;;

;;; monarch-lite:
;;; 

;;; TODO FEATURES
;;;
;;; hotkeys for 'go', moving between panes--should be able to do everything from the keyboard

;;; Consider removing the 'go' button entirely

;;; Add default sorting, along with the ability to click on a column to sort by that column


(require
  racket/sandbox
  racket/gui/base
  racket/engine
  racket/date
  "db.rkt"
  "mk-db.rkt"
  (except-in racket/match ==))

(provide
  launch-gui)

;;; Synthetic predicates
;;; TODO FIXME -- are these the ideal predicates?
(define DECREASES_PREDICATE_NAMES '("negatively_regulates" "prevents" "treats"))
(define INCREASES_PREDICATE_NAMES '("positively_regulates" "causes" "produces"))

#|
concept format (subject or object), without dbname at front:

`(,cid ,cui ,name (,catid . ,cat) . ,props)

concept format (subject or object), with dbname at front (as used in fuzzy-concepto):

`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)


edge format, without dbname at front:

`(,eid (,scid ,scui ,sname (,scatid . ,scat) . ,sprops)
       (,ocid ,ocui ,oname (,ocatid . ,ocat) . ,oprops)
       (,pid . ,pred) . ,eprops)

edge format, with dbname at front (as used in edgeo):

`(,dbname ,eid (,scid ,scui ,sname (,scatid . ,scat) . ,sprops)
               (,ocid ,ocui ,oname (,ocatid . ,ocat) . ,oprops)
               (,pid . ,pred) . ,eprops)
|#



(displayln "Starting mediKanren Explorer...")

(displayln "Loading data sources...")


(displayln "loading semmed")
(define semmed (time (make-db "data/semmed")))
(displayln "loading monarch-lite")
(define monarch (time (make-db "data/monarch-lite")))
(displayln "loading rtx")
(define rtx (time (make-db "data/rtx")))
;(displayln "loading scigraph")
;(define scigraph (time (make-db "data/scigraph")))

(displayln "Finished loading data sources")



;;; TODO
;;;
;;; recognize concept name containing only whitespace as being empty
;;;
;;; use a reasonable default sorting for the concepts
;;;
;;; add ability to sort concept columns by clicking on column titles
;;;
;;; speed up concept search--seems much slower than in the old mediKanren
;;; (perhaps consider searching one DB exhaustively before moving to the next one)
;;;
;;; add ability to include only some of the data sources
;;;
;;; add ability to show and hide concept columns
;;;
;;; add ability to show date of data sources, and date/provenance for results
;;;
;;; add ability to specify/filter by data source or category


;;; ISSUES
;;;
;;; Seem to be missing '<gene> has_phenotype alacrima' entries for
;;; HEXA and GBA, even though these seem to be in the Monarch website.
;;; Why?
;;;
;;; Different data sources have what are effectively duplicate entries,
;;; but it isn't always easy to tell.
;;;
;;; Different data sources have different category numbers for the
;;; same CUI/entity.  For example, 'Imatinib mesylate' has the 'UMLS:C0939537'
;;; CUI in both Semmed and Scigraph, yet the category is (5 . "chemical_substance")
;;; for Semmed and (21 . "chemical_substance") for Scigraph.  Why?
;;; (The concept IDs are different in this case)


;; list membership
(define membero
  (lambda (x ls)
    (fresh (y rest)
      (== `(,y . ,rest) ls)
      (conde
        [(== x y)]
        [(=/= x y) (membero x rest)]))))

;; remove duplicates from a list
(define rem-dups
  (lambda (ls)
    (cond
      [(null? ls) '()]
      [(member (car ls) (cdr ls)) (rem-dups (cdr ls))]
      [else (cons (car ls) (rem-dups (cdr ls)))])))

#|
`(,dbname ,eid (,scid ,scui ,sname (,scatid . ,scat) . ,sprops)
               (,ocid ,ocui ,oname (,ocatid . ,ocat) . ,oprops)
               (,pid . ,pred) . ,eprops)
|#
(define (edgeo e)
  (conde
    ((fresh (ee) (== `(semmed . ,ee) e) (db:edgeo semmed ee)))
    ((fresh (ee) (== `(monarch . ,ee) e) (db:edgeo monarch ee)))
    ((fresh (ee) (== `(rtx . ,ee) e) (db:edgeo rtx ee)))
    ;;((fresh (ee) (== `(scigraph . ,ee) e) (db:edgeo scigraph ee)))
    ))

#|
`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
|#
(define (fuzzy-concepto n c)
  (conde
    ((fresh (cc) (== `(semmed . ,cc) c) (db:~name-concepto semmed n cc)))
    ((fresh (cc) (== `(monarch . ,cc) c) (db:~name-concepto monarch n cc)))
    ((fresh (cc) (== `(rtx . ,cc) c) (db:~name-concepto rtx n cc)))
    ;;((fresh (cc) (== `(scigraph . ,cc) c) (db:~name-concepto scigraph n cc)))
    ))



(define *verbose* #t)

;;; window size
(define HORIZ-SIZE 800)
(define VERT-SIZE 400)

(define input-response-latency 50)

(define MAX-CHAR-WIDTH 100)

(define DECREASES_PREDICATE_STRING "decreases [synthetic]")
(define INCREASES_PREDICATE_STRING "increases [synthetic]")
(define DECREASES_STAR_PREDICATE_STRING "decreases* [synthetic]")
(define INCREASES_STAR_PREDICATE_STRING "increases* [synthetic]")

(define SYNTHETIC_PREDICATE_STRINGS (list DECREASES_PREDICATE_STRING
                                          INCREASES_PREDICATE_STRING
                                          DECREASES_STAR_PREDICATE_STRING
                                          INCREASES_STAR_PREDICATE_STRING))


(define *concept-1-name-string* (box ""))
(define *concept-1-isa-flag* (box #f))
(define *concept-1-choices* (box '()))
(define *predicate-1-choices* (box '()))

(define *concept-2-name-string* (box ""))
(define *concept-2-isa-flag* (box #f))
(define *concept-2-choices* (box '()))
(define *predicate-2-choices* (box '()))

(define *concept-X-choices* (box '()))
(define *full-path-choices* (box '()))

;; saved choices used to generate
;; paths when clicking on a concept in the X list box.
(define *solution-concept-1-name-string* (box ""))
(define *solution-concept-2-name-string* (box ""))
(define *solution-concept-1-isa-flag* (box #f))
(define *solution-concept-2-isa-flag* (box #f))
(define *solution-concept-1-choices* (box '()))
(define *solution-concept-2-choices* (box '()))
(define *solution-predicate-1-choices* (box '()))
(define *solution-predicate-2-choices* (box '()))

(define (concept-list parent parent-search/isa-panel parent-list-boxes-panel label name-string isa-flag choices predicate-list-box-thunk predicate-choices edge-type)
  (define name-field (new text-field%
                          (label label)
                          (parent parent-search/isa-panel)
                          (init-value "")
                          (callback (lambda (self event)
                                      (define name (send self get-value))
                                      (set-box! name-string name)
                                      (set-box! predicate-choices '())
                                      (send (predicate-list-box-thunk) set '())
                                      (handle)))))
  (define isa-field (new check-box%
                         (parent parent-search/isa-panel)
                         (label "Include ISA-related concepts")
                         (value #f)
                         (callback (lambda (self event) (handle)))))
  (define concept-listbox (new list-box%
                               (label label)
                               (choices '())
                               (columns '("DB" "CID" "CUI" "Category" "Name"))
                               (parent parent-list-boxes-panel)
                               (style '(column-headers reorderable-headers extended))
                               (callback (lambda (self event)
                                           (define selections (send self get-selections))
                                           (define selected-concepts (foldr (lambda (i l) (cons (list-ref (unbox choices) i) l)) '() selections))
                                           (when *verbose*
                                             (printf "selected concepts:\n~s\n" selected-concepts))
                                           (define predicates
                                             (sort
                                              (remove-duplicates
                                               (run* (predicate)
                                                 (fresh (dbname e eid s o pid eprops)
                                                   (== `(,dbname ,eid ,s ,o (,pid . ,predicate) . ,eprops) e)
                                                   (case edge-type
                                                     [(in-edge)
                                                      (membero `(,dbname . ,o) selected-concepts)]
                                                     [(out-edge)
                                                      (membero `(,dbname . ,s) selected-concepts)]
                                                     [else (error 'concept-listbox/predicates)])
                                                   (edgeo e))))
                                              string<?))
                                           (set! predicates (append
                                                             (list
                                                              DECREASES_PREDICATE_STRING
                                                              INCREASES_PREDICATE_STRING
                                                              DECREASES_STAR_PREDICATE_STRING
                                                              INCREASES_STAR_PREDICATE_STRING)
                                                             predicates))
                                           (printf "predicates: ~s\n" predicates)
                                           (set-box! predicate-choices predicates)
                                           (send (predicate-list-box-thunk) set predicates)

                                           ;; unselect all items
                                           (for ([i (length predicates)])
                                                (send (predicate-list-box-thunk) select i #f))))))
  (define (mk-run)
    (let ((ans (if (equal? current-name "") ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
                   '()
                   (run* (q) (fuzzy-concepto current-name q)))))
      (let ((ans (remove-duplicates ans)))
        (let ((isa-ans (if (and (not (equal? current-name "")) current-isa)  ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
                           ;; only grab the first 50
                           (remove-duplicates
                            (run 50 (s-with-dbname) ;; 50 should probably be a parameter
                              (fresh (o-with-dbname dbname o s eid pid eprops e)
                                (membero o-with-dbname ans)
                                (== `(,dbname . ,o) o-with-dbname)
                                (== `(,dbname ,eid ,s ,o (,pid . "subclass_of") . ,eprops) e)
                                (== `(,dbname . ,s) s-with-dbname)
                                (edgeo e))))
                        '())))
          (let ((ans (remove-duplicates (append ans isa-ans))))
            (let ((ans (filter (lambda (x)
                                 (match x
                                   [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                                    (let ((preds
                                           (run 1 (pred)
                                             (fresh (o s eid eprops e)
                                               (case edge-type
                                                 [(out-edge) (== `(,cid ,cui ,name (,catid . ,cat) . ,props) s)]
                                                 [(in-edge) (== `(,cid ,cui ,name (,catid . ,cat) . ,props) o)])
                                               (== `(,dbname ,eid ,s ,o ,pred . ,eprops) e)
                                               (edgeo e)))))
                                      (not (null? preds)))]))
                        ans)))
              (set-box! choices ans)
              (send concept-listbox
                    set
                    (map (lambda (x)
                           (match x
                             [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                              (~a dbname #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                         ans)
                    (map (lambda (x)
                           (match x
                             [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                              (format "~a" cid)]))
                         ans)              
                    (map (lambda (x)
                           (match x
                             [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                              (format "~a" cui)]))
                         ans)
                    (map (lambda (x)
                           (match x
                             [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                              (~a `(,catid . ,cat) #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                         ans)              
                    (map (lambda (x)
                           (match x
                             [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                              (~a name #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                         ans))
              ;; unselect all items
              (for ([i (length ans)])
                   (send concept-listbox select i #f))))))))
  (define current-name "")
  (define current-isa #f)
  (define pending-name current-name)
  (define mk-thread #f)
  (define timer (new timer% (notify-callback
                             (lambda () (set! mk-thread (thread mk-run))))))
  (define (handle)
    (define new-name (send name-field get-value))
    (define new-isa (send isa-field get-value))
    (when (not (and (equal? current-name new-name)
                    (equal? current-isa new-isa)))
      (set! current-name new-name)
      (set! current-isa new-isa)
      (set-box! isa-flag current-isa)
      (and mk-thread (begin (kill-thread mk-thread) (set! mk-thread #f)))
      (send timer stop)
      (send timer start input-response-latency #t)))
  concept-listbox)

(define (launch-gui)
  (let ((frame (new frame%
                    (label "mediKanren Explorer v0.2")
                    (width HORIZ-SIZE)
                    (height VERT-SIZE))))

    (define go-callback
      (lambda (button event)
        (send running-status-description set-label "Running...")

        (define concept-1-selections (send concept-1-list-box get-selections))
        (define concept-2-selections (send concept-2-list-box get-selections))

        (define concept-1-selected-concepts
          (foldr (lambda (i l) (cons (list-ref (unbox *concept-1-choices*) i) l))
                 '()
                 concept-1-selections))
        (define concept-2-selected-concepts
          (foldr (lambda (i l) (cons (list-ref (unbox *concept-2-choices*) i) l))
                 '()
                 concept-2-selections))

        (printf "concept-1-selections: ~s\n" concept-1-selections)
        (displayln concept-1-selected-concepts)
        (printf "---------------------------------\n")
        (printf "concept-2-selections: ~s\n" concept-2-selections)
        (displayln concept-2-selected-concepts)
        (printf "---------------------------------\n")
                                       

        (define predicate-1-selections (send predicate-1-list-box get-selections))
        (define predicate-2-selections (send predicate-2-list-box get-selections))

        (define predicate-1-selected-predicates
          (foldr (lambda (i l) (cons (list-ref (unbox *predicate-1-choices*) i) l))
                 '()
                 predicate-1-selections))
        (define predicate-2-selected-predicates
          (foldr (lambda (i l) (cons (list-ref (unbox *predicate-2-choices*) i) l))
                 '()
                 predicate-2-selections))

                                       
        (printf "predicate-1-selections: ~s\n" predicate-1-selections)
        (displayln predicate-1-selected-predicates)
        (printf "---------------------------------\n")
        (printf "predicate-2-selections: ~s\n" predicate-2-selections)
        (displayln predicate-2-selected-predicates)
        (printf "---------------------------------\n")

                                       
        (find-X-concepts concept-1-selected-concepts
                         concept-2-selected-concepts
                         predicate-1-selected-predicates
                         predicate-2-selected-predicates
                         concept-X-list-box
                         running-status-description
                         full-path-list-box)
                                       
        ))
    
    (define concept-1-search/isa-panel (new horizontal-panel%
                                            (parent frame)
                                            (alignment '(left center))
                                            (stretchable-height #f)))
    (define concept-1-list-boxes-panel (new horizontal-panel%
                                            (parent frame)
                                            (alignment '(left center))))
    (define concept-1-list-box (concept-list frame concept-1-search/isa-panel concept-1-list-boxes-panel "Concept 1" *concept-1-name-string* *concept-1-isa-flag* *concept-1-choices* (lambda () predicate-1-list-box) *predicate-1-choices* 'out-edge))
    (define predicate-1-list-box (new list-box%
                                      (label "Predicate 1")
                                      (choices (unbox *predicate-1-choices*))
                                      (columns '("Name"))
                                      (parent concept-1-list-boxes-panel)
                                      (style '(extended))
                                      (callback go-callback)))
    (define edge-description (new message%
                                  (parent frame)
                                  (label "Concept 1 -> Predicate 1 -> [X] -> Predicate 2 -> Concept 2")))
    (define concept-2-search/isa-panel (new horizontal-panel%
                                            (parent frame)
                                            (alignment '(left center))
                                            (stretchable-height #f)))
    (define concept-2-list-boxes-panel (new horizontal-panel%
                                            (parent frame)
                                            (alignment '(left center))))
    (define predicate-2-list-box (new list-box%
                                      (label "Predicate 2")
                                      (choices (unbox *predicate-2-choices*))
                                      (columns '("Name"))
                                      (parent concept-2-list-boxes-panel)
                                      (style '(extended))
                                      (callback go-callback)))
    (define concept-2-list-box (concept-list frame concept-2-search/isa-panel concept-2-list-boxes-panel "Concept 2" *concept-2-name-string* *concept-2-isa-flag* *concept-2-choices* (lambda () predicate-2-list-box) *predicate-2-choices* 'in-edge))

    #|
    (define go-button (new button%
                           (parent frame)
                           (label "go!")
                           (callback go-callback)))
    |#
    
    (define running-status-description (new message%
                                            (parent frame)
                                            (label "                                                                ")))

    (define concept-X-list-box (new list-box%
                                    (label "X")
                                    (choices (unbox *concept-X-choices*))
                                    (columns '("DB" "CID" "CUI" "Category" "Name"))
                                    (parent frame)
                                    (style '(column-headers reorderable-headers single))
                                    (callback (lambda (button event)
                                                (send properties-list-box set '() '())
                                                (let ((sel* (send concept-X-list-box get-selections)))
                                                  (when (= (length sel*) 1)
                                                    (let ((selected-X (list-ref (unbox *concept-X-choices*) (car sel*))))
                                                      (printf "selected ~s\n" selected-X)
                                                      (define concept-1* (unbox *solution-concept-1-choices*))
                                                      (define concept-2* (unbox *solution-concept-2-choices*))
                                                      (printf "concept-1* ~s\n" concept-1*)
                                                      (printf "concept-2* ~s\n" concept-2*)
                                                      (define predicate-1* (unbox *solution-predicate-1-choices*))
                                                      (define predicate-2* (unbox *solution-predicate-2-choices*))
                                                      (printf "predicate-1* ~s\n" predicate-1*)
                                                      (printf "predicate-2* ~s\n" predicate-2*)
                                                          
                                                          
                                                      (define atomic/synthetic-predicate-1* (split-atomic/synthetic-predicates predicate-1*))
                                                      (define atomic/synthetic-predicate-2* (split-atomic/synthetic-predicates predicate-2*))

                                                      (define atomic-predicate-1* (car atomic/synthetic-predicate-1*))
                                                      (define atomic-predicate-2* (car atomic/synthetic-predicate-2*))

                                                      (define synthetic-predicate-1* (cadr atomic/synthetic-predicate-1*))
                                                      (define synthetic-predicate-2* (cadr atomic/synthetic-predicate-2*))


                                                      (define paths '())
                                                          
                                                          
                                                      (cond
                                                        [(and (equal? (unbox *solution-concept-1-name-string*) "")
                                                              (equal? (unbox *solution-concept-2-name-string*) ""))
                                                         ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
                                                         (set! paths '())]
                                                        [(equal? (unbox *solution-concept-1-name-string*) "")
                                                         ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
                                                         (set! paths '())
                                                         ;; run synthetic queries here
                                                         (set! paths
                                                               (remove-duplicates
                                                                (append paths
                                                                        (run* (q)
                                                                          (fresh (e dbname eid x o pid pred eprops)
                                                                            (== (list `(,dbname ,eid ,x ,o (,pid . ,pred) ,eprops)) q)
                                                                            (== `(,dbname . ,x) selected-X)
                                                                            (== `(,dbname ,eid ,x ,o (,pid . ,pred) . ,eprops) e)
                                                                            (membero `(,dbname . ,o) concept-2*)
                                                                            (membero pred atomic-predicate-2*)
                                                                            (edgeo e)))))
                                                               #| ;; v0.1 version
                                                               (remove-duplicates
                                                               (append paths
                                                               (run* (q)
                                                               (fresh (e2
                                                               x
                                                               o p2 t2 t3 r2)
                                                               (== (list e2) q)
                                                               (== selected-X x)
                                                               (== e2 `(,x ,o ,p2 ,t2 ,t3 ,r2))
                                                               (membero o concept-2*)
                                                               (membero p2 atomic-predicate-2*)
                                                               (edgeo e2)))))
                                                               |#
                                                               )]
                                                        [(equal? (unbox *solution-concept-2-name-string*) "")
                                                         ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
                                                         (set! paths '())
                                                         ;; run synthetic queries here
                                                         (set! paths
                                                               (remove-duplicates
                                                                (append paths
                                                                        (run* (q)
                                                                          (fresh (e dbname eid s x pid pred eprops)
                                                                            (== (list `(,dbname ,eid ,s ,x (,pid . ,pred) ,eprops)) q)
                                                                            (== `(,dbname . ,x) selected-X)
                                                                            (== `(,dbname ,eid ,s ,x (,pid . ,pred) . ,eprops) e)
                                                                            (membero `(,dbname . ,s) concept-1*)
                                                                            (membero pred atomic-predicate-1*)
                                                                            (edgeo e)))))
                                                               #| ;; v0.1 version
                                                               (remove-duplicates
                                                               (append paths
                                                               (run* (q)
                                                               (fresh (e1
                                                               x
                                                               s
                                                               p1 ts t1 r1)
                                                               (== (list e1) q)
                                                               (== selected-X x)
                                                               (== e1 `(,s ,x ,p1 ,ts ,t1 ,r1))
                                                               (membero s concept-1*)
                                                               (membero p1 atomic-predicate-1*)
                                                               (edgeo e1)))))
                                                               |#
                                                               )]
                                                        [else
                                                         (set! paths '())
                                                         ;; run synthetic queries here
                                                         (set! paths                                                                   
                                                               (remove-duplicates
                                                                (append paths
                                                                        (run* (q)
                                                                          (fresh (e1 e2 dbname eid1 eid2 s x o pid1 pid2 p1 p2 eprops1 eprops2)
                                                                            (== `(,dbname . ,x) selected-X)
                                                                            (== (list
                                                                                 `(,dbname ,eid1 ,s ,x (,pid1 . ,p1) ,eprops1)
                                                                                 `(,dbname ,eid2 ,x ,o (,pid2 . ,p2) ,eprops2))
                                                                                q)
                                                                            (== `(,dbname ,eid1 ,s ,x (,pid1 . ,p1) . ,eprops1) e1)
                                                                            (== `(,dbname ,eid2 ,x ,o (,pid2 . ,p2) . ,eprops2) e2)
                                                                            (membero `(,dbname . ,s) concept-1*)
                                                                            (membero `(,dbname . ,o) concept-2*)
                                                                            (membero p1 atomic-predicate-1*)
                                                                            (membero p2 atomic-predicate-2*)
                                                                            (edgeo e1)
                                                                            (edgeo e2)))))
                                                               #| ;; v0.1 version
                                                               (remove-duplicates
                                                               (append paths
                                                               (run* (e1 e2)
                                                               (fresh (x
                                                               s
                                                               o p1 p2 ts t1 t2 t3 r1 r2)
                                                               (== selected-X x)
                                                               (== e1 `(,s ,x ,p1 ,ts ,t1 ,r1))
                                                               (== e2 `(,x ,o ,p2 ,t2 ,t3 ,r2))
                                                               (membero s concept-1*)
                                                               (membero o concept-2*)
                                                               (membero p1 atomic-predicate-1*)
                                                               (membero p2 atomic-predicate-2*)
                                                               (edgeo e1)
                                                               (edgeo e2)))))
                                                               |#
                                                               )])

                                                      (printf "paths: ~s\n" paths)
                                                      (newline)
                                                          
                                                      #|
                                                          ;; (printf "sorting paths: ~s\n" paths) ;

                                                          ;; This sorting affects the order of the "Path" list for the selected concept. ;
                                                      (set! paths (map remove-duplicate-pubrefs/path (sort-paths paths)))

                                                          ;; (printf "sorted paths: ~s\n" paths) ;
                                                      |#

                                                          
                                                      (define flattened-paths
                                                        (let ((ls (foldr
                                                                   (lambda (p l)
                                                                     (cons
                                                                      'path-separator
                                                                      (append (reverse p) l)))
                                                                   '()
                                                                   paths)))
                                                          (if (null? ls)
                                                              ;; ls should never be null!
                                                              '()
                                                              (reverse (cdr ls)))))



                                                      (define full-path-dbname-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a dbname)]))
                                                             flattened-paths))

                                                      (define full-path-eid-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a eid)]))
                                                             flattened-paths))
                                                          
                                                      (define full-path-subj-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a subj #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))
                                                          
                                                      (define full-path-pred-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a `(,pid . ,pred) #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))
                                                          
                                                      (define full-path-obj-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a obj #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))
                                                          
                                                      (define full-path-subj-cat-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid (,cid ,cui ,name (,catid . ,cat) . ,props) ,obj (,pid . ,pred) ,eprops)
                                                                  (~a `(,catid . ,cat) #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))

                                                      (define full-path-obj-cat-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj (,cid ,cui ,name (,catid . ,cat) . ,props) (,pid . ,pred) ,eprops)
                                                                  (~a `(,catid . ,cat) #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))

                                                      #|
                                                      (define full-path-eprops-list
                                                        (map (lambda (x)
                                                               (match x
                                                                 ['path-separator "----"]
                                                                 [`(,dbname ,eid ,subj ,obj (,pid . ,pred) ,eprops)
                                                                  (~a eprops #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                             flattened-paths))
                                                      |#

                                                      (send full-path-list-box
                                                            set
                                                            full-path-dbname-list
                                                            full-path-eid-list
                                                            full-path-subj-list
                                                            full-path-pred-list
                                                            full-path-obj-list
                                                            full-path-subj-cat-list
                                                            full-path-obj-cat-list
                                                            ;;full-path-eprops-list
                                                            )
                                                          
                                                          
                                                      #| ;; v0.1 version
                                                      (define full-path-subj-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a subj #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (define full-path-obj-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a obj #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (define full-path-pred-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a pred #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (define full-path-subj-type-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a subj-type #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (define full-path-obj-type-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a obj-type #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (define full-path-pubmed*-list
                                                      (map (lambda (x)
                                                      (match x
                                                      [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                                                      (~a pubmed* #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
                                                      flattened-paths))

                                                      (send full-path-list-box
                                                      set
                                                      full-path-subj-list
                                                      full-path-obj-list
                                                      full-path-pred-list
                                                      full-path-subj-type-list
                                                      full-path-obj-type-list
                                                      full-path-pubmed*-list)
                                                      |#

                                                      (set-box! *full-path-choices* flattened-paths)

                                                      ;; unselect all items
                                                      (for ([i (length flattened-paths)])
                                                           (send full-path-list-box select i #f))

                                                      ))
                                                  (void))))))

    (define full-path-list-box (new list-box%
                                    (label "Paths")
                                    (choices (unbox *full-path-choices*))
                                    (columns '("DB" "EID" "Subject" "Predicate" "Object" "Subj Cat" "Obj Cat"))
                                    (parent frame)
                                    (style '(column-headers reorderable-headers extended))
                                    (callback (lambda (self event)
                                                (when *verbose*
                                                  (printf "(unbox *full-path-choices*):\n~s\n" (unbox *full-path-choices*)))
                                                (define selections (send self get-selections))
                                                (when *verbose*
                                                  (printf "selection for full path:\n~s\n" selections))
                                                (define selected-full-paths
                                                  (foldr (lambda (i l) (cons (list-ref (unbox *full-path-choices*) i) l))
                                                         '()
                                                         selections))
                                                (for-each
                                                    (lambda (x)
                                                      (match x
                                                        ['path-separator
                                                         (send properties-list-box set '() '())]
                                                        [`(,dbname ,eid ,subj ,obj ,p ,eprops)
                                                         (send properties-list-box
                                                               set
                                                               (map
                                                                 (lambda (p)
                                                                   (~a (car p) #:max-width MAX-CHAR-WIDTH #:limit-marker "..."))
                                                                 eprops)
                                                               (map
                                                                 (lambda (p)
                                                                   (~a (cdr p) #:max-width MAX-CHAR-WIDTH #:limit-marker "..."))
                                                                 eprops))]))
                                                    selected-full-paths)                                                
                                                (when *verbose*
                                                  (printf "selected full path:\n")
                                                  (for-each
                                                    (lambda (x)
                                                      (match x
                                                        ['path-separator
                                                         (printf "-----------------------\n")]
                                                        [`(,dbname ,eid ,subj ,obj ,p ,eprops)
                                                         (pretty-print `(,dbname ,eid ,subj ,obj ,p ,eprops))]))
                                                    selected-full-paths))
                                                ))))

    (define properties-list-box (new list-box%
                                     (label "Properties")
                                     (choices (unbox *full-path-choices*))
                                     (columns '("Property" "Value"))
                                     (parent frame)
                                     (style '(column-headers reorderable-headers extended))
                                     (callback (lambda (self event)
                                                 (void)))))
        
    (send frame show #t)
    ))


(define (split-atomic/synthetic-predicates predicate*)

  (define atomic-predicate* predicate*)
  (define synthetic-predicate* '())

  (set! synthetic-predicate* (filter (lambda (pred) (member pred SYNTHETIC_PREDICATE_STRINGS))
                                     atomic-predicate*))

  (when (member DECREASES_PREDICATE_STRING atomic-predicate*)
    ;; v0.1 predicates: (set! atomic-predicate* (cons "INHIBITS" (cons "PREVENTS" (cons "TREATS" atomic-predicate*))))
    (set! atomic-predicate* (append DECREASES_PREDICATE_NAMES atomic-predicate*))
    (set! synthetic-predicate* (remove DECREASES_PREDICATE_STRING synthetic-predicate*)))

  (when (member INCREASES_PREDICATE_STRING atomic-predicate*)
    ;; v0.1 predicates: (set! atomic-predicate* (cons "STIMULATES" (cons "AUGMENTS" (cons "CAUSES" atomic-predicate*))))
    (set! atomic-predicate* (append INCREASES_PREDICATE_NAMES atomic-predicate*))
    (set! synthetic-predicate* (remove INCREASES_PREDICATE_STRING synthetic-predicate*)))

  (set! atomic-predicate* (filter (lambda (pred) (not (member pred SYNTHETIC_PREDICATE_STRINGS)))
                                  atomic-predicate*))

  (set! atomic-predicate* (remove-duplicates atomic-predicate*))

  (printf "atomic-predicate*: ~s\n" atomic-predicate*)
  (printf "synthetic-predicate*: ~s\n" synthetic-predicate*)

  (list atomic-predicate* synthetic-predicate*)
  )


(define (find-X-concepts concept-1* concept-2* predicate-1* predicate-2* concept-X-list-box running-status-description full-path-list-box)

  (define start-time (current-milliseconds))

  (printf "\nfinding concepts X for which\n[C1] -> P1 -> [X] -> P2 -> [C2]\n")
  (printf "=============================\n")

  (define atomic/synthetic-predicate-1* (split-atomic/synthetic-predicates predicate-1*))
  (define atomic/synthetic-predicate-2* (split-atomic/synthetic-predicates predicate-2*))

  (define atomic-predicate-1* (car atomic/synthetic-predicate-1*))
  (define atomic-predicate-2* (car atomic/synthetic-predicate-2*))

  (define synthetic-predicate-1* (cadr atomic/synthetic-predicate-1*))
  (define synthetic-predicate-2* (cadr atomic/synthetic-predicate-2*))

  (define all-X-concepts-with-edges '())

  (printf "atomic/synthetic-predicate-1*: ~s\n" atomic/synthetic-predicate-1*)
  (printf "atomic/synthetic-predicate-2*: ~s\n" atomic/synthetic-predicate-2*)
  (newline)
  (printf "atomic-predicate-1*: ~s\n" atomic-predicate-1*)
  (printf "atomic-predicate-2*: ~s\n" atomic-predicate-2*)
  (newline)
  (printf "synthetic-predicate-1*: ~s\n" synthetic-predicate-1*)
  (printf "synthetic-predicate-2*: ~s\n" synthetic-predicate-2*)
  (newline)
  
  #|
  (define (stream-query/predicate/trust predicate&nedges&ntrusted->ss)
    (start-streaming
      (foldr
        (lambda (pname ss)
          (define predicate (cdr (assoc pname synthetic-relations)))
          (define (run/ranked nedges ntrusted)
            (stream-cons
              (begin
                (displayln "***************************************")
                (printf "Path length: ~s, Trusted edge count: ~s\n" nedges ntrusted)
                (displayln "***************************************")
                (flush-output))
              (predicate&nedges&ntrusted->ss predicate nedges ntrusted)))
          (stream-append
            (stream-cons
              (printf "Streaming synthetic predicate ~s\n" pname)
              (stream-append
                (run/ranked 1 1)
                (stream-append
                  (run/ranked 1 0)
                  (let loop ((nedges 2) (ntrusted 2))
                    (if (< 4 nedges)
                      '()
                      (stream-append
                        (run/ranked nedges ntrusted)
                        (loop (+ nedges 1) (+ ntrusted 1))))))))
            (stream-cons
              (printf "Finished streaming synthetic predicate ~s\n" pname)
              ss)))
        (stream-cons (begin (displayln "Finished all streaming.")
                            (flush-output))
                     '())
        synthetic-predicate-2*)))
  |#

  (cond
    [(and (equal? (unbox *concept-1-name-string*) "")  ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
          (equal? (unbox *concept-2-name-string*) ""))
     (set! all-X-concepts-with-edges '())]
    [(equal? (unbox *concept-1-name-string*) "")  ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
     (set! all-X-concepts-with-edges '())
     ;; run synthetic queries here
     #|
     (stream-query/predicate/trust
       (lambda (predicate nedges ntrusted)
         (run-stream
           (path-url)
           (fresh (m o path)
             (path-length-trustedo path nedges ntrusted)
             (membero o concept-2*)
             (predicate m o path)
             (path/urlo path path-url)
             ;(== path path-url)
             ))))
     |#
     (set! all-X-concepts-with-edges
           (remove-duplicates
            (append all-X-concepts-with-edges
                    (run* (q)
                      (fresh (dbname eid s o pid pred eprops e)
                        ;; TODO FIXME -- epropos may contain pubmed ids--how to extract it, or other evidence?
                        (== (list dbname s (list eprops) (list e)) q)
                        (== `(,dbname ,eid ,s ,o (,pid . ,pred) . ,eprops) e)
                        (membero `(,dbname . ,o) concept-2*)
                        (membero pred atomic-predicate-2*)
                        (edgeo e)))
                    #| ;; v0.1 version
                    (run* (q)
                      (fresh (m
                              e2
                              o p2 t2 t3 r2)
                        (== (list m (list r2) (list e2)) q)
                        (== e2 `(,m ,o ,p2 ,t2 ,t3 ,r2))
                        (membero o concept-2*)
                        (membero p2 atomic-predicate-2*)
                        (edgeo e2)))
                    |#
                    )))]
    [(equal? (unbox *concept-2-name-string*) "")  ;; TODO FIXME -- handle spaces, tabs, whatever (regex for all whitespace)
     (set! all-X-concepts-with-edges '())
     ;; run synthetic queries here
     (set! all-X-concepts-with-edges
           (remove-duplicates
            (append all-X-concepts-with-edges
                    (run* (q)
                      (fresh (dbname eid s o pid pred eprops e)
                        ;; TODO FIXME -- epropos may contain pubmed ids--how to extract it, or other evidence?
                        (== (list dbname o (list eprops) (list e)) q)
                        (== `(,dbname ,eid ,s ,o (,pid . ,pred) . ,eprops) e)
                        (membero `(,dbname . ,s) concept-1*)
                        (membero pred atomic-predicate-1*)
                        (edgeo e)))
                    #| ;; v0.1 version
                    (run* (q)
                      (fresh (m
                              e1 e2
                              s
                              p1 ts t1 r1)
                        (== (list m (list r1) (list e1)) q)
                        (== e1 `(,s ,m ,p1 ,ts ,t1 ,r1))
                        (membero s concept-1*)
                        (membero p1 atomic-predicate-1*)
                        (edgeo e1)))
                    |#
                    )))]
    [else
     (set! all-X-concepts-with-edges '())
     ;; run synthetic queries here
     (set! all-X-concepts-with-edges
           (remove-duplicates
            (append all-X-concepts-with-edges
                    (run* (q)
                      (fresh (dbname eid1 eid2 s m o pid1 pid2 p1 p2 eprops1 eprops2 e1 e2)
                        (== (list dbname m (list eprops1 eprops2) (list e1 e2)) q)
                        (== `(,dbname ,eid1 ,s ,m (,pid1 . ,p1) . ,eprops1) e1)
                        (== `(,dbname ,eid2 ,m ,o (,pid2 . ,p2) . ,eprops2) e2)
                        (membero `(,dbname . ,s) concept-1*)
                        (membero `(,dbname . ,o) concept-2*)
                        (membero p1 atomic-predicate-1*)
                        (membero p2 atomic-predicate-2*)
                        (edgeo e1)
                        (edgeo e2)))
                    #| ;; v0.1 version
                    (run* (q)
                      (fresh (m
                              e1 e2
                              s
                              o p1 p2 ts t1 t2 t3 r1 r2)
                        (== (list m (list r1 r2) (list e1 e2)) q)
                        (== e1 `(,s ,m ,p1 ,ts ,t1 ,r1))
                        (== e2 `(,m ,o ,p2 ,t2 ,t3 ,r2))
                        (membero s concept-1*)
                        (membero o concept-2*)
                        (membero p1 atomic-predicate-1*)
                        (membero p2 atomic-predicate-2*)
                        (edgeo e1)
                        (edgeo e2)))
                    |#
                    )))])

  (define end-time (current-milliseconds))

  (define elapsed-time (- end-time start-time))

  (printf "elapsed query time: ~s seconds\n" (/ elapsed-time 1000.0))
  (printf "=============================\n")

  ;; (printf "all-X-concepts-with-edges: ~s\n" all-X-concepts-with-edges)
  ;; (newline)
  
  #|
  ;; This sorting affects order of appearance in the "X" concept list
  (set! all-X-concepts-with-edges
    (sort
      all-X-concepts-with-edges
      (lambda (c1 c2)
        (match (list c1 c2)
          [`((,_ ,_ ,e1*) (,_ ,_ ,e2*))
            (not (path-confidence<? e1* e2*))]))))
  |#


  (define all-X-concepts '())
  (set! all-X-concepts
        (let loop ([ls all-X-concepts-with-edges])
          (cond
            [(null? ls) '()]
            [else
             (match (car ls)
               [`(,dbname (,cid ,cui ,name (,catid . ,cat) . ,props) . ,rest)
                (cons (car ls)
                      (loop (remf* (lambda (x)
                                     (match x
                                       [`(,dbname-x (,cid-x ,cui-x ,name-x (,catid-x . ,cat-x) . ,props-x) . ,rest-x)
                                        (and (equal? dbname dbname-x)
                                             (equal? cid cid-x)
                                             (equal? cui cui-x))]))
                                   (cdr ls))))])])))
  (set! all-X-concepts (map (lambda (e) (cons (car e) (cadr e))) all-X-concepts))

  ;;(printf "all-X-concepts: ~s\n" all-X-concepts)
  ;;(newline)
  
  (newline)
  (printf "========== begin query results =============\n")
  (newline)

  (printf "Query end date/time:\n~a\n" (date->string (seconds->date (current-seconds)) #t))
  (newline)


  (define number-Xs-found (length all-X-concepts))
  (define query-seconds (/ elapsed-time 1000.0))
  (define query-time-format-string "Found ~s X's after ~s seconds")
  (send running-status-description set-label (format query-time-format-string number-Xs-found query-seconds))
  (printf query-time-format-string number-Xs-found query-seconds)
  (newline)
  (newline)


  (set-box! *concept-X-choices* all-X-concepts)

  (set-box! *solution-concept-1-name-string* (unbox *concept-1-name-string*))
  (set-box! *solution-concept-2-name-string* (unbox *concept-2-name-string*))

  (set-box! *solution-concept-1-isa-flag* (unbox *concept-1-isa-flag*))
  (set-box! *solution-concept-2-isa-flag* (unbox *concept-2-isa-flag*))

  (set-box! *solution-concept-1-choices* concept-1*)
  (set-box! *solution-concept-2-choices* concept-2*)
  (set-box! *solution-predicate-1-choices* predicate-1*)
  (set-box! *solution-predicate-2-choices* predicate-2*)

  (printf "*solution-concept-1-name-string*:\n~s\n" (unbox *solution-concept-1-name-string*))
  (printf "*solution-concept-1-isa-flag*:\n~s\n" (unbox *solution-concept-1-isa-flag*))
  (printf "*solution-concept-1-choices*:\n")
  (pretty-print (unbox *solution-concept-1-choices*))
  (printf "*solution-predicate-1-choices*:\n")
  (pretty-print (unbox *solution-predicate-1-choices*))
  (newline)

  (printf "*solution-concept-2-name-string*:\n~s\n" (unbox *solution-concept-2-name-string*))
  (printf "*solution-concept-2-isa-flag*:\n~s\n" (unbox *solution-concept-2-isa-flag*))
  (printf "*solution-concept-2-choices*:\n")
  (pretty-print (unbox *solution-concept-2-choices*))
  (printf "*solution-predicate-2-choices*:\n")
  (pretty-print (unbox *solution-predicate-2-choices*))
  (newline)

  #|
  (define pretty-print-X-concepts-with-edges
    (lambda (X-concepts-with-edges)
      (with-output-to-file
          "a.out"
          (lambda ()
            (printf "'(\n")
            (let loop ([ls X-concepts-with-edges])
              (cond
                [(null? ls)
                 (printf ")\n")
                 (newline)]
                [else
                 (match (car ls)
                   [`((,cui ,name ,concept-type*) ,pubmed** ,edge*)
                    ;; (printf "-----------------------------------------------\n")
                    (for-each
                      (lambda (x)
                        (match x
                          [`(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*)
                           (let ((pubmed* (if (list? pubmed*)
                                              (map (lambda (pubmed-id) (string-append "https://www.ncbi.nlm.nih.gov/pubmed/" (~a pubmed-id)))
                                                   pubmed*)
                                              pubmed*)))
                             (pretty-print `(,subj ,obj ,pred ,subj-type ,obj-type ,pubmed*) (current-output-port) 1))]))
                      edge*)
                    (loop (cdr ls))])])))
          #:mode 'text
          #:exists 'append)))

  ;; (printf "all-X-concepts-with-edges:\n")
  (pretty-print-X-concepts-with-edges all-X-concepts-with-edges)
  |#

  (printf "========== end query results =============\n")

  (send concept-X-list-box
        set
        (map (lambda (x)
               (match x
                 [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                  (format "~a" dbname)]))
             all-X-concepts)
        (map (lambda (x)
               (match x
                 [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                  (format "~a" cid)]))
             all-X-concepts)
        (map (lambda (x)
               (match x
                 [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                  (format "~a" cui)]))
             all-X-concepts)
        (map (lambda (x)
               (match x
                 [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                  (format "~a" `(,catid . ,cat))]))
             all-X-concepts)    
        (map (lambda (x)
               (match x
                 [`(,dbname ,cid ,cui ,name (,catid . ,cat) . ,props)
                  (~a name #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
             all-X-concepts))
  
  #| ;; v 0.1 version
  (send concept-X-list-box
        set
        (map (lambda (x)
               (match x
                 [`(,cui ,name ,concept-type*)
                  (format "~a" cui)]))
             all-X-concepts)
        (map (lambda (x)
               (match x
                 [`(,cui ,name ,concept-type*)
                  (let ((concept-type*
                         (sort concept-type* string<?)))
                    (format "~a" concept-type*))]))
             all-X-concepts)
        (map (lambda (x)
               (match x
                 [`(,cui ,name ,concept-type*)
                  (~a name #:max-width MAX-CHAR-WIDTH #:limit-marker "...")]))
             all-X-concepts))
  |#
  
  ;; unselect all items
  (for ([i (length all-X-concepts)])
       (send concept-X-list-box select i #f))

  ;; empty the entries in the full-path-list-box
  (send full-path-list-box set '() '() '() '() '() '() '())
  
  )

(displayln
  "Launching GUI")

(launch-gui)
