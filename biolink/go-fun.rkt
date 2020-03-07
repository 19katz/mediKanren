#lang racket
(provide (all-defined-out)
         (all-from-out "common.rkt" "mk-db.rkt"))
(require "common.rkt" "mk-db.rkt")


;; How can we tell we reached one of the 3 ultimate GO superclasses?
;;
;; biological_process   GO:0008150 has subclass_of predicate, but it is a subclass of BFO: CURIES, not GO: CURIES
;; similarly for the other two
;;
;; Need to cache superclasses we have seen, since GO supports multiple inheritance.

;; Currently only works for RTX2, not Robokop.
;; Do we want it to work for Robokop as well?
;;
;; Need to be careful if we are trying to navigate both KG's copies of GO, since may be inconsistent.
(define get-all-GO-ancestors
  (let ((subclass_of-pred-ls '((rtx2 15 . "subclass_of"))))
    (lambda (S)
      (define get-all-GO-ancestors
        (lambda (S ancestors)
          (match (run/graph
                  ((S S)
                   (O #f))
                  ((S->O subclass_of-pred-ls))
                  (S S->O O))
            [(list name=>concepts name=>edges)
             (let* ((c* (hash-ref name=>concepts 'O))
                    (c* (filter (lambda (c) (not (set-member? ancestors c))) c*))
                    (c* (filter (lambda (c) (string-prefix? (concept->curie c) "GO:")) c*)))
               (cond
                 [(null? c*) ancestors]
                 [else
                  (let ((ancestors (let loop ((c* c*)
                                              (ancestors ancestors))
                                     (match c*
                                       ['() ancestors]
                                       [`(,c . ,c*)
                                        (loop c* (set-add ancestors c))]))))
                    (get-all-GO-ancestors c* ancestors))]))])))
      (get-all-GO-ancestors S (set)))))

(define get-curies/names-from-concepts
  (lambda (s)
    (map (lambda (c)
           (match c
             [`(,db ,cid ,curie ,name (,catid . ,cat) ,props)
              (list curie name)]
             [else
              (error 'get-curies/names-from-concepts (format "c didn't match:\n~s\n" c))]))
         (set->list s))))

;; Lymphangiogenesis
(define S1 (keep 1 (find-concepts #t (list "GO:0001946"))))
(define A1 (get-all-GO-ancestors S1))
(pretty-print (get-curies/names-from-concepts A1))

;; negative regulation of cell migration involved in sprouting angiogenesis
(define S2 (keep 1 (find-concepts #t (list "GO:0090051"))))
(define A2 (get-all-GO-ancestors S2))
(pretty-print (get-curies/names-from-concepts A2))

;; positive regulation of execution phase of apoptosis
(define S3 (keep 1 (find-concepts #t (list "GO:1900119"))))
(define A3 (get-all-GO-ancestors S3))
(pretty-print (get-curies/names-from-concepts A3))

;; positive regulation of cysteine-type endopeptidase activity involved in execution phase of apoptosis
(define S4 (keep 1 (find-concepts #t (list "GO:2001272"))))
(define A4 (get-all-GO-ancestors S4))
(pretty-print (get-curies/names-from-concepts A4))

;; cysteine-type endopeptidase activity involved in execution phase of apoptosis
(define S5 (keep 1 (find-concepts #t (list "GO:0097200"))))
(define A5 (get-all-GO-ancestors S5))
(pretty-print (get-curies/names-from-concepts A5))
