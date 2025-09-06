(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_CONTACT_NOT_FOUND (err u301))
(define-constant ERR_RECOVERY_ALREADY_ACTIVE (err u302))
(define-constant ERR_RECOVERY_NOT_FOUND (err u303))
(define-constant ERR_ALREADY_CONFIRMED (err u304))
(define-constant ERR_COOLING_PERIOD_ACTIVE (err u305))
(define-constant ERR_INVALID_CONTACT (err u306))
(define-constant COOLING_PERIOD_BLOCKS u2016)

(define-map emergency-contacts
  { testator: principal }
  { contacts: (list 3 principal), required-confirmations: uint }
)

(define-map recovery-requests
  { testator: principal }
  {
    initiated-by: principal,
    initiated-at: uint,
    confirmations: uint,
    confirmed-contacts: (list 3 principal),
    active: bool,
    cancelled: bool
  }
)

(define-map contact-confirmations
  { testator: principal, contact: principal }
  { confirmed: bool, confirmed-at: uint }
)

(define-public (register-emergency-contacts 
  (contacts (list 3 principal))
  (required-confirmations uint)
)
  (let ((testator tx-sender))
    (asserts! (and (> required-confirmations u0) (<= required-confirmations (len contacts))) ERR_INVALID_CONTACT)
    (map-set emergency-contacts
      { testator: testator }
      { contacts: contacts, required-confirmations: required-confirmations }
    )
    (ok true)
  )
)

(define-public (initiate-recovery (testator principal))
  (let (
    (contact tx-sender)
    (contact-data (unwrap! (map-get? emergency-contacts { testator: testator }) ERR_CONTACT_NOT_FOUND))
    (is-valid-contact (is-some (index-of (get contacts contact-data) contact)))
    (existing-recovery (map-get? recovery-requests { testator: testator }))
  )
    (asserts! is-valid-contact ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-recovery) ERR_RECOVERY_ALREADY_ACTIVE)
    
    (map-set recovery-requests
      { testator: testator }
      {
        initiated-by: contact,
        initiated-at: stacks-block-height,
        confirmations: u1,
        confirmed-contacts: (list contact),
        active: true,
        cancelled: false
      }
    )
    
    (map-set contact-confirmations
      { testator: testator, contact: contact }
      { confirmed: true, confirmed-at: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (confirm-recovery (testator principal))
  (let (
    (contact tx-sender)
    (contact-data (unwrap! (map-get? emergency-contacts { testator: testator }) ERR_CONTACT_NOT_FOUND))
    (recovery-data (unwrap! (map-get? recovery-requests { testator: testator }) ERR_RECOVERY_NOT_FOUND))
    (is-valid-contact (is-some (index-of (get contacts contact-data) contact)))
    (already-confirmed (default-to false (get confirmed (map-get? contact-confirmations { testator: testator, contact: contact }))))
  )
    (asserts! is-valid-contact ERR_NOT_AUTHORIZED)
    (asserts! (not already-confirmed) ERR_ALREADY_CONFIRMED)
    (asserts! (get active recovery-data) ERR_RECOVERY_NOT_FOUND)
    
    (map-set contact-confirmations
      { testator: testator, contact: contact }
      { confirmed: true, confirmed-at: stacks-block-height }
    )
    
    (map-set recovery-requests
      { testator: testator }
      (merge recovery-data {
        confirmations: (+ (get confirmations recovery-data) u1),
        confirmed-contacts: (unwrap-panic (as-max-len? (append (get confirmed-contacts recovery-data) contact) u3))
      })
    )
    (ok true)
  )
)

(define-public (cancel-recovery)
  (let (
    (testator tx-sender)
    (recovery-data (unwrap! (map-get? recovery-requests { testator: testator }) ERR_RECOVERY_NOT_FOUND))
  )
    (asserts! (get active recovery-data) ERR_RECOVERY_NOT_FOUND)
    (asserts! (< (- stacks-block-height (get initiated-at recovery-data)) COOLING_PERIOD_BLOCKS) ERR_COOLING_PERIOD_ACTIVE)
    
    (map-set recovery-requests
      { testator: testator }
      (merge recovery-data { active: false, cancelled: true })
    )
    (ok true)
  )
)

(define-read-only (get-emergency-contacts (testator principal))
  (map-get? emergency-contacts { testator: testator })
)

(define-read-only (get-recovery-status (testator principal))
  (map-get? recovery-requests { testator: testator })
)

(define-read-only (can-execute-recovery (testator principal))
  (match (map-get? recovery-requests { testator: testator })
    recovery-data
    (match (map-get? emergency-contacts { testator: testator })
      contact-data
      (and
        (get active recovery-data)
        (not (get cancelled recovery-data))
        (>= (get confirmations recovery-data) (get required-confirmations contact-data))
        (>= (- stacks-block-height (get initiated-at recovery-data)) COOLING_PERIOD_BLOCKS)
      )
      false
    )
    false
  )
)