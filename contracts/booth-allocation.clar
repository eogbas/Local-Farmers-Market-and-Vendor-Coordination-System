;; Booth Allocation Contract
;; Handles booth assignment, reservation, and fee management

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-BOOTH-NOT-AVAILABLE (err u301))
(define-constant ERR-BOOTH-NOT-FOUND (err u302))
(define-constant ERR-INVALID-INPUT (err u303))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u304))
(define-constant ERR-VENDOR-NOT-APPROVED (err u305))

;; Data Variables
(define-data-var next-booth-id uint u1)

;; Data Maps
(define-map booths
  { booth-id: uint }
  {
    market-id: uint,
    booth-number: (string-ascii 10),
    size: uint,
    location-description: (string-ascii 100),
    base-fee: uint,
    is-available: bool,
    created-at: uint
  }
)

(define-map booth-reservations
  { booth-id: uint, date: uint }
  {
    vendor-id: uint,
    reserved-by: principal,
    fee-paid: uint,
    status: (string-ascii 20),
    reserved-at: uint
  }
)

(define-map vendor-booth-history
  { vendor-id: uint, booth-id: uint }
  {
    total-reservations: uint,
    last-reservation: uint
  }
)

;; Public Functions

;; Create booth (admin function)
(define-public (create-booth (market-id uint) (booth-number (string-ascii 10)) (size uint) (location-description (string-ascii 100)) (base-fee uint))
  (let ((booth-id (var-get next-booth-id)))
    ;; In a real implementation, this would check market admin permissions
    (asserts! (> (len booth-number) u0) ERR-INVALID-INPUT)
    (asserts! (> size u0) ERR-INVALID-INPUT)
    (asserts! (> base-fee u0) ERR-INVALID-INPUT)

    (map-set booths
      { booth-id: booth-id }
      {
        market-id: market-id,
        booth-number: booth-number,
        size: size,
        location-description: location-description,
        base-fee: base-fee,
        is-available: true,
        created-at: block-height
      }
    )

    (var-set next-booth-id (+ booth-id u1))
    (ok booth-id)
  )
)

;; Reserve booth
(define-public (reserve-booth (booth-id uint) (vendor-id uint) (date uint) (payment uint))
  (let ((booth (unwrap! (map-get? booths { booth-id: booth-id }) ERR-BOOTH-NOT-FOUND)))
    ;; Check if booth is available
    (asserts! (get is-available booth) ERR-BOOTH-NOT-AVAILABLE)

    ;; Check if booth is already reserved for this date
    (asserts! (is-none (map-get? booth-reservations { booth-id: booth-id, date: date })) ERR-BOOTH-NOT-AVAILABLE)

    ;; Check if vendor is approved for this market
    ;; In a real implementation, this would call vendor-registry contract

    ;; Check payment amount
    (asserts! (>= payment (get base-fee booth)) ERR-INSUFFICIENT-PAYMENT)

    ;; Create reservation
    (map-set booth-reservations
      { booth-id: booth-id, date: date }
      {
        vendor-id: vendor-id,
        reserved-by: tx-sender,
        fee-paid: payment,
        status: "confirmed",
        reserved-at: block-height
      }
    )

    ;; Update vendor history
    (let ((history (default-to { total-reservations: u0, last-reservation: u0 }
                               (map-get? vendor-booth-history { vendor-id: vendor-id, booth-id: booth-id }))))
      (map-set vendor-booth-history
        { vendor-id: vendor-id, booth-id: booth-id }
        {
          total-reservations: (+ (get total-reservations history) u1),
          last-reservation: block-height
        }
      )
    )

    (ok true)
  )
)

;; Cancel reservation
(define-public (cancel-reservation (booth-id uint) (date uint))
  (let ((reservation (unwrap! (map-get? booth-reservations { booth-id: booth-id, date: date }) ERR-BOOTH-NOT-FOUND)))
    (asserts! (is-eq (get reserved-by reservation) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set booth-reservations
      { booth-id: booth-id, date: date }
      (merge reservation { status: "cancelled" })
    )
    (ok true)
  )
)

;; Update booth availability (admin function)
(define-public (update-booth-availability (booth-id uint) (is-available bool))
  (let ((booth (unwrap! (map-get? booths { booth-id: booth-id }) ERR-BOOTH-NOT-FOUND)))
    ;; In a real implementation, this would check market admin permissions
    (map-set booths
      { booth-id: booth-id }
      (merge booth { is-available: is-available })
    )
    (ok true)
  )
)

;; Update booth fee (admin function)
(define-public (update-booth-fee (booth-id uint) (new-fee uint))
  (let ((booth (unwrap! (map-get? booths { booth-id: booth-id }) ERR-BOOTH-NOT-FOUND)))
    ;; In a real implementation, this would check market admin permissions
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)

    (map-set booths
      { booth-id: booth-id }
      (merge booth { base-fee: new-fee })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get booth details
(define-read-only (get-booth (booth-id uint))
  (map-get? booths { booth-id: booth-id })
)

;; Get booth reservation
(define-read-only (get-booth-reservation (booth-id uint) (date uint))
  (map-get? booth-reservations { booth-id: booth-id, date: date })
)

;; Check if booth is available for date
(define-read-only (is-booth-available (booth-id uint) (date uint))
  (match (map-get? booths { booth-id: booth-id })
    booth (and (get is-available booth)
               (is-none (map-get? booth-reservations { booth-id: booth-id, date: date })))
    false
  )
)

;; Get vendor booth history
(define-read-only (get-vendor-booth-history (vendor-id uint) (booth-id uint))
  (map-get? vendor-booth-history { vendor-id: vendor-id, booth-id: booth-id })
)

;; Calculate booth fee with potential discounts
(define-read-only (calculate-booth-fee (booth-id uint) (vendor-id uint))
  (match (map-get? booths { booth-id: booth-id })
    booth (let ((base-fee (get base-fee booth))
                (history (map-get? vendor-booth-history { vendor-id: vendor-id, booth-id: booth-id })))
            (match history
              vendor-history (if (> (get total-reservations vendor-history) u5)
                               (* base-fee u90 (/ u1 u100)) ;; 10% discount for frequent vendors
                               base-fee)
              base-fee))
    u0
  )
)

;; Get next booth ID
(define-read-only (get-next-booth-id)
  (var-get next-booth-id)
)
