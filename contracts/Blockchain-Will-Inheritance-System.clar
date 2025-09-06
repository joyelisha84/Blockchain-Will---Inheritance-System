(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_WILL_NOT_FOUND (err u101))
(define-constant ERR_WILL_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_BENEFICIARY (err u103))
(define-constant ERR_WILL_NOT_EXECUTABLE (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_ALREADY_EXECUTED (err u106))
(define-constant ERR_INVALID_WITNESS (err u107))
(define-constant ERR_WITNESS_ALREADY_CONFIRMED (err u108))
(define-constant ERR_INVALID_TIMELOCK (err u109))

(define-map wills
  { testator: principal }
  {
    beneficiaries: (list 10 { recipient: principal, percentage: uint }),
    total-amount: uint,
    timelock-height: uint,
    required-witnesses: uint,
    witnesses: (list 5 principal),
    witness-confirmations: uint,
    executed: bool,
    created-at: uint
  }
)

(define-map witness-confirmations
  { testator: principal, witness: principal }
  { confirmed: bool, confirmed-at: uint }
)

(define-map balances
  { owner: principal }
  { amount: uint }
)

(define-public (create-will 
  (beneficiaries (list 10 { recipient: principal, percentage: uint }))
  (timelock-blocks uint)
  (required-witnesses uint)
  (witnesses (list 5 principal))
)
  (let (
    (testator tx-sender)
    (current-height stacks-block-height)
    (timelock-height (+ current-height timelock-blocks))
  )
    (asserts! (is-none (map-get? wills { testator: testator })) ERR_WILL_ALREADY_EXISTS)
    (asserts! (> timelock-blocks u0) ERR_INVALID_TIMELOCK)
    (asserts! (and (> required-witnesses u0) (<= required-witnesses (len witnesses))) ERR_INVALID_WITNESS)
    (asserts! (is-eq (fold + (map get-percentage beneficiaries) u0) u100) ERR_INVALID_BENEFICIARY)
    
    (map-set wills
      { testator: testator }
      {
        beneficiaries: beneficiaries,
        total-amount: u0,
        timelock-height: timelock-height,
        required-witnesses: required-witnesses,
        witnesses: witnesses,
        witness-confirmations: u0,
        executed: false,
        created-at: current-height
      }
    )
    (ok true)
  )
)

(define-public (deposit-to-will (amount uint))
  (let (
    (testator tx-sender)
    (current-balance (default-to u0 (get amount (map-get? balances { owner: testator }))))
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
  )
    (asserts! (>= (stx-get-balance testator) amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (stx-transfer? amount testator (as-contract tx-sender)))
    
    (map-set balances
      { owner: testator }
      { amount: (+ current-balance amount) }
    )
    
    (map-set wills
      { testator: testator }
      (merge will-data { total-amount: (+ (get total-amount will-data) amount) })
    )
    (ok amount)
  )
)

(define-public (confirm-death (testator principal))
  (let (
    (witness tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (is-valid-witness (is-some (index-of (get witnesses will-data) witness)))
    (already-confirmed (default-to false (get confirmed (map-get? witness-confirmations { testator: testator, witness: witness }))))
  )
    (asserts! is-valid-witness ERR_INVALID_WITNESS)
    (asserts! (not already-confirmed) ERR_WITNESS_ALREADY_CONFIRMED)
    (asserts! (not (get executed will-data)) ERR_ALREADY_EXECUTED)
    
    (map-set witness-confirmations
      { testator: testator, witness: witness }
      { confirmed: true, confirmed-at: stacks-block-height }
    )
    
    (map-set wills
      { testator: testator }
      (merge will-data { witness-confirmations: (+ (get witness-confirmations will-data) u1) })
    )
    (ok true)
  )
)

(define-public (execute-will (testator principal))
  (let (
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (current-height stacks-block-height)
    (timelock-passed (>= current-height (get timelock-height will-data)))
    (witnesses-confirmed (>= (get witness-confirmations will-data) (get required-witnesses will-data)))
    (can-execute (or timelock-passed witnesses-confirmed))
  )
    (asserts! can-execute ERR_WILL_NOT_EXECUTABLE)
    (asserts! (not (get executed will-data)) ERR_ALREADY_EXECUTED)
    (asserts! (> (get total-amount will-data) u0) ERR_INSUFFICIENT_BALANCE)
    
    (asserts! (get success (distribute-assets testator (get beneficiaries will-data) (get total-amount will-data))) (err u500))
    
    (map-set wills
      { testator: testator }
      (merge will-data { executed: true })
    )
    
    (map-set balances
      { owner: testator }
      { amount: u0 }
    )
    (ok true)
  )
)(define-private (distribute-assets 
  (testator principal)
  (beneficiaries (list 10 { recipient: principal, percentage: uint }))
  (total-amount uint)
)
  (fold distribute-to-beneficiary beneficiaries { testator: testator, total: total-amount, success: true })
)

(define-private (distribute-to-beneficiary
  (beneficiary { recipient: principal, percentage: uint })
  (context { testator: principal, total: uint, success: bool })
)
  (let (
    (amount (/ (* (get total context) (get percentage beneficiary)) u100))
  )
    (if (get success context)
      (match (as-contract (stx-transfer? amount tx-sender (get recipient beneficiary)))
        success-val context
        error-val (merge context { success: false })
      )
      context
    )
  )
)

(define-public (update-will-timelock (new-timelock-blocks uint))
  (let (
    (testator tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (new-timelock-height (+ stacks-block-height new-timelock-blocks))
  )
    (asserts! (not (get executed will-data)) ERR_ALREADY_EXECUTED)
    (asserts! (> new-timelock-blocks u0) ERR_INVALID_TIMELOCK)
    
    (map-set wills
      { testator: testator }
      (merge will-data { timelock-height: new-timelock-height })
    )
    (ok true)
  )
)

(define-public (update-beneficiaries 
  (new-beneficiaries (list 10 { recipient: principal, percentage: uint }))
)
  (let (
    (testator tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
  )
    (asserts! (not (get executed will-data)) ERR_ALREADY_EXECUTED)
    (asserts! (is-eq (fold + (map get-percentage new-beneficiaries) u0) u100) ERR_INVALID_BENEFICIARY)
    
    (map-set wills
      { testator: testator }
      (merge will-data { beneficiaries: new-beneficiaries })
    )
    (ok true)
  )
)

(define-public (withdraw-from-will (amount uint))
  (let (
    (testator tx-sender)
    (will-data (unwrap! (map-get? wills { testator: testator }) ERR_WILL_NOT_FOUND))
    (current-balance (default-to u0 (get amount (map-get? balances { owner: testator }))))
  )
    (asserts! (not (get executed will-data)) ERR_ALREADY_EXECUTED)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender testator)))
    
    (map-set balances
      { owner: testator }
      { amount: (- current-balance amount) }
    )
    
    (map-set wills
      { testator: testator }
      (merge will-data { total-amount: (- (get total-amount will-data) amount) })
    )
    (ok amount)
  )
)

(define-read-only (get-will (testator principal))
  (map-get? wills { testator: testator })
)

(define-read-only (get-will-balance (testator principal))
  (default-to u0 (get amount (map-get? balances { owner: testator })))
)

(define-read-only (get-witness-confirmation (testator principal) (witness principal))
  (map-get? witness-confirmations { testator: testator, witness: witness })
)

(define-read-only (can-execute-will (testator principal))
  (match (map-get? wills { testator: testator })
    will-data 
    (let (
      (timelock-passed (>= stacks-block-height (get timelock-height will-data)))
      (witnesses-confirmed (>= (get witness-confirmations will-data) (get required-witnesses will-data)))
    )
      (and 
        (not (get executed will-data))
        (or timelock-passed witnesses-confirmed)
        (> (get total-amount will-data) u0)
      )
    )
    false
  )
)

(define-private (get-percentage (beneficiary { recipient: principal, percentage: uint }))
  (get percentage beneficiary)
)
