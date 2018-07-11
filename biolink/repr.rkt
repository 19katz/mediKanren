#lang racket
(provide
  edge-predicate
  edge-dst-category
  edge-dst
  edge-eid
  edge->bytes
  bytes->edge

  offset-write
  offset-count
  offset-ref
  detail-find
  detail-next
  detail-write
  )

;; TODO: stream edges-by-X by mask for a particular source concept, e.g.,
;;   #(#f  #f         #f):     get all.
;;   #(#f  dst-cat-id #f):     get all with some destination category, any pid.
;;   #(#f  _          dst-id): get all with some destination, any pid.
;;   #(pid #f         #f):     get all with some pid and any destination.
;;   #(pid dst-cat-id #f):     get all with some pid and destination category.
;;   #(pid _          dst-id): get all with some pid and destination.
;; TODO: stream edges-by-X by pid set, equivalent to a union of pid-only masks.

;; This is the edge representation for edges-by-X.detail, not for edges.scm.
(define (edge-predicate e)    (vector-ref e 0))
(define (edge-dst-category e) (vector-ref e 1))
(define (edge-dst e)          (vector-ref e 2))
(define (edge-eid e)          (vector-ref e 3))

;; 1-byte predicate + 1-byte category + 3-byte concept-id + 4-byte eid
(define edge-byte-size (+ 1 1 3 4))

(define (byte-at offset n) (bitwise-and 255 (arithmetic-shift n offset)))

(define (edge->bytes e)
  (define c (edge-dst e))
  (define pid (edge-predicate e))
  (define cc (edge-dst-category e))
  (define eid (edge-eid e))
  (bytes pid cc (byte-at -16 c) (byte-at -8 c) (byte-at 0 c)
         (byte-at -24 eid) (byte-at -16 eid) (byte-at -8 eid) (byte-at 0 eid)))
(define (bytes->edge bs)
  (define (bref pos) (bytes-ref bs pos))
  (define (bref-to pos offset) (arithmetic-shift (bref pos) offset))
  (vector (bref 0) (bref 1)
          (+ (bref-to 2 16) (bref-to 3 8) (bref-to 4 0))
          (+ (bref-to 5 24) (bref-to 6 16) (bref-to 7 8) (bref-to 8 0))))

(define (write-scm out scm) (fprintf out "~s\n" scm))

(define offset-size 8)
(define (offset->bytes o) (integer->integer-bytes o offset-size #f #f))
(define (bytes->offset b) (integer-bytes->integer b #f #f 0 offset-size))
(define (offset-write out offset) (write-bytes (offset->bytes offset) out))
(define (offset-count in)
  (file-position in eof)
  (/ (file-position in) offset-size))
(define (offset-ref in n)
  (file-position in (* n offset-size))
  (bytes->offset (read-bytes offset-size in)))

(define (detail-write detail-out offset-out detail)
  (when offset-out (offset-write offset-out (file-position detail-out)))
  (write-scm detail-out detail))
(define (detail-ref detail-in offset-in n)
  (file-position detail-in (offset-ref offset-in n))
  (read detail-in))
(define (detail-next detail-in) (read detail-in))

(define (detail-find detail-in offset-in compare)
  (let loop ((start 0) (end (offset-count offset-in)) (best #f))
    (cond ((< start end)
           (define n (+ start (quotient (- end start) 2)))
           (define detail (detail-ref detail-in offset-in n))
           (case (compare detail)
             ((-1) (loop (+ 1 n) end best))
             ((0) (loop start n n))
             ((1) (loop start n best))))
          (best (detail-ref detail-in offset-in best))
          (else eof))))
