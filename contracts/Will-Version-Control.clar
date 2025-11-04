(define-constant ERR_NOT_AUTHORIZED (err u600))
(define-constant ERR_INVALID_VERSION (err u601))
(define-constant ERR_VERSION_NOT_FOUND (err u602))
(define-constant ERR_INVALID_HASH (err u603))

(define-data-var global-version-counter uint u0)

(define-map version-registry
  { testator: principal }
  { current-version: uint, total-amendments: uint, last-modified: uint }
)

(define-map version-history
  { testator: principal, version: uint }
  {
    timestamp: uint,
    change-type: (string-ascii 50),
    previous-hash: (buff 32),
    modifier: principal,
    block-height: uint
  }
)

(define-map version-metadata
  { testator: principal, version: uint }
  {
    beneficiary-count: uint,
    witness-count: uint,
    total-value: uint,
    timelock-height: uint
  }
)

(define-public (record-amendment 
  (change-type (string-ascii 50))
  (previous-hash (buff 32))
  (beneficiary-count uint)
  (witness-count uint)
  (total-value uint)
  (timelock-height uint)
)
  (let (
    (testator tx-sender)
    (registry (default-to { current-version: u0, total-amendments: u0, last-modified: u0 } 
                           (map-get? version-registry { testator: testator })))
    (new-version (+ (get current-version registry) u1))
  )
    (asserts! (> (len previous-hash) u0) ERR_INVALID_HASH)
    
    (map-set version-history
      { testator: testator, version: new-version }
      {
        timestamp: stacks-block-height,
        change-type: change-type,
        previous-hash: previous-hash,
        modifier: testator,
        block-height: stacks-block-height
      }
    )
    
    (map-set version-metadata
      { testator: testator, version: new-version }
      {
        beneficiary-count: beneficiary-count,
        witness-count: witness-count,
        total-value: total-value,
        timelock-height: timelock-height
      }
    )
    
    (map-set version-registry
      { testator: testator }
      {
        current-version: new-version,
        total-amendments: (+ (get total-amendments registry) u1),
        last-modified: stacks-block-height
      }
    )
    
    (ok new-version)
  )
)

(define-read-only (get-current-version (testator principal))
  (map-get? version-registry { testator: testator })
)

(define-read-only (get-version-details (testator principal) (version uint))
  (map-get? version-history { testator: testator, version: version })
)

(define-read-only (get-version-metadata (testator principal) (version uint))
  (map-get? version-metadata { testator: testator, version: version })
)

(define-read-only (get-amendment-count (testator principal))
  (default-to u0 (get total-amendments (map-get? version-registry { testator: testator })))
)
