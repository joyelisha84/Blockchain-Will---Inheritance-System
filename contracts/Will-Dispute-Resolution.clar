(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u200))
(define-constant ERR_DISPUTE_NOT_FOUND (err u201))
(define-constant ERR_NOT_BENEFICIARY (err u202))
(define-constant ERR_DISPUTE_PERIOD_EXPIRED (err u203))
(define-constant ERR_ALREADY_VOTED (err u204))
(define-constant ERR_NOT_ARBITRATOR (err u205))
(define-constant ERR_DISPUTE_ACTIVE (err u206))
(define-constant ERR_ALREADY_EXECUTED (err u207))
(define-constant DISPUTE_PERIOD_BLOCKS u1440)
(define-constant ARBITRATOR_PENALTY u1000000)

(define-map disputes
  { testator: principal }
  {
    challenger: principal,
    reason: (string-ascii 100),
    created-at: uint,
    votes-for: uint,
    votes-against: uint,
    resolved: bool,
    resolution: (optional bool)
  }
)

(define-map arbitrator-votes
  { testator: principal, arbitrator: principal }
  { vote: bool, voted-at: uint }
)

(define-map arbitrators
  { arbitrator: principal }
  { active: bool, stake: uint }
)

(define-public (register-arbitrator (stake uint))
  (let ((arbitrator tx-sender))
    (asserts! (>= (stx-get-balance arbitrator) stake) (err u208))
    (try! (stx-transfer? stake arbitrator (as-contract tx-sender)))
    (map-set arbitrators { arbitrator: arbitrator } { active: true, stake: stake })
    (ok true)
  )
)

(define-public (initiate-dispute (testator principal) (reason (string-ascii 100)))
  (let (
    (challenger tx-sender)
    (will-data (unwrap! (contract-call? .Blockchain-Will-Inheritance-System get-will testator) (err u100)))
    (is-beneficiary (is-some (index-of (map get-recipient (get beneficiaries will-data)) challenger)))
  )
    (asserts! is-beneficiary ERR_NOT_BENEFICIARY)
    (asserts! (not (get executed will-data)) (err u209))
    (asserts! (is-none (map-get? disputes { testator: testator })) ERR_DISPUTE_ALREADY_EXISTS)
    (map-set disputes 
      { testator: testator }
      {
        challenger: challenger,
        reason: reason,
        created-at: stacks-block-height,
        votes-for: u0,
        votes-against: u0,
        resolved: false,
        resolution: none
      }
    )
    (ok true)
  )
)

(define-public (vote-on-dispute (testator principal) (support bool))
  (let (
    (arbitrator tx-sender)
    (arbitrator-data (unwrap! (map-get? arbitrators { arbitrator: arbitrator }) ERR_NOT_ARBITRATOR))
    (dispute-data (unwrap! (map-get? disputes { testator: testator }) ERR_DISPUTE_NOT_FOUND))
    (already-voted (is-some (map-get? arbitrator-votes { testator: testator, arbitrator: arbitrator })))
  )
    (asserts! (get active arbitrator-data) ERR_NOT_ARBITRATOR)
    (asserts! (not already-voted) ERR_ALREADY_VOTED)
    (asserts! (not (get resolved dispute-data)) (err u210))
    (asserts! (<= (- stacks-block-height (get created-at dispute-data)) DISPUTE_PERIOD_BLOCKS) ERR_DISPUTE_PERIOD_EXPIRED)
    
    (map-set arbitrator-votes 
      { testator: testator, arbitrator: arbitrator }
      { vote: support, voted-at: stacks-block-height }
    )
    
    (map-set disputes
      { testator: testator }
      (merge dispute-data {
        votes-for: (if support (+ (get votes-for dispute-data) u1) (get votes-for dispute-data)),
        votes-against: (if support (get votes-against dispute-data) (+ (get votes-against dispute-data) u1))
      })
    )
    (ok true)
  )
)

(define-public (resolve-dispute (testator principal))
  (let (
    (dispute-data (unwrap! (map-get? disputes { testator: testator }) ERR_DISPUTE_NOT_FOUND))
    (period-expired (> (- stacks-block-height (get created-at dispute-data)) DISPUTE_PERIOD_BLOCKS))
    (total-votes (+ (get votes-for dispute-data) (get votes-against dispute-data)))
    (dispute-upheld (> (get votes-for dispute-data) (get votes-against dispute-data)))
  )
    (asserts! period-expired ERR_DISPUTE_PERIOD_EXPIRED)
    (asserts! (not (get resolved dispute-data)) ERR_ALREADY_EXECUTED)
    
    (map-set disputes
      { testator: testator }
      (merge dispute-data { resolved: true, resolution: (some dispute-upheld) })
    )
    (ok dispute-upheld)
  )
)

(define-read-only (get-dispute (testator principal))
  (map-get? disputes { testator: testator })
)

(define-read-only (has-active-dispute (testator principal))
  (match (map-get? disputes { testator: testator })
    dispute-data (and (not (get resolved dispute-data)) (<= (- stacks-block-height (get created-at dispute-data)) DISPUTE_PERIOD_BLOCKS))
    false
  )
)

(define-private (get-recipient (beneficiary { recipient: principal, percentage: uint }))
  (get recipient beneficiary)
)
