#lang racket
(provide (all-defined-out))
(require "query.rkt"
         racket/engine)

;;get simple pieces of edges
(define edge-matcher
  (lambda (ls els)
    (cond
      ((null? ls) (set-union els))
      (else
       (match (car ls)
         [`(,db ,edge-cui
               (,subject-cui ,subject-id ,subject-name (,_ . ,subject-category) ,subject-props-assoc)
               (,object-cui ,object-id ,object-name (,_ . ,object-category) ,object-props-assoc)
               (,_ . ,pred)
               ,pred-props-assoc)
          (edge-matcher
           (cdr ls)
           (set-union
            (list `((,db) (,subject-name . ,subject-id) ,pred (,object-name . ,object-id))) 
            els))])))))


(define gene-filter
  (lambda (ls els)
    (cond
      ((null? ls) (set-union els))
      ((or (string-prefix? (car ls) "HGNC:")
           (string-prefix? (car ls) "ENSEMBL:")
           (string-prefix? (car ls) "UniProtKB:")
           (string-prefix? (car ls) "NCBIGene:")
           (string-prefix? (car ls) "NCBIGENE:"))
       (gene-filter
        (cdr ls)
        (cons (car ls) els)))
      (else
       (gene-filter (cdr ls) els)))))

(define drug-filter
  (lambda (ls els)
    (cond
      ((null? ls) (set-union els))
      ((or (string-prefix? (car ls) "CHEBI:")
           (string-prefix? (car ls) "CHEMBL:")
           (string-prefix? (car ls) "CHEMBL.")
           (string-prefix? (car ls) "KEGG:")
           (string-prefix? (car ls) "KEGG.")
           (string-prefix? (car ls) "DRUGBANK:")
           (string-prefix? (car ls) "RXNORM:"))
       (drug-filter
        (cdr ls)
        (cons (car ls) els)))
      (else
       (drug-filter (cdr ls) els)))))

(define filter/curie
  (lambda (ls els curie)
    (cond
      ((null? ls) (set-union els))
      ((string-prefix? (car ls) curie)
       (filter/curie
        (cdr ls)
        (cons (car ls) els) curie))
      (else
       (filter/curie (cdr ls) els curie)))))

(define remove-item
  (lambda (x ls els)
    (cond
      ((null? ls) (reverse els))
      ((or (boolean? (car ls))
           (void? (car ls)))
       (remove-item
        x (cdr ls) els))
      ((equal? x (car ls))
       (remove-item x (cdr ls) els))
      (else
       (remove-item x (cdr ls)
                    (cons (car ls) els))))))

#|
(define curie-to-anything
  (lambda (curie predicate*)
    ;;(printf "starting curie-to-anything with curie ~s and preds ~s\n" curie predicate*)
    (let ((val (query/graph
                ( ;; concepts
                 (X curie)
                 (T #f))
                ;; edges
                ((X->T predicate*))
                ;; paths      
                (X X->T T))))
      ;;(printf "finished curie-to-anything with curie ~s and preds ~s\n" curie predicate*)
      val)))

(define curie-to-tradenames
  (lambda (curie)
    (curie-to-anything curie '("has_tradename"))))

(define curie-to-clinical-trials
  (lambda (curie)
    (curie-to-anything curie '("clinically_tested_approved_unknown_phase"
                               "clinically_tested_terminated_phase_2"
                               "clinically_tested_terminated_phase_3"
                               "clinically_tested_terminated_phase_2_or_phase_3"
                               "clinically_tested_withdrawn_phase_3"
                               "clinically_tested_withdrawn_phase_2_or_phase_3"
                               "clinically_tested_withdrawn_phase_2"
                               "clinically_tested_suspended_phase_2"
                               "clinically_tested_suspended_phase_3"
                               "clinically_tested_suspended_phase_2_or_phase_3"))))

(define curie-to-indicated_for
  (lambda (curie)
    (curie-to-anything curie '("indicated_for"))))

(define curie-to-contraindicated_for
  (lambda (curie)
    (curie-to-anything curie '("contraindicated_for"))))

|#

(define 2-hop-gene-lookup
  (lambda (target-gene-ls els)
    (define 1-hop/query
      (lambda (target-gene)
        (printf "\nQUERY/GRAPH RUNNING ON:   ~a\n" target-gene)
        (time (query/graph
               ((X #f)
                (TG target-gene))
               ((X->TG #f))
               (X X->TG TG)))))
    (let* ((1-hop-affector-genes/HGNC*
            (synonyms/query (1-hop/query (car target-gene-ls)) 'X))
           (1-hop-affector-genes/HGNC*
            (flatten
             (remove-item
              '()
              (map
               (lambda (ls) (filter/curie ls '() "HGNC:"))
               (map
                set->list
                1-hop-affector-genes/HGNC*))
              '()))))
      (printf "\n\n~a 1-HOP AFFECTOR GENE CONCEPTS FOUND!\n" (length 1-hop-affector-genes/HGNC*))
      (printf "\n\n~a 1-HOP AFFECTOR GENES HGNC-IDs FOUND!\n\n~a" (length 1-hop-affector-genes/HGNC*) 1-hop-affector-genes/HGNC*)
      (cond
        ((null? target-gene-ls)
         (cons 2-hop-affector-gene/edges els))
        (else
         (displayln (format "\n\nPREPARING 1-HOP AFFECTOR GENES FOR 2-HOP QUERY!\n\n"))
         (let ((2-hop-affector-gene/edges (let loop ((1-hop-affector-genes/HGNC* 1-hop-affector-genes/HGNC*)
                                                     (2-hop-affector-gene/edges '()))
                                            (cond
                                              ((null? 1-hop-affector-genes/HGNC*) 2-hop-affector-gene/edges)
                                              (else
                                               (loop
                                                (cdr 1-hop-affector-genes/HGNC*) 
                                                (cons (edges/query (1-hop/query (car 1-hop-affector-genes/HGNC*)) 'X->TG)
                                                      2-hop-affector-gene/edges)))))))
           (1-hop/query (car target-gene-ls))))))))

(define 2-hop-affector-genes/NGLY1
  (2-hop-gene-lookup '("HGNC:21625") '()))

(define NGLY1
  (time (query/graph
         ((X       #f)
          (NGLY1 "HGNC:17646"))
         ((X->NGLY1 #f))
         (X X->NGLY1 NGLY1))))


#|
(define NGLY1
  (time (query/graph
         ((X       #f)
          (NGLY1 "HGNC:17646"))
         ((X->NGLY1 #f))
         (X X->NGLY1 NGLY1))))
(define NGLY1/synonyms (curie-synonyms/names "HGNC:17646"))

(define X->NGLY1/simple
  (edge-matcher X->NGLY1 '()))

(define 1-hop/concepts->NGLY1 (curies/query NGLY1 'X))

(define X->NGLY1 (edges/query NGLY1 'X->NGLY1))

;; dont have to map curie-synonyms 
(define 1-hop-affector-genes/NGLY1
  (remove-item
   '()
   (map (lambda (ls) (gene-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->NGLY1))) '()))

;; use filter 
(define 1-hop-affector-genes-HGNC/NGLY1
  (remove-item
   '()
   (map (lambda (ls) (filter/curie ls '() "HGNC:"))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->NGLY1))) '()))

(define 1-hop-affector-genes-names/NGLY1
  (map (lambda (ls) (curie-synonyms/names ls))
                      (flatten 1-hop-affector-genes-HGNC/NGLY1)))

(define 1-hop-affector-drugs/NGLY1
  (remove-item
   '()
   (map (lambda (ls) (drug-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->NGLY1))) '()))

(define 1-hop-affector-drugs-names/NGLY1
  (map (lambda (ls) (curie-synonyms/names ls))
                      (flatten 1-hop-affector-drugs/NGLY1)))

(define 1-hop-affector-drugs-DRUGBANK/NGLY1 
  (remove-item
   '()
   (map (lambda (ls) (filter/curie ls '() "DRUGBANK:"))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->NGLY1))) '()))

(define X->NGLY1/preds
  (remove-duplicates (map (lambda (ls) (list-ref ls 2)) X->NGLY1/simple)))

;; use NGYL1 gene, much fewer edges

|#

#|
,en synonymize.rkt
,en query.rkt
|#
#|
;; 670 edges
(define ACE2 (time (query/graph
                  ((X       #f)
                   (ACE2 "HGNC:13557"))
                  ((X->ACE2 #f))
                  (X X->ACE2 ACE2))))

;; all X's in the X--pred-->ACE2 edges
(define 1-hop/concepts->ACE2 (curies/query ACE2 'X))

;; gives full edge list X--pred-->ACE2
(define X->ACE2 (edges/query ACE2 'X->ACE2))

;; gives db S P O of all edges 
(define X->ACE2/simple
  (edge-matcher X->ACE2 '()))

;;all unique predicates in the X->ACE2 edges, only 29 unique ones
(define X->ACE2/preds
(remove-duplicates (map (lambda (ls) (list-ref ls 2)) X->ACE2/simple)))

;; all Gene concept X's + synonyms in the X--pred-->ACE2 edges
;; seems like there are 57 gene concepts
(define 1-hop-affector-genes/ACE2
  (remove-item
   '()
   (map (lambda (ls) (gene-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->ACE2))) '()))

;; seems like there is a 1 to 1 ratio with HGNC ids, there are 57 HGNCs
(define 1-hop-affector-genes-HGNC/ACE2
  (remove-item
   '()
   (map (lambda (ls) (filter/curie ls '() "HGNC:"))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->ACE2))) '()))


;; 108 total: all Drug concept X's + synonyms in the X--pred-->ACE2 edges
;; question: what curie can we use to isolate drugs we want? DRUGBANK? CHEBI?
(define 1-hop-affector-drugs/ACE2
  (remove-item
   '()
   (map (lambda (ls) (drug-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->ACE2))) '()))

(define 1-hop-affector-drugs-CHEBI/ACE2 
  (remove-item
   '()
   (map (lambda (ls) (filter/curie ls '() "CHEBI:"))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->ACE2))) '()))

;; 37 DRUGBANK curies  
(define 1-hop-affector-drugs-DRUGBANK/ACE2 
  (remove-item
   '()
   (map (lambda (ls) (filter/curie ls '() "DRUGBANK:"))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->ACE2))) '()))

|#

#|start 2-hop affector gene code here|#
#|
(define viral-entry-gene-ls
  '("HGNC:13557"))
|#




#|
;; 390 edges
(define TMPRSS2 (time (query/graph
                  ((X       #f)
                   (TMPRSS2 "HGNC:11876"))
                  ((X->TMPRSS2 #f))
                  (X X->TMPRSS2 TMPRSS2))))

(define 1-hop/concepts->TMPRSS2 (curies/query TMPRSS2 'X))

;; gives full edges
(define X->TMPRSS2 (edges/query TMPRSS2 'X->TMPRSS2))

(define X->TMPRSS2/simple
  (edge-matcher X->TMPRSS2 '()))

(define X->TMPRSS2/preds
  (remove-duplicates (map (lambda (ls) (list-ref ls 2)) X->TMPRSS2/simple)))

(define 1-hop-affector-genes/TMPRSS2
  (remove-item
   '()
   (map (lambda (ls) (gene-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->TMPRSS2))) '()))

(define 1-hop-affector-drugs/TMPRSS2
  (remove-item
   '()
   (map (lambda (ls) (drug-filter ls '()))
        (map set->list (map (lambda (ls) (curie-synonyms ls)) 1-hop/concepts->TMPRSS2))) '()))


;; 2236 edges 
(define CXCL10 (time (query/graph
                  ((X       #f)
                   (CXCL10 "HGNC:10637"))
                  ((X->CXCL10 #f))
                  (X X->CXCL10 CXCL10))))

(define 1-hop/concepts->CXCL10 (curies/query CXCL10 'X))

;; gives full edges
(define X->CXCL10 (edges/query CXCL10 'X->CXCL10))

(define X->CXCL10/simple
  (edge-matcher X->CXCL10 '()))

(define X->CXCL10/preds
  (remove-duplicates (map (lambda (ls) (list-ref ls 2)) X->CXCL10/simple)))

|#


#|
;;manually filtered list for X--decreases-->ACE2
'("targets"
  "inhibitor"
  "physically_interacts_with"
  "regulates_expression_of"
  "interacts_with"
  "directly_interacts_with"
  "decreases_activity_of"
  "affects"
  "associated_with"
  "inhibits"
  "coexists_with"
  "compared_with"
  "negatively_regulates")

;;manually filtered list for X--increases-->ACE2
'("targets"
  "physically_interacts_with"
  "regulates_expression_of"
  "interacts_with"
  "directly_interacts_with"
  "activator"
  "affects"
  "associated_with"
  "produces"
  "stimulates"
  "coexists_with"
  "positively_regulates"
  "positively_regulates__entity_to_entity")

|#






#|NOTES HERE|#

#|
Gives the all --predicate-->Object
(run* (p) (object-predicateo '(rtx
  1225271
  "NCIT:C102527"
  "ACE2 Gene"
  (11 . "http://w3id.org/biolink/vocab/GeneSet")
  (("iri" . "http://purl.obolibrary.org/obo/NCIT_C102527")
   ("synonym"
    .
    "['ACE2', 'Angiotensin I Converting Enzyme (Peptidyl-Dipeptidase A) 2 Gene']")
   ("category_label" . "gene_set")
   ("deprecated" . "False")
   ("description"
    .
    "This gene plays a role in both proteolysis and vasodilation.; UMLS Semantic Type: TUI:T028")
   ("provided_by" . "https://identifiers.org/umls/NCI")
   ("id" . "NCIT:C102527")
   ("update_date" . "2018")
   ("publications" . "[]")))  p))
'((rtx 15 . "subclass_of"))


(run* (p) (subject-predicateo
'(rtx
  1225271
  "NCIT:C102527"
  "ACE2 Gene"
  (11 . "http://w3id.org/biolink/vocab/GeneSet")
  (("iri" . "http://purl.obolibrary.org/obo/NCIT_C102527")
   ("synonym"
    .
    "['ACE2', 'Angiotensin I Converting Enzyme (Peptidyl-Dipeptidase A) 2 Gene']")
   ("category_label" . "gene_set")
   ("deprecated" . "False")
   ("description"
    .
    "This gene plays a role in both proteolysis and vasodilation.; UMLS Semantic Type: TUI:T028")
   ("provided_by" . "https://identifiers.org/umls/NCI")
   ("id" . "NCIT:C102527")
   ("update_date" . "2018")
   ("publications" . "[]")))  p))
'((rtx 3 . "xref")
 (rtx 15 . "subclass_of")
 (rtx 346 . "gene_encodes_gene_product")
 (rtx 354 . "gene_plays_role_in_process"))
|#


|#
|#
