#lang racket/base
(provide
  load-databases
  conde/databases
  config
  config-ref
  path/data
  path:data
  path/root
  path:root)
(require
  "mk-db.rkt"
  racket/list
  racket/runtime-path)

(define-runtime-path path:root ".")
(define (path/root relative-path) (build-path path:root relative-path))
(define path:data                 (path/root "data"))
(define (path/data relative-path) (build-path path:data relative-path))

(define path:config.user     (path/root "config.scm"))
(define path:config.defaults (path/root "config.defaults.scm"))
(define config.user          (if (file-exists? path:config.user)
                               (with-input-from-file path:config.user
                                                     (lambda () (read)))
                               '()))
(define config.defaults      (with-input-from-file path:config.defaults
                                                   (lambda () (read))))
(unless (and (list? config.user) (andmap pair? config.user))
  (error "invalid user config:"
         config.user (path->string (simplify-path path:config.user))))
(define config
  (let* ((user-keys (map car config.user))
         (user-defined? (lambda (kv) (member (car kv) user-keys))))
    (append config.user (filter-not user-defined? config.defaults))))
(define (config-ref key)
  (define kv (assoc key config))
  (unless kv (error "missing configuration key:" key))
  (cdr kv))

(define box:databases (box #f))
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
  (cond ((unbox box:databases))
        (else (when verbose? (displayln "Loading data sources..."))
              (define dbs (load-dbs))
              (set-box! box:databases dbs)
              (when verbose? (displayln "Finished loading data sources"))
              dbs)))
(define (conde/databases dbdesc->clause)
  (foldr (lambda (desc rest) (conde ((dbdesc->clause desc)) (rest)))
         (== #t #f) (load-databases #t)))
