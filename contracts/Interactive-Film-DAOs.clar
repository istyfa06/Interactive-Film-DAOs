;; Interactive Film DAOs Contract
;; Token holders vote on story direction, characters' fates, and scene filming

(define-fungible-token film-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-holder (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-voting-not-ended (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-insufficient-tokens (err u106))
(define-constant err-proposal-executed (err u107))
(define-constant err-invalid-delegate (err u108))
(define-constant err-self-delegation (err u109))
(define-constant err-already-delegated (err u110))
(define-constant err-milestone-not-found (err u111))
(define-constant err-milestone-already-completed (err u112))
(define-constant err-invalid-milestone (err u113))
(define-constant err-achievement-not-found (err u114))
(define-constant err-achievement-already-claimed (err u115))

(define-data-var proposal-counter uint u0)
(define-data-var total-supply uint u1000000)
(define-data-var next-delegate-id uint u1)

(define-map proposals
  uint
  {
    id: uint,
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: (string-ascii 20),
    option-a: (string-ascii 200),
    option-b: (string-ascii 200),
    option-c: (string-ascii 200),
    votes-a: uint,
    votes-b: uint,
    votes-c: uint,
    total-votes: uint,
    end-block: uint,
    executed: bool,
    winning-option: (string-ascii 200)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { option: (string-ascii 1), tokens-used: uint }
)

(define-map token-holders
  principal
  { balance: uint, voting-power: uint }
)

(define-map delegates
  uint
  {
    delegate-address: principal,
    reputation-score: uint,
    total-delegated-power: uint,
    successful-proposals: uint,
    total-proposals: uint,
    active: bool,
    bio: (string-ascii 200)
  }
)

(define-map delegations
  principal
  {
    delegate-id: uint,
    delegated-power: uint,
    active: bool
  }
)

(define-map delegate-by-address
  principal
  { delegate-id: uint }
)

(define-map milestones
  uint
  {
    id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    milestone-type: (string-ascii 20),
    target-value: uint,
    current-value: uint,
    reward-pool: uint,
    completed: bool,
    completed-at: (optional uint),
    created-by: principal
  }
)

(define-map achievements
  uint
  {
    id: uint,
    title: (string-ascii 100),
    description: (string-ascii 200),
    requirement-type: (string-ascii 20),
    requirement-value: uint,
    reward-tokens: uint,
    total-claimed: uint
  }
)

(define-map user-achievements
  { user: principal, achievement-id: uint }
  {
    claimed: bool,
    claimed-at: uint
  }
)

(define-map user-stats
  principal
  {
    proposals-created: uint,
    votes-cast: uint,
    characters-created: uint,
    scenes-created: uint,
    total-voting-power-used: uint,
    achievements-earned: uint
  }
)

(define-map characters
  uint
  {
    id: uint,
    name: (string-ascii 50),
    status: (string-ascii 20),
    description: (string-ascii 300)
  }
)

(define-map scenes
  uint
  {
    id: uint,
    title: (string-ascii 100),
    description: (string-ascii 500),
    filmed: bool,
    votes-received: uint
  }
)

(define-data-var character-counter uint u0)
(define-data-var scene-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var achievement-counter uint u0)

(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (ft-mint? film-token amount recipient))
    (map-set token-holders recipient
      { balance: (+ (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders recipient))) amount),
        voting-power: (+ (get voting-power (default-to { balance: u0, voting-power: u0 } 
                           (map-get? token-holders recipient))) amount) })
    (ok true)
  )
)

(define-public (create-story-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (proposal-type (string-ascii 20))
  (option-a (string-ascii 200))
  (option-b (string-ascii 200))
  (option-c (string-ascii 200))
  (voting-duration uint))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (end-block (+ stacks-block-height voting-duration))
    (token-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (>= token-balance u100) err-insufficient-tokens)
    (map-set proposals proposal-id
      {
        id: proposal-id,
        creator: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        option-a: option-a,
        option-b: option-b,
        option-c: option-c,
        votes-a: u0,
        votes-b: u0,
        votes-c: u0,
        total-votes: u0,
        end-block: end-block,
        executed: false,
        winning-option: ""
      }
    )
    (var-set proposal-counter proposal-id)
    (update-user-stat "proposal" u1)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (option (string-ascii 1)) (token-amount uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (voter-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
    (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
    (delegation (map-get? delegations tx-sender))
    (effective-power (if (is-some delegation)
                       (get delegated-power (unwrap-panic delegation))
                       voter-balance))
  )
    (asserts! (>= effective-power token-amount) err-insufficient-tokens)
    (asserts! (>= voter-balance u10) err-not-token-holder)
    (asserts! (<= stacks-block-height (get end-block proposal)) err-voting-ended)
    (asserts! (is-none existing-vote) err-already-voted)
    
    (map-set votes { proposal-id: proposal-id, voter: tx-sender }
      { option: option, tokens-used: token-amount })
    
    (let (
      (new-votes-a (if (is-eq option "a") (+ (get votes-a proposal) token-amount) (get votes-a proposal)))
      (new-votes-b (if (is-eq option "b") (+ (get votes-b proposal) token-amount) (get votes-b proposal)))
      (new-votes-c (if (is-eq option "c") (+ (get votes-c proposal) token-amount) (get votes-c proposal)))
    )
      (map-set proposals proposal-id
        (merge proposal {
          votes-a: new-votes-a,
          votes-b: new-votes-b,
          votes-c: new-votes-c,
          total-votes: (+ (get total-votes proposal) token-amount)
        })
      )
    )
    (update-user-stat "vote" token-amount)
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
  )
    (asserts! (> stacks-block-height (get end-block proposal)) err-voting-not-ended)
    (asserts! (not (get executed proposal)) err-proposal-executed)
    
    (let (
      (votes-a (get votes-a proposal))
      (votes-b (get votes-b proposal))
      (votes-c (get votes-c proposal))
      (winner (if (and (>= votes-a votes-b) (>= votes-a votes-c))
                 (get option-a proposal)
                 (if (>= votes-b votes-c)
                   (get option-b proposal)
                   (get option-c proposal))))
    )
      (map-set proposals proposal-id
        (merge proposal {
          executed: true,
          winning-option: winner
        })
      )
      (ok winner)
    )
  )
)

(define-public (create-character 
  (name (string-ascii 50))
  (description (string-ascii 300)))
  (let (
    (character-id (+ (var-get character-counter) u1))
    (token-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (>= token-balance u50) err-insufficient-tokens)
    (map-set characters character-id
      {
        id: character-id,
        name: name,
        status: "alive",
        description: description
      }
    )
    (var-set character-counter character-id)
    (update-user-stat "character" u1)
    (ok character-id)
  )
)

(define-public (create-scene 
  (title (string-ascii 100))
  (description (string-ascii 500)))
  (let (
    (scene-id (+ (var-get scene-counter) u1))
    (token-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (>= token-balance u50) err-insufficient-tokens)
    (map-set scenes scene-id
      {
        id: scene-id,
        title: title,
        description: description,
        filmed: false,
        votes-received: u0
      }
    )
    (var-set scene-counter scene-id)
    (update-user-stat "scene" u1)
    (ok scene-id)
  )
)

(define-public (vote-for-scene (scene-id uint) (token-amount uint))
  (let (
    (scene (unwrap! (map-get? scenes scene-id) err-proposal-not-found))
    (voter-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (>= voter-balance token-amount) err-insufficient-tokens)
    (asserts! (>= voter-balance u10) err-not-token-holder)
    
    (map-set scenes scene-id
      (merge scene {
        votes-received: (+ (get votes-received scene) token-amount)
      })
    )
    (ok true)
  )
)

(define-public (mark-scene-filmed (scene-id uint))
  (let (
    (scene (unwrap! (map-get? scenes scene-id) err-proposal-not-found))
    (token-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set scenes scene-id
      (merge scene { filmed: true })
    )
    (ok true)
  )
)

(define-public (register-as-delegate (bio (string-ascii 200)))
  (let (
    (delegate-id (var-get next-delegate-id))
    (token-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
  )
    (asserts! (>= token-balance u1000) err-insufficient-tokens)
    (asserts! (is-none (map-get? delegate-by-address tx-sender)) err-already-delegated)
    
    (map-set delegates delegate-id {
      delegate-address: tx-sender,
      reputation-score: u100,
      total-delegated-power: u0,
      successful-proposals: u0,
      total-proposals: u0,
      active: true,
      bio: bio
    })
    
    (map-set delegate-by-address tx-sender { delegate-id: delegate-id })
    
    (var-set next-delegate-id (+ delegate-id u1))
    (ok delegate-id)
  )
)

(define-public (delegate-voting-power (delegate-id uint) (power-amount uint))
  (let (
    (delegate-info (unwrap! (map-get? delegates delegate-id) err-invalid-delegate))
    (delegator-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                         (map-get? token-holders tx-sender))))
    (existing-delegation (map-get? delegations tx-sender))
  )
    (asserts! (not (is-eq tx-sender (get delegate-address delegate-info))) err-self-delegation)
    (asserts! (is-none existing-delegation) err-already-delegated)
    (asserts! (>= delegator-balance power-amount) err-insufficient-tokens)
    (asserts! (get active delegate-info) err-invalid-delegate)
    
    (map-set delegations tx-sender {
      delegate-id: delegate-id,
      delegated-power: power-amount,
      active: true
    })
    
    (map-set delegates delegate-id
      (merge delegate-info {
        total-delegated-power: (+ (get total-delegated-power delegate-info) power-amount)
      })
    )
    
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let (
    (delegation (unwrap! (map-get? delegations tx-sender) err-invalid-delegate))
    (delegate-id (get delegate-id delegation))
    (delegate-info (unwrap! (map-get? delegates delegate-id) err-invalid-delegate))
    (delegated-power (get delegated-power delegation))
  )
    (asserts! (get active delegation) err-invalid-delegate)
    
    (map-set delegations tx-sender
      (merge delegation { active: false })
    )
    
    (map-set delegates delegate-id
      (merge delegate-info {
        total-delegated-power: (- (get total-delegated-power delegate-info) delegated-power)
      })
    )
    
    (ok true)
  )
)

(define-public (update-delegate-reputation (delegate-id uint) (successful bool))
  (let (
    (delegate-info (unwrap! (map-get? delegates delegate-id) err-invalid-delegate))
    (new-successful (if successful (+ (get successful-proposals delegate-info) u1) (get successful-proposals delegate-info)))
    (new-total (+ (get total-proposals delegate-info) u1))
    (new-reputation (if (> new-total u0) 
                      (/ (* new-successful u100) new-total)
                      u100))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set delegates delegate-id
      (merge delegate-info {
        successful-proposals: new-successful,
        total-proposals: new-total,
        reputation-score: new-reputation
      })
    )
    
    (ok new-reputation)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-token-balance (holder principal))
  (ft-get-balance film-token holder)
)

(define-read-only (get-voting-power (holder principal))
  (get voting-power (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders holder)))
)

(define-read-only (get-character (character-id uint))
  (map-get? characters character-id)
)

(define-read-only (get-scene (scene-id uint))
  (map-get? scenes scene-id)
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-character-count)
  (var-get character-counter)
)

(define-read-only (get-scene-count)
  (var-get scene-counter)
)

(define-read-only (get-total-supply)
  (ft-get-supply film-token)
)

(define-read-only (get-delegate (delegate-id uint))
  (map-get? delegates delegate-id)
)

(define-read-only (get-delegation (delegator principal))
  (map-get? delegations delegator)
)

(define-read-only (get-delegate-by-address (address principal))
  (map-get? delegate-by-address address)
)

(define-public (create-milestone
  (title (string-ascii 100))
  (description (string-ascii 300))
  (milestone-type (string-ascii 20))
  (target-value uint)
  (reward-pool uint))
  (let (
    (milestone-id (+ (var-get milestone-counter) u1))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> target-value u0) err-invalid-milestone)
    
    (map-set milestones milestone-id {
      id: milestone-id,
      title: title,
      description: description,
      milestone-type: milestone-type,
      target-value: target-value,
      current-value: u0,
      reward-pool: reward-pool,
      completed: false,
      completed-at: none,
      created-by: tx-sender
    })
    
    (var-set milestone-counter milestone-id)
    (ok milestone-id)
  )
)

(define-public (update-milestone-progress (milestone-id uint) (increment uint))
  (let (
    (milestone (unwrap! (map-get? milestones milestone-id) err-milestone-not-found))
    (new-value (+ (get current-value milestone) increment))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (get completed milestone)) err-milestone-already-completed)
    
    (if (>= new-value (get target-value milestone))
      (map-set milestones milestone-id
        (merge milestone {
          current-value: new-value,
          completed: true,
          completed-at: (some stacks-block-height)
        })
      )
      (map-set milestones milestone-id
        (merge milestone {
          current-value: new-value
        })
      )
    )
    (ok new-value)
  )
)

(define-public (create-achievement
  (title (string-ascii 100))
  (description (string-ascii 200))
  (requirement-type (string-ascii 20))
  (requirement-value uint)
  (reward-tokens uint))
  (let (
    (achievement-id (+ (var-get achievement-counter) u1))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> requirement-value u0) err-invalid-milestone)
    (asserts! (> reward-tokens u0) err-insufficient-tokens)
    
    (map-set achievements achievement-id {
      id: achievement-id,
      title: title,
      description: description,
      requirement-type: requirement-type,
      requirement-value: requirement-value,
      reward-tokens: reward-tokens,
      total-claimed: u0
    })
    
    (var-set achievement-counter achievement-id)
    (ok achievement-id)
  )
)

(define-public (claim-achievement (achievement-id uint))
  (let (
    (achievement (unwrap! (map-get? achievements achievement-id) err-achievement-not-found))
    (user-stats-data (default-to 
      { proposals-created: u0, votes-cast: u0, characters-created: u0, 
        scenes-created: u0, total-voting-power-used: u0, achievements-earned: u0 }
      (map-get? user-stats tx-sender)))
    (already-claimed (map-get? user-achievements { user: tx-sender, achievement-id: achievement-id }))
  )
    (asserts! (is-none already-claimed) err-achievement-already-claimed)
    (asserts! (check-achievement-requirement achievement user-stats-data) err-insufficient-tokens)
    
    (try! (ft-mint? film-token (get reward-tokens achievement) tx-sender))
    
    (map-set token-holders tx-sender
      { balance: (+ (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))) (get reward-tokens achievement)),
        voting-power: (+ (get voting-power (default-to { balance: u0, voting-power: u0 } 
                           (map-get? token-holders tx-sender))) (get reward-tokens achievement)) })
    
    (map-set user-achievements { user: tx-sender, achievement-id: achievement-id }
      { claimed: true, claimed-at: stacks-block-height })
    
    (map-set user-stats tx-sender
      (merge user-stats-data {
        achievements-earned: (+ (get achievements-earned user-stats-data) u1)
      })
    )
    
    (map-set achievements achievement-id
      (merge achievement {
        total-claimed: (+ (get total-claimed achievement) u1)
      })
    )
    
    (ok true)
  )
)

(define-private (check-achievement-requirement 
  (achievement { id: uint, title: (string-ascii 100), description: (string-ascii 200),
                 requirement-type: (string-ascii 20), requirement-value: uint,
                 reward-tokens: uint, total-claimed: uint })
  (stats { proposals-created: uint, votes-cast: uint, characters-created: uint,
           scenes-created: uint, total-voting-power-used: uint, achievements-earned: uint }))
  (let (
    (req-type (get requirement-type achievement))
    (req-value (get requirement-value achievement))
  )
    (if (is-eq req-type "proposals")
      (>= (get proposals-created stats) req-value)
      (if (is-eq req-type "votes")
        (>= (get votes-cast stats) req-value)
        (if (is-eq req-type "characters")
          (>= (get characters-created stats) req-value)
          (if (is-eq req-type "scenes")
            (>= (get scenes-created stats) req-value)
            (>= (get total-voting-power-used stats) req-value)
          )
        )
      )
    )
  )
)

(define-private (update-user-stat (stat-type (string-ascii 20)) (increment uint))
  (let (
    (current-stats (default-to 
      { proposals-created: u0, votes-cast: u0, characters-created: u0,
        scenes-created: u0, total-voting-power-used: u0, achievements-earned: u0 }
      (map-get? user-stats tx-sender)))
  )
    (if (is-eq stat-type "proposal")
      (map-set user-stats tx-sender
        (merge current-stats { proposals-created: (+ (get proposals-created current-stats) increment) }))
      (if (is-eq stat-type "vote")
        (map-set user-stats tx-sender
          (merge current-stats { 
            votes-cast: (+ (get votes-cast current-stats) u1),
            total-voting-power-used: (+ (get total-voting-power-used current-stats) increment)
          }))
        (if (is-eq stat-type "character")
          (map-set user-stats tx-sender
            (merge current-stats { characters-created: (+ (get characters-created current-stats) increment) }))
          (if (is-eq stat-type "scene")
            (map-set user-stats tx-sender
              (merge current-stats { scenes-created: (+ (get scenes-created current-stats) increment) }))
            true
          )
        )
      )
    )
  )
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones milestone-id)
)

(define-read-only (get-achievement (achievement-id uint))
  (map-get? achievements achievement-id)
)

(define-read-only (get-user-achievement (user principal) (achievement-id uint))
  (map-get? user-achievements { user: user, achievement-id: achievement-id })
)

(define-read-only (get-user-stats (user principal))
  (default-to 
    { proposals-created: u0, votes-cast: u0, characters-created: u0,
      scenes-created: u0, total-voting-power-used: u0, achievements-earned: u0 }
    (map-get? user-stats user))
)

(define-read-only (get-milestone-count)
  (var-get milestone-counter)
)

(define-read-only (get-achievement-count)
  (var-get achievement-counter)
)

(define-read-only (check-achievement-eligibility (user principal) (achievement-id uint))
  (let (
    (achievement (unwrap! (map-get? achievements achievement-id) (ok false)))
    (user-stats-data (get-user-stats user))
    (already-claimed (map-get? user-achievements { user: user, achievement-id: achievement-id }))
  )
    (if (is-some already-claimed)
      (ok false)
      (ok (check-achievement-requirement achievement user-stats-data))
    )
  )
)

(begin
  (try! (ft-mint? film-token u100000 contract-owner))
  (map-set token-holders contract-owner
    { balance: u100000, voting-power: u100000 })
)
