;; ------------------------------------------------------------
;; dao-treasury.clar
;; Treasury contract controlled by dao-core.clar proposals
;; ------------------------------------------------------------

(define-constant ERR-NOT-DAO u100)
(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-ZERO-AMOUNT u102)
(define-constant ERR-INSUFFICIENT-FUNDS u103)
(define-constant ERR-SPENDING-PAUSED u104)

;; DAO contract principal (set once)
(define-data-var dao (optional principal) none)

;; Pause flag
(define-data-var paused bool false)

;; Track treasury total
(define-data-var total-reserve uint u0)

;; ------------------------------------------------------------
;; Initialize Treasury (only once)
;; ------------------------------------------------------------

(define-public (initialize (dao-contract principal))
  (if (or (is-some (var-get dao)) (is-eq dao-contract tx-sender))
      (err ERR-UNAUTHORIZED)
      (begin
        (var-set dao (some dao-contract))
        (ok true)
      )
  )
)

;; ------------------------------------------------------------
;; Deposit STX into treasury
;; Anyone can deposit STX
;; ------------------------------------------------------------

(define-public (deposit (amount uint))
  (if (<= amount u0)
      (err ERR-ZERO-AMOUNT)
      (begin
        (var-set total-reserve (+ (var-get total-reserve) amount))
        (ok amount)
      )
  )
)

;; ------------------------------------------------------------
;; DAO callback: spend STX from treasury
;; Only callable by dao-core after a passed proposal
;; ------------------------------------------------------------

(define-public (dao-spend (recipient principal) (amount uint))
  (if (is-eq recipient tx-sender)
      (err ERR-UNAUTHORIZED)
      (match (var-get dao)
        dao-contract
          (if (not (is-eq dao-contract tx-sender))
              (err ERR-UNAUTHORIZED)
              (if (var-get paused)
                  (err ERR-SPENDING-PAUSED)
                  (if (or (<= amount u0) (> amount (var-get total-reserve)))
                      (err ERR-INSUFFICIENT-FUNDS)
                      (begin
                        ;; Update internal accounting
                        (var-set total-reserve (- (var-get total-reserve) amount))

                        ;; Transfer STX to recipient
                        (match (stx-transfer? amount (as-contract tx-sender) recipient)
                          ok-val (ok ok-val)
                          err-val (err err-val)
                        )
                      )
                  )
              )
          )
        (err ERR-NOT-DAO)
      )
  )
)

;; ------------------------------------------------------------
;; Emergency controls (DAO only)
;; ------------------------------------------------------------

(define-public (pause-spending)
  (match (var-get dao)
    d
      (if (is-eq d tx-sender)
          (begin (var-set paused true) (ok true))
          (err ERR-UNAUTHORIZED)
      )
    (err ERR-NOT-DAO)
  )
)

(define-public (resume-spending)
  (match (var-get dao)
    d
      (if (is-eq d tx-sender)
          (begin (var-set paused false) (ok true))
          (err ERR-UNAUTHORIZED)
      )
    (err ERR-NOT-DAO)
  )
)

;; ------------------------------------------------------------
;; Read-only functions
;; ------------------------------------------------------------

(define-read-only (get-balance)
  (ok (var-get total-reserve))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (get-dao)
  (ok (var-get dao))
)
