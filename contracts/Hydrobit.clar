(define-fungible-token hydrobit-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-insufficient-tokens (err u102))
(define-constant err-daily-limit-exceeded (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-registered (err u105))
(define-constant err-meter-not-found (err u106))
(define-constant err-unauthorized (err u107))

(define-data-var daily-token-rate uint u10)
(define-data-var base-daily-allowance uint u1000)
(define-data-var total-users uint u0)
(define-data-var contract-paused bool false)

(define-map user-profiles
  { user: principal }
  {
    registered-at: uint,
    total-usage: uint,
    token-balance: uint,
    daily-allowance: uint,
    last-reset-day: uint,
    daily-usage: uint,
    meter-id: (string-ascii 32),
    is-active: bool
  }
)

(define-map meter-readings
  { meter-id: (string-ascii 32), day: uint }
  {
    usage: uint,
    timestamp: uint,
    verified: bool,
    reader: principal
  }
)

(define-map daily-usage-history
  { user: principal, day: uint }
  {
    usage: uint,
    tokens-spent: uint,
    allowance-used: uint
  }
)

(define-map authorized-readers
  { reader: principal }
  { authorized: bool }
)

(define-private (get-current-day)
  (/ stacks-block-height u144)
)

(define-private (is-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-reader)
  (default-to false (get authorized (map-get? authorized-readers { reader: tx-sender })))
)

(define-private (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-private (reset-daily-usage-if-needed (user principal))
  (let (
    (profile (unwrap! (get-user-profile user) err-not-registered))
    (current-day (get-current-day))
    (last-reset (get last-reset-day profile))
  )
    (if (> current-day last-reset)
      (begin
        (map-set user-profiles
          { user: user }
          (merge profile {
            daily-usage: u0,
            last-reset-day: current-day
          })
        )
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (register-user (meter-id (string-ascii 32)))
  (let (
    (current-day (get-current-day))
    (existing-profile (get-user-profile tx-sender))
  )
    (asserts! (is-none existing-profile) err-already-registered)
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (map-set user-profiles
      { user: tx-sender }
      {
        registered-at: stacks-block-height,
        total-usage: u0,
        token-balance: u0,
        daily-allowance: (var-get base-daily-allowance),
        last-reset-day: current-day,
        daily-usage: u0,
        meter-id: meter-id,
        is-active: true
      }
    )
    (var-set total-users (+ (var-get total-users) u1))
    (ok true)
  )
)

(define-public (purchase-tokens (amount uint))
  (let (
    (profile (unwrap! (get-user-profile tx-sender) err-not-registered))
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (try! (ft-mint? hydrobit-token amount tx-sender))
    (map-set user-profiles
      { user: tx-sender }
      (merge profile {
        token-balance: (+ (get token-balance profile) amount)
      })
    )
    (ok amount)
  )
)

(define-public (record-usage (user principal) (usage-amount uint) (meter-id (string-ascii 32)))
  (let (
    (profile (unwrap! (get-user-profile user) err-not-registered))
    (current-day (get-current-day))
  )
    (asserts! (or (is-owner) (is-authorized-reader)) err-unauthorized)
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (is-eq (get meter-id profile) meter-id) err-meter-not-found)
    (asserts! (> usage-amount u0) err-invalid-amount)
    
    (unwrap! (reset-daily-usage-if-needed user) err-not-registered)
    
    (let (
      (updated-profile (unwrap! (get-user-profile user) err-not-registered))
      (new-daily-usage (+ (get daily-usage updated-profile) usage-amount))
      (daily-allowance (get daily-allowance updated-profile))
      (excess-usage (if (> new-daily-usage daily-allowance) 
                      (- new-daily-usage daily-allowance) 
                      u0))
      (tokens-needed (* excess-usage (var-get daily-token-rate)))
      (current-tokens (get token-balance updated-profile))
    )
      (asserts! (>= current-tokens tokens-needed) err-insufficient-tokens)
      
      (map-set meter-readings
        { meter-id: meter-id, day: current-day }
        {
          usage: usage-amount,
          timestamp: stacks-block-height,
          verified: true,
          reader: tx-sender
        }
      )
      
      (map-set user-profiles
        { user: user }
        (merge updated-profile {
          daily-usage: new-daily-usage,
          total-usage: (+ (get total-usage updated-profile) usage-amount),
          token-balance: (- current-tokens tokens-needed)
        })
      )
      
      (map-set daily-usage-history
        { user: user, day: current-day }
        {
          usage: new-daily-usage,
          tokens-spent: tokens-needed,
          allowance-used: (if (> new-daily-usage daily-allowance) daily-allowance new-daily-usage)
        }
      )
      
      (if (> tokens-needed u0)
        (try! (ft-burn? hydrobit-token tokens-needed user))
        true
      )
      
      (ok { usage: usage-amount, tokens-spent: tokens-needed, remaining-allowance: (if (> daily-allowance new-daily-usage) (- daily-allowance new-daily-usage) u0) })
    )
  )
)

(define-public (increase-daily-allowance (additional-allowance uint))
  (let (
    (profile (unwrap! (get-user-profile tx-sender) err-not-registered))
    (tokens-needed (* additional-allowance u5))
  )
    (asserts! (> additional-allowance u0) err-invalid-amount)
    (asserts! (>= (get token-balance profile) tokens-needed) err-insufficient-tokens)
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    
    (try! (ft-burn? hydrobit-token tokens-needed tx-sender))
    
    (map-set user-profiles
      { user: tx-sender }
      (merge profile {
        daily-allowance: (+ (get daily-allowance profile) additional-allowance),
        token-balance: (- (get token-balance profile) tokens-needed)
      })
    )
    (ok true)
  )
)

(define-public (transfer-tokens (recipient principal) (amount uint))
  (let (
    (sender-profile (unwrap! (get-user-profile tx-sender) err-not-registered))
    (recipient-profile (unwrap! (get-user-profile recipient) err-not-registered))
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get token-balance sender-profile) amount) err-insufficient-tokens)
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    
    (map-set user-profiles
      { user: tx-sender }
      (merge sender-profile {
        token-balance: (- (get token-balance sender-profile) amount)
      })
    )
    
    (map-set user-profiles
      { user: recipient }
      (merge recipient-profile {
        token-balance: (+ (get token-balance recipient-profile) amount)
      })
    )
    
    (try! (ft-transfer? hydrobit-token amount tx-sender recipient))
    (ok true)
  )
)

(define-public (set-daily-token-rate (new-rate uint))
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set daily-token-rate new-rate)
    (ok true)
  )
)

(define-public (set-base-daily-allowance (new-allowance uint))
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set base-daily-allowance new-allowance)
    (ok true)
  )
)

(define-public (authorize-reader (reader principal))
  (begin
    (asserts! (is-owner) err-owner-only)
    (map-set authorized-readers { reader: reader } { authorized: true })
    (ok true)
  )
)

(define-public (revoke-reader (reader principal))
  (begin
    (asserts! (is-owner) err-owner-only)
    (map-set authorized-readers { reader: reader } { authorized: false })
    (ok true)
  )
)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

(define-read-only (get-user-info (user principal))
  (get-user-profile user)
)

(define-read-only (get-daily-usage-info (user principal))
  (let (
    (profile (get-user-profile user))
    (current-day (get-current-day))
  )
    (match profile
      user-data
        (let (
          (last-reset (get last-reset-day user-data))
          (daily-usage (if (> current-day last-reset) u0 (get daily-usage user-data)))
        )
          (some {
            daily-usage: daily-usage,
            daily-allowance: (get daily-allowance user-data),
            remaining-allowance: (if (> (get daily-allowance user-data) daily-usage) (- (get daily-allowance user-data) daily-usage) u0),
            current-day: current-day,
            tokens-available: (get token-balance user-data)
          })
        )
      none
    )
  )
)

(define-read-only (get-meter-reading (meter-id (string-ascii 32)) (day uint))
  (map-get? meter-readings { meter-id: meter-id, day: day })
)

(define-read-only (get-usage-history (user principal) (day uint))
  (map-get? daily-usage-history { user: user, day: day })
)

(define-read-only (get-contract-stats)
  {
    total-users: (var-get total-users),
    daily-token-rate: (var-get daily-token-rate),
    base-daily-allowance: (var-get base-daily-allowance),
    contract-paused: (var-get contract-paused),
    current-day: (get-current-day)
  }
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance hydrobit-token user)
)

(define-read-only (is-user-registered (user principal))
  (is-some (get-user-profile user))
)

(define-read-only (calculate-excess-cost (user principal) (projected-usage uint))
  (let (
    (profile (get-user-profile user))
  )
    (match profile
      user-data
        (let (
          (daily-allowance (get daily-allowance user-data))
          (current-usage (get daily-usage user-data))
          (total-usage (+ current-usage projected-usage))
          (excess (if (> total-usage daily-allowance) (- total-usage daily-allowance) u0))
        )
          (some (* excess (var-get daily-token-rate)))
        )
      none
    )
  )
)
