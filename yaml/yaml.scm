(load "biolink-model.scm")
(define model biolink-model)

(define (cat l1)
  (map (lambda (c) (car c)) (cdr (assoc l1 model))))

(define (rel l1 l2)
  (map (lambda (c) (cons (car c)
                    (let ((p (assoc l2 (cdr c))))
                      (if p (cdr p) #f))))
       (cdr (assoc l1 model))))

(define (chain k r)
  (cons k
        (let ((p (assoc k r)))
          (if (cdr p)
              (chain (cdr p) r)
              '()))))
(define (refl-trans-closure r)
  (map (lambda (p) (chain (car p) r)) r))

(define categories-is-a (rel "classes" "is_a"))
(define categories-subs (refl-trans-closure categories-is-a))

(define categories-slots (filter (lambda (x) (cdr x)) (rel "classes" "slots")))
(define categories-slot_usage (filter (lambda (x) (cdr x)) (rel "classes" "slot_usage")))

(define predicates-is-a (rel "slots" "is_a"))
(define predicates-subs (refl-trans-closure predicates-is-a))

(define predicates-domain (rel "slots" "domain"))

(define predicates-range (rel "slots" "range"))

(define (mk-sub name subs)
  `(define (,name s u)
     (conde
       ,@(map (lambda (cs) `((== s ,(car cs))
                        ,`(conde
                            ,@(map (lambda (c) `((== u ,c))) cs))))
              subs))))

(load "../code/mk/mk.scm")
(load "../code/mk/test-check.scm")
(eval (mk-sub 'categories-subo categories-subs))
(eval (mk-sub 'predicates-subo predicates-subs))

(test "sub-1"
  (run* (q) (categories-subo q "pathway"))
  '(("pathway")))
(test "sub-2"
  (run* (q) (categories-subo q "gene or gene product"))
  '(("gene or gene product")
    ("gene") ("gene product") ("protein") ("gene product isoform")
    ("protein isoform") ("RNA product") ("RNA product isoform")
    ("noncoding RNA product") ("microRNA")))
(test "super-1"
  (run* (q) (categories-subo "protein" q))
  '(("protein")
    ("gene product") ("gene or gene product") ("macromolecular machine")
    ("genomic entity") ("molecular entity")
    ("biological entity") ("named thing")))
(test "super-2"
  (run* (q) (predicates-subo "regulates" q))
  '(("regulates") ("affects") ("related to")))
(test "super-3"
  (run* (q) (predicates-subo q "homologous to"))
  '(("homologous to")
    ("paralogous to")
    ("orthologous to")
    ("xenologous to")))

(define (find-spec domain p)
  (if p
      (if (cdr p)
          (cdr p)
          (let ((parent (assoc (car p) predicates-is-a)))
            (if parent
                (find-spec domain (assoc (cdr parent) domain))
                (error 'find-spec "no parent" (car p)))))
      #f))

(define (mk-valid-type name name_csubo name_psubo)
  `(define (,name subject verb object)
     (conde
       ,@(map (lambda (pd pr)
                (assert (equal? (car pd) (car pr)))
                `((== verb ,(car pd))
                  (== subject ,(find-spec predicates-domain pd))
                  (== object ,(find-spec predicates-range pr))))
              predicates-domain predicates-range))))

(eval (mk-valid-type 'valid-typeo 'categories-subo 'predicates-subo))

(test "valid-1"
  (run* (q)
    (fresh (a b)
      (valid-typeo a "regulates" b)
      (categories-subo "pathway" a)
      (categories-subo "disease" b)))
  '((_.0)))

(test "valid-2"
  (run* (q p) (valid-typeo q "homologous to" p))
  '((("named thing" "named thing"))))

(test "valid-sub-1"
  (run* (s v o)
    (predicates-subo v "homologous to")
    (valid-typeo s v o))
  '((("named thing" "homologous to" "named thing"))
    (("named thing" "paralogous to" "named thing"))
    (("named thing" "orthologous to" "named thing"))
    (("named thing" "xenologous to" "named thing"))))

(test "valid-sub-2"
  (run* (s v o)
    (predicates-subo "homologous to" v)
    (valid-typeo s v o))
  '((("named thing" "homologous to" "named thing"))
    (("named thing" "related to" "named thing"))))

(test "valid-sub-3"
  (run* (s s1 v o o1)
    (predicates-subo v "genetically interacts with")
    (valid-typeo s v o)
    (categories-subo s1 s)
    (categories-subo o1 o))
  '((("gene" "gene" "genetically interacts with" "gene" "gene"))))

(test "valid-4"
  (run* (s v o)
    (== "molecularly interacts with" v)
    (valid-typeo s v o))
  '((("molecular entity"
    "molecularly interacts with"
    "molecular entity"))))

(test "valid-sub-4"
  (length (run* (s v o o1)
            (== "molecularly interacts with" v)
            (valid-typeo s v o)
            (categories-subo o1 o)))
  26)

(test "valid-sub-5"
  (run* (s v o o1)
    (== "molecularly interacts with" v)
    (== o1 "sequence variant")
    (valid-typeo s v o)
    (categories-subo o1 o))
  '((("molecular entity"
      "molecularly interacts with"
      "molecular entity"
      "sequence variant"))))

(test "mol-sub-1"
  (length (run* (q)
            (fresh (x)
              (== "molecular entity" x)
              (=/= x q)
              (categories-subo q x))))
  25)

(test "gtga-1"
  (run* (q)
    (fresh (x)
      (== "gene to gene association" x)
      (categories-subo x q)))
  '(("gene to gene association")
    ("association")))

(assoc "range" (cdr (assoc "subject" (cdr (assoc "gene to gene association" categories-slot_usage)))))

(define (mk-slot-table name slot)
  `(define (,name category slot)
     (conde
       ,@(filter (lambda (x) x)
                 (map
                  (lambda (c)
                    (let ((s (assoc slot (cdr c))))
                      (if s
                          (let ((r (assoc "range" (cdr s))))
                            (if r
                                `((== category ,(car c))
                                  (== slot ,(cdr r)))
                                #f))
                          #f)))
                  categories-slot_usage)))))

(eval (mk-slot-table 'categories-subjecto "subject"))
(eval (mk-slot-table 'categories-objecto "object"))


(test "slot-challenge-1"
  (run 1 (a b)
    (categories-subo a "association")
    (categories-subo "protein" b)
    (categories-subjecto a b))
  '((("gene to gene association" "gene or gene product"))))

(test "slot-challenge-2"
  (run 1 (a b)
    (categories-subo a "association")
    (categories-subo "protein" b)
    (categories-objecto a b))
  '((("gene to gene association" "gene or gene product"))))

(define (specific-predo s1 v1 o1 s2 v2 o2)
  (fresh ()
    (categories-subo v2 v1)
    (categories-subjecto v2 s2)
    (categories-objecto v2 o2)
    (categories-subo s1 s2)
    (categories-subo o1 o2)))

(test "slot-challenge-3"
  (run 1 (a b c)
    (specific-predo "protein" "association" "protein" a b c))
  '((("gene or gene product"
      "gene to gene association"
      "gene or gene product"))))

(test "slot-challenge-4"
  (run* (b)
    (fresh (a c)
      (specific-predo "protein" "association" "protein" a b c)))
  '(("gene to gene association")
    ("pairwise interaction association")
    ("genomic sequence localization")
    ("sequence feature relationship")
    ("gene regulatory relationship")))

;;; "homologous to" should inherit the range and domain
;;;
;;; "homologous to" "is_a" "related to"
;;;
;;; related to
;;;
;;; (
;;;   "domain"
;;;   . "named thing"
;;; )
;;; (
;;;   "range"
;;;   . "named thing"
;;; )
;;; (
;;;   "multivalued"
;;;   . #t
;;; )


(test "inherit-1"
  (run* (q p)
    (valid-typeo q "homologous to" p))
  '((("named thing" "named thing"))))

(test "inherit-2"
  (run* (q)
    (fresh (pred)
      (== "homologous to" pred)
      (=/= pred q)
      (predicates-subo pred q)))
  '(("related to")))

(test "inherit-3"
  (run* (x y)
    (valid-typeo x "related to" y))
  '((("named thing" "named thing"))))

(test "inherit-4"
  (run* (q) (categories-subo "named thing" q))
  '(("named thing")))

(test "inherit-5"
  (run* (q p r)
    (predicates-subo "homologous to" r)
    (valid-typeo q r p))
  '((("named thing" "named thing" "homologous to"))
    (("named thing" "named thing" "related to"))))

#!eof

;;; Tricky case from Chris Mungall:
gene_to_gene_association
   is_a association
   defining_slots [ subject : gene
                    object : gene ]
   slot_usage [ subject.range = gene
                object.range = gene ]



x = association
x.subject = protein_coding_gene
x.object = protein_coding_gene

protein_coding_gene is_a gene

=>  (implies)

gene_to_gene_association(x)



(test "Chris-1"
  (run* (pred)
    (most-specific-predo "protein coding gene" "association" "protein coding gene" pred))
  '((("gene to gene association"))))
