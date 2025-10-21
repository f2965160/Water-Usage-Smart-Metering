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
(define-constant err-no-analytics-data (err u108))
(define-constant err-reward-claimed-recently (err u109))
(define-constant err-dispute-window-expired (err u110))
(define-constant err-duplicate-dispute (err u111))
(define-constant err-dispute-not-found (err u112))
(define-constant err-invalid-reading (err u113))
(define-constant err-dispute-already-resolved (err u114))

(define-data-var daily-token-rate uint u10)
(define-data-var base-daily-allowance uint u1000)
(define-data-var total-users uint u0)
(define-data-var contract-paused bool false)
(define-data-var community-total-usage uint u0)
(define-data-var conservation-reward-pool uint u5000)

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

(define-map conservation-analytics
  { user: principal }
  {
    efficiency-score: uint,
    conservation-tier: uint,
    total-savings: uint,
    last-reward-claim: uint,
    milestone-bronze: bool,
    milestone-silver: bool,
    milestone-gold: bool
  }
)

(define-map weekly-usage-history
  { user: principal, week: uint }
  { total-usage: uint, avg-daily: uint }
)

(define-map disputes
  { user: principal, meter-id: (string-ascii 32), day: uint }
  {
    reason: (string-utf8 500),
    submitted-at: uint,
    status: (string-ascii 20),
    resolution-note: (optional (string-utf8 500)),
    resolved-at: (optional uint)
  }
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
      
      (var-set community-total-usage (+ (var-get community-total-usage) usage-amount))
      (try! (update-conservation-analytics user))
      
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

(define-private (calculate-efficiency-score (user principal))
  (let (
    (profile-opt (get-user-profile user))
  )
    (match profile-opt
      profile
        (let (
          (user-total (get total-usage profile))
          (community-avg (if (> (var-get total-users) u0) (/ (var-get community-total-usage) (var-get total-users)) u0))
        )
          (if (and (> community-avg u0) (> user-total u0))
            (if (<= user-total community-avg)
              (+ u50 (/ (* (- community-avg user-total) u50) community-avg))
              (if (> (- user-total community-avg) community-avg) u0 (- u50 (/ (* (- user-total community-avg) u50) community-avg)))
            )
            u50
          )
        )
      u50
    )
  )
)

(define-private (determine-conservation-tier (score uint))
  (if (>= score u90) u4
    (if (>= score u75) u3
      (if (>= score u60) u2
        (if (>= score u50) u1 u0)
      )
    )
  )
)

(define-public (update-conservation-analytics (user principal))
  (let (
    (current-analytics (default-to { efficiency-score: u50, conservation-tier: u0, total-savings: u0, last-reward-claim: u0, milestone-bronze: false, milestone-silver: false, milestone-gold: false } (map-get? conservation-analytics { user: user })))
    (new-score (calculate-efficiency-score user))
    (new-tier (determine-conservation-tier new-score))
    (profile (unwrap! (get-user-profile user) err-not-registered))
    (community-avg (if (> (var-get total-users) u0) (/ (var-get community-total-usage) (var-get total-users)) u0))
    (user-usage (get total-usage profile))
    (savings (if (and (> community-avg u0) (< user-usage community-avg)) (- community-avg user-usage) u0))
  )
    (map-set conservation-analytics
      { user: user }
      {
        efficiency-score: new-score,
        conservation-tier: new-tier,
        total-savings: (+ (get total-savings current-analytics) savings),
        last-reward-claim: (get last-reward-claim current-analytics),
        milestone-bronze: (or (get milestone-bronze current-analytics) (>= (+ (get total-savings current-analytics) savings) u1000)),
        milestone-silver: (or (get milestone-silver current-analytics) (>= (+ (get total-savings current-analytics) savings) u5000)),
        milestone-gold: (or (get milestone-gold current-analytics) (and (>= (+ (get total-savings current-analytics) savings) u10000) (>= new-score u80)))
      }
    )
    (ok new-score)
  )
)

(define-public (claim-conservation-reward)
  (let (
    (analytics (unwrap! (map-get? conservation-analytics { user: tx-sender }) err-no-analytics-data))
    (current-tier (get conservation-tier analytics))
    (current-day (get-current-day))
    (last-claim (get last-reward-claim analytics))
    (reward-amount (if (> current-tier u0) (* current-tier u25) u0))
  )
    (asserts! (> current-tier u0) err-invalid-amount)
    (asserts! (> current-day (+ last-claim u7)) err-reward-claimed-recently)
    (asserts! (<= reward-amount (var-get conservation-reward-pool)) err-insufficient-tokens)
    
    (map-set conservation-analytics
      { user: tx-sender }
      (merge analytics { last-reward-claim: current-day })
    )
    
    (var-set conservation-reward-pool (- (var-get conservation-reward-pool) reward-amount))
    (try! (ft-mint? hydrobit-token reward-amount tx-sender))
    
    (let ((profile (unwrap! (get-user-profile tx-sender) err-not-registered)))
      (map-set user-profiles
        { user: tx-sender }
        (merge profile {
          token-balance: (+ (get token-balance profile) reward-amount)
        })
      )
    )
    (ok reward-amount)
  )
)

(define-public (predict-weekly-usage (user principal))
  (let (
    (current-week (/ (get-current-day) u7))
    (profile (unwrap! (get-user-profile user) err-not-registered))
    (current-day (get-current-day))
    (daily-avg (if (> current-day u0) (/ (get total-usage profile) current-day) u0))
    (predicted-weekly (* daily-avg u7))
  )
    (map-set weekly-usage-history
      { user: user, week: (+ current-week u1) }
      { total-usage: predicted-weekly, avg-daily: daily-avg }
    )
    (ok predicted-weekly)
  )
)

(define-public (add-conservation-rewards (amount uint))
  (begin
    (asserts! (is-owner) err-owner-only)
    (var-set conservation-reward-pool (+ (var-get conservation-reward-pool) amount))
    (ok (var-get conservation-reward-pool))
  )
)

(define-public (submit-dispute (meter-id (string-ascii 32)) (day uint) (reason (string-utf8 500)))
  (let
    (
      (caller tx-sender)
      (current-block stacks-block-height)
      (reading (map-get? meter-readings { meter-id: meter-id, day: day }))
      (existing-dispute (map-get? disputes { user: caller, meter-id: meter-id, day: day }))
    )
    (asserts! (is-some reading) err-invalid-reading)
    (asserts! (is-none existing-dispute) err-duplicate-dispute)
    (asserts! (<= (- current-block day) u1008) err-dispute-window-expired)
    (map-set disputes
      { user: caller, meter-id: meter-id, day: day }
      {
        reason: reason,
        submitted-at: current-block,
        status: "pending",
        resolution-note: none,
        resolved-at: none
      }
    )
    (ok true)
  )
)

(define-public (resolve-dispute (user principal) (meter-id (string-ascii 32)) (day uint) (approve bool) (resolution-note (string-utf8 500)))
  (let
    (
      (dispute (map-get? disputes { user: user, meter-id: meter-id, day: day }))
      (current-block stacks-block-height)
    )
    (asserts! (is-owner) err-owner-only)
    (asserts! (is-some dispute) err-dispute-not-found)
    (asserts! (is-eq (get status (unwrap! dispute err-dispute-not-found)) "pending") err-dispute-already-resolved)
    (map-set disputes
      { user: user, meter-id: meter-id, day: day }
      (merge (unwrap! dispute err-dispute-not-found) {
        status: (if approve "approved" "rejected"),
        resolution-note: (some resolution-note),
        resolved-at: (some current-block)
      })
    )
    (ok true)
  )
)

(define-read-only (get-conservation-analytics (user principal))
  (map-get? conservation-analytics { user: user })
)

(define-read-only (get-efficiency-score (user principal))
  (default-to u50 (get efficiency-score (map-get? conservation-analytics { user: user })))
)

(define-read-only (get-conservation-tier (user principal))
  (default-to u0 (get conservation-tier (map-get? conservation-analytics { user: user })))
)

(define-read-only (get-conservation-milestones (user principal))
  (let ((analytics (map-get? conservation-analytics { user: user })))
    (match analytics
      data {
        bronze: (get milestone-bronze data),
        silver: (get milestone-silver data),
        gold: (get milestone-gold data)
      }
      { bronze: false, silver: false, gold: false }
    )
  )
)

(define-read-only (get-weekly-prediction (user principal) (week uint))
  (map-get? weekly-usage-history { user: user, week: week })
)

(define-read-only (get-community-average)
  (if (> (var-get total-users) u0) 
    (/ (var-get community-total-usage) (var-get total-users)) 
    u0
  )
)

(define-read-only (get-conservation-summary (user principal))
  (let (
    (analytics (map-get? conservation-analytics { user: user }))
    (milestones (get-conservation-milestones user))
    (community-avg (get-community-average))
  )
    {
      analytics: analytics,
      milestones: milestones,
      community-average: community-avg,
      reward-pool-remaining: (var-get conservation-reward-pool)
    }
  )
)

(define-read-only (get-dispute (user principal) (meter-id (string-ascii 32)) (day uint))
  (map-get? disputes { user: user, meter-id: meter-id, day: day })
)

(define-read-only (get-dispute-status (user principal) (meter-id (string-ascii 32)) (day uint))
  (match (map-get? disputes { user: user, meter-id: meter-id, day: day })
    dispute-data (some (get status dispute-data))
    none
  )
)
