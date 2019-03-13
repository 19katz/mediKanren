#lang racket/base
(provide
  ~name*-concepto
  edgeo

  pubmed-URLs-from-edge
  pubmed-count
  path-confidence
  path-confidence<?
  sort-paths

  databases
  load-databases
  conde/databases

  config
  config-ref
  load-config

  path-simple
  path/data
  path:data
  path/root
  path:root)

(require
  "mk-db.rkt"
  racket/format
  racket/list
  (except-in racket/match ==)
  racket/runtime-path)

(define-runtime-path path:root ".")
(define (path/root relative-path) (build-path path:root relative-path))
(define path:data                 (path/root "data"))
(define (path/data relative-path) (build-path path:data relative-path))
(define (path-simple path)        (path->string (simplify-path path)))

(define box:config (box #f))
(define (config)
  (define cfg (unbox box:config))
  (cond (cfg cfg)
        (else (load-config #t #f)
              (unbox box:config))))
(define (config-ref key)
  (define kv (assoc key (config)))
  (unless kv (error "missing configuration key:" key))
  (cdr kv))
(define (load-config verbose? path:config)
  (define path:config.user     (or path:config (path/root "config.scm")))
  (define path:config.defaults (path/root "config.defaults.scm"))
  (when verbose? (printf "loading configuration defaults: ~a\n"
                         (path-simple path:config.defaults)))
  (when verbose? (printf "loading configuration overrides: ~a\n"
                         (path-simple path:config.user)))
  (define config.user          (if (file-exists? path:config.user)
                                 (with-input-from-file path:config.user
                                                       (lambda () (read)))
                                 '()))
  (define config.defaults      (with-input-from-file path:config.defaults
                                                     (lambda () (read))))
  (unless (and (list? config.user) (andmap pair? config.user))
    (error "invalid configuration overrides:" config.user))
  (define user-keys (map car config.user))
  (define (user-defined? kv) (member (car kv) user-keys))
  (set-box! box:config
            (append config.user (filter-not user-defined? config.defaults))))

(define box:databases (box #f))
(define (databases)
  (define dbs (unbox box:databases))
  (cond (dbs dbs)
        (else (load-databases #t)
              (unbox box:databases))))
(define (load-databases verbose?)
  (define (load-dbs)
    (filter (lambda (desc) desc)
            (map (lambda (name)
                   (define path (path/data (symbol->string name)))
                   (cond ((directory-exists? path)
                          (when verbose? (printf "loading ~a\n" name))
                          (cons name (if verbose?
                                       (time (make-db path))
                                       (make-db path))))
                         (else (when verbose?
                                 (printf "cannot load ~a; " name)
                                 (printf "directory missing: ~a\n" path))
                               #f)))
                 (config-ref 'databases))))
  (unless (unbox box:databases)
    (when verbose? (displayln "loading data sources..."))
    (define dbs (load-dbs))
    (set-box! box:databases dbs)
    (when verbose? (displayln "finished loading data sources"))))
(define (conde/databases dbdesc->clause)
  (foldr (lambda (desc rest)
           (conde ((dbdesc->clause (car desc) (cdr desc))) (rest)))
         (== #t #f) (databases)))

#|
concept = `(,dbname ,cid ,cui ,name (,catid . ,cat) ,props)
|#
(define (~name*-concepto ~name* concept)
  (conde/databases
    (lambda (dbname db)
      (fresh (c)
        (== `(,dbname . ,c) concept)
        (db:~name*-concepto/options
          #f ;; case sensitivity flag
          "" ;; ignored characters ('chars:ignore-typical' is pre-defined)
          "" ;; characters to split target name on for exact matching ('chars:split-typical' is pre-defined)
          db ~name* c)))))

#|
edge = `(,dbname ,eid (,scid ,scui ,sname (,scatid . ,scat) ,sprops)
                      (,ocid ,ocui ,oname (,ocatid . ,ocat) ,oprops)
                      (,pid . ,pred) ,eprops)
|#
(define (edgeo edge)
  (conde/databases
    (lambda (dbname db)
      (fresh (e)
        (== `(,dbname . ,e) edge)
        (db:edgeo db e)))))

(define PUBMED_URL_PREFIX "https://www.ncbi.nlm.nih.gov/pubmed/")
(define pubmed-URLs-from-edge
  (lambda (edge)
    (match edge
      ['path-separator '()]
      [`(,dbname ,eid ,subj ,obj ,p ,eprops)
        (cond
          [(assoc "pmids" eprops) ;; WEB this property is only used by semmed, I believe
           =>
           (lambda (pr)
             (let ((pubmed* (regexp-split #rx";" (cdr pr))))
               (map (lambda (pubmed-id)
                      (string-append PUBMED_URL_PREFIX (~a pubmed-id)))
                    (remove-duplicates pubmed*))))]
          [(assoc "publications" eprops)
           =>
           (lambda (pr)
             (let ((pubs (cdr pr)))
               (if (and (string? pubs)
                        (> (string-length pubs) 0)
                        (equal? (string-ref pubs 0) #\())
                 (let ((pubmed* (regexp-match* #rx"PMID:([0-9]+)"
                                               pubs #:match-select cadr)))
                   (map (lambda (pubmed-id)
                          (string-append PUBMED_URL_PREFIX (~a pubmed-id)))
                        (remove-duplicates pubmed*)))
                 (let ((pubmed* (regexp-match* #rx"'http://www.ncbi.nlm.nih.gov/pubmed/([0-9]+)'"
                                               pubs #:match-select cadr)))
                   (map (lambda (pubmed-id)
                          (string-append PUBMED_URL_PREFIX (~a pubmed-id)))
                        (remove-duplicates pubmed*))))))]
          [else '()])])))

(define (pubmed-count e)
  (length (pubmed-URLs-from-edge e)))

(define (path-confidence p)
  (define (weight-linear+1 n) (+ 1 n))
  (define (weight-exponential n) (expt 2 n))
  ;; To experiment with sorting, try to only change the weight calculation
  ;; being used.  Leave everything else the same.
  (define weight weight-exponential)
  (define (confidence/edge e) (- 1 (/ 1.0 (weight (pubmed-count e)))))
  (foldl * 1 (map confidence/edge p)))
(define (path-confidence<? p1 p2)
  (let ((pc1 (path-confidence p1))
        (pc2 (path-confidence p2)))
    (cond
      [(= pc1 pc2)
       (let ((pubmed-count*1 (map pubmed-count p1))
             (pubmed-count*2 (map pubmed-count p2)))
         (let ((min-pubmed-count1 (apply min pubmed-count*1))
               (min-pubmed-count2 (apply min pubmed-count*2)))
           (cond
             [(= min-pubmed-count1 min-pubmed-count2)
              (let ((max-pubmed-count1 (apply max pubmed-count*1))
                    (max-pubmed-count2 (apply max pubmed-count*2)))
                (not (> max-pubmed-count1 max-pubmed-count2)))]
             [(< min-pubmed-count1 min-pubmed-count2) #t]
             [else #f])))]
      [(< pc1 pc2) #t]
      [else #f])))
(define (sort-paths paths) (sort paths path-confidence<?))
