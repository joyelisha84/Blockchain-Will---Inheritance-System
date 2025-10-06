(define-constant ERR_WILL_NOT_FOUND (err u400))
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INVALID_CERTIFICATE (err u402))
(define-constant ERR_CERTIFICATE_EXISTS (err u403))
(define-constant ERR_INVALID_HASH (err u404))

(define-data-var certificate-counter uint u0)

(define-map will-certificates
  { testator: principal }
  {
    certificate-id: uint,
    content-hash: (buff 32),
    issued-at: uint,
    issuer: principal,
    verified: bool,
    verification-count: uint
  }
)

(define-map certificate-lookup
  { certificate-id: uint }
  {
    testator: principal,
    public-key: (buff 33),
    signature: (buff 65)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool, verified-count: uint }
)

(define-public (issue-certificate (testator principal) (content-hash (buff 32)))
  (let (
    (issuer tx-sender)
    (certificate-id (+ (var-get certificate-counter) u1))
    (current-height stacks-block-height)
  )
    (asserts! (is-eq issuer testator) ERR_NOT_AUTHORIZED)
    (asserts! (> (len content-hash) u0) ERR_INVALID_HASH)
    (asserts! (is-none (map-get? will-certificates { testator: testator })) ERR_CERTIFICATE_EXISTS)
    
    (map-set will-certificates
      { testator: testator }
      {
        certificate-id: certificate-id,
        content-hash: content-hash,
        issued-at: current-height,
        issuer: issuer,
        verified: true,
        verification-count: u0
      }
    )
    
    (var-set certificate-counter certificate-id)
    (ok certificate-id)
  )
)

(define-public (verify-will-authenticity (testator principal) (provided-hash (buff 32)))
  (let (
    (verifier tx-sender)
    (certificate (unwrap! (map-get? will-certificates { testator: testator }) ERR_WILL_NOT_FOUND))
    (hash-matches (is-eq (get content-hash certificate) provided-hash))
  )
    (if hash-matches
      (begin
        (map-set will-certificates
          { testator: testator }
          (merge certificate { verification-count: (+ (get verification-count certificate) u1) })
        )
        (map-set authorized-verifiers
          { verifier: verifier }
          {
            authorized: true,
            verified-count: (+ (default-to u0 (get verified-count (map-get? authorized-verifiers { verifier: verifier }))) u1)
          }
        )
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (register-verifier)
  (let ((verifier tx-sender))
    (map-set authorized-verifiers
      { verifier: verifier }
      { authorized: true, verified-count: u0 }
    )
    (ok true)
  )
)

(define-read-only (get-certificate (testator principal))
  (map-get? will-certificates { testator: testator })
)

(define-read-only (lookup-by-certificate-id (certificate-id uint))
  (map-get? certificate-lookup { certificate-id: certificate-id })
)

(define-read-only (is-will-authentic (testator principal) (provided-hash (buff 32)))
  (match (map-get? will-certificates { testator: testator })
    certificate (is-eq (get content-hash certificate) provided-hash)
    false
  )
)

(define-read-only (get-verification-stats (testator principal))
  (match (map-get? will-certificates { testator: testator })
    certificate
    (some {
      total-verifications: (get verification-count certificate),
      issued-at: (get issued-at certificate),
      verified-status: (get verified certificate)
    })
    none
  )
)

(define-read-only (get-verifier-stats (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)