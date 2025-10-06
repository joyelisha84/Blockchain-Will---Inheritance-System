(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_INVALID_INTERVAL (err u501))
(define-constant ERR_HEARTBEAT_NOT_CONFIGURED (err u502))
(define-constant ERR_TOO_SOON (err u503))
(define-constant DEFAULT_INACTIVITY_THRESHOLD u4320)

(define-map heartbeat-config
  { testator: principal }
  {
    check-in-interval: uint,
    inactivity-threshold: uint,
    grace-period-blocks: uint,
    notifications-enabled: bool
  }
)

(define-map heartbeat-history
  { testator: principal }
  {
    last-heartbeat: uint,
    total-heartbeats: uint,
    consecutive-missed: uint,
    longest-streak: uint,
    current-streak: uint,
    inactive: bool
  }
)

(define-map missed-heartbeat-alerts
  { testator: principal }
  {
    alerted-at: uint,
    alert-count: uint,
    acknowledged: bool
  }
)

(define-public (configure-heartbeat
  (check-in-interval uint)
)
  (let (
    (testator tx-sender)
    (inactivity-threshold (* check-in-interval u3))
    (grace-period (* check-in-interval u1))
  )
    (asserts! (>= check-in-interval u100) ERR_INVALID_INTERVAL)
    (map-set heartbeat-config
      { testator: testator }
      {
        check-in-interval: check-in-interval,
        inactivity-threshold: inactivity-threshold,
        grace-period-blocks: grace-period,
        notifications-enabled: true
      }
    )
    (map-set heartbeat-history
      { testator: testator }
      {
        last-heartbeat: stacks-block-height,
        total-heartbeats: u1,
        consecutive-missed: u0,
        longest-streak: u1,
        current-streak: u1,
        inactive: false
      }
    )
    (ok true)
  )
)

(define-public (send-heartbeat)
  (let (
    (testator tx-sender)
    (config (unwrap! (map-get? heartbeat-config { testator: testator }) ERR_HEARTBEAT_NOT_CONFIGURED))
    (history (unwrap! (map-get? heartbeat-history { testator: testator }) ERR_HEARTBEAT_NOT_CONFIGURED))
    (blocks-since-last (- stacks-block-height (get last-heartbeat history)))
    (is-on-time (<= blocks-since-last (+ (get check-in-interval config) (get grace-period-blocks config))))
    (new-streak (if is-on-time (+ (get current-streak history) u1) u1))
    (new-longest (if (> new-streak (get longest-streak history)) new-streak (get longest-streak history)))
  )
    (map-set heartbeat-history
      { testator: testator }
      {
        last-heartbeat: stacks-block-height,
        total-heartbeats: (+ (get total-heartbeats history) u1),
        consecutive-missed: u0,
        longest-streak: new-longest,
        current-streak: new-streak,
        inactive: false
      }
    )
    (ok true)
  )
)

(define-read-only (is-inactive (testator principal))
  (match (map-get? heartbeat-config { testator: testator })
    config
    (match (map-get? heartbeat-history { testator: testator })
      history
      (let (
        (blocks-since-last (- stacks-block-height (get last-heartbeat history)))
        (threshold (get inactivity-threshold config))
      )
        (>= blocks-since-last threshold)
      )
      false
    )
    false
  )
)

(define-read-only (get-heartbeat-status (testator principal))
  (match (map-get? heartbeat-config { testator: testator })
    config
    (match (map-get? heartbeat-history { testator: testator })
      history
      (let (
        (blocks-since-last (- stacks-block-height (get last-heartbeat history)))
        (is-currently-inactive (>= blocks-since-last (get inactivity-threshold config)))
      )
        (some {
          last-activity: (get last-heartbeat history),
          blocks-since-activity: blocks-since-last,
          total-checkins: (get total-heartbeats history),
          current-streak: (get current-streak history),
          best-streak: (get longest-streak history),
          inactive: is-currently-inactive,
          next-checkin-due: (+ (get last-heartbeat history) (get check-in-interval config))
        })
      )
      none
    )
    none
  )
)

(define-read-only (get-config (testator principal))
  (map-get? heartbeat-config { testator: testator })
)

(define-read-only (blocks-until-inactive (testator principal))
  (match (map-get? heartbeat-config { testator: testator })
    config
    (match (map-get? heartbeat-history { testator: testator })
      history
      (let (
        (blocks-since-last (- stacks-block-height (get last-heartbeat history)))
        (threshold (get inactivity-threshold config))
        (remaining (if (>= blocks-since-last threshold) u0 (- threshold blocks-since-last)))
      )
        (some remaining)
      )
      none
    )
    none
  )
)
