;; Market Management Contract
;; Handles market creation, configuration, and administrative functions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-EXISTS (err u101))
(define-constant ERR-MARKET-NOT-FOUND (err u102))
(define-constant ERR-INVALID-INPUT (err u103))

;; Data Variables
(define-data-var next-market-id uint u1)

;; Data Maps
(define-map markets
  { market-id: uint }
  {
    name: (string-ascii 50),
    location: (string-ascii 100),
    admin: principal,
    is-active: bool,
    operating-days: (list 7 uint),
    opening-time: uint,
    closing-time: uint,
    booth-fee: uint,
    created-at: uint
  }
)

(define-map market-admins
  { market-id: uint, admin: principal }
  { authorized: bool }
)

;; Public Functions

;; Create a new market
(define-public (create-market (name (string-ascii 50)) (location (string-ascii 100)) (operating-days (list 7 uint)) (opening-time uint) (closing-time uint) (booth-fee uint))
  (let ((market-id (var-get next-market-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len location) u0) ERR-INVALID-INPUT)
    (asserts! (< opening-time closing-time) ERR-INVALID-INPUT)
    (asserts! (> booth-fee u0) ERR-INVALID-INPUT)

    (map-set markets
      { market-id: market-id }
      {
        name: name,
        location: location,
        admin: tx-sender,
        is-active: true,
        operating-days: operating-days,
        opening-time: opening-time,
        closing-time: closing-time,
        booth-fee: booth-fee,
        created-at: block-height
      }
    )

    (map-set market-admins
      { market-id: market-id, admin: tx-sender }
      { authorized: true }
    )

    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Update market configuration
(define-public (update-market (market-id uint) (operating-days (list 7 uint)) (opening-time uint) (closing-time uint) (booth-fee uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND)))
    (asserts! (is-market-admin market-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (< opening-time closing-time) ERR-INVALID-INPUT)
    (asserts! (> booth-fee u0) ERR-INVALID-INPUT)

    (map-set markets
      { market-id: market-id }
      (merge market {
        operating-days: operating-days,
        opening-time: opening-time,
        closing-time: closing-time,
        booth-fee: booth-fee
      })
    )
    (ok true)
  )
)

;; Add market administrator
(define-public (add-market-admin (market-id uint) (admin principal))
  (begin
    (asserts! (is-market-admin market-id tx-sender) ERR-NOT-AUTHORIZED)
    (map-set market-admins
      { market-id: market-id, admin: admin }
      { authorized: true }
    )
    (ok true)
  )
)

;; Remove market administrator
(define-public (remove-market-admin (market-id uint) (admin principal))
  (begin
    (asserts! (is-market-admin market-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq admin tx-sender)) ERR-NOT-AUTHORIZED)
    (map-delete market-admins { market-id: market-id, admin: admin })
    (ok true)
  )
)

;; Deactivate market
(define-public (deactivate-market (market-id uint))
  (let ((market (unwrap! (map-get? markets { market-id: market-id }) ERR-MARKET-NOT-FOUND)))
    (asserts! (is-market-admin market-id tx-sender) ERR-NOT-AUTHORIZED)
    (map-set markets
      { market-id: market-id }
      (merge market { is-active: false })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get market details
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

;; Check if user is market admin
(define-read-only (is-market-admin (market-id uint) (user principal))
  (default-to false (get authorized (map-get? market-admins { market-id: market-id, admin: user })))
)

;; Get next market ID
(define-read-only (get-next-market-id)
  (var-get next-market-id)
)

;; Check if market is active
(define-read-only (is-market-active (market-id uint))
  (match (map-get? markets { market-id: market-id })
    market (get is-active market)
    false
  )
)
