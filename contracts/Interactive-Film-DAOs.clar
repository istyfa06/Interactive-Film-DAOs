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

(define-data-var proposal-counter uint u0)
(define-data-var total-supply uint u1000000)

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
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (option (string-ascii 1)) (token-amount uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
    (voter-balance (get balance (default-to { balance: u0, voting-power: u0 } 
                     (map-get? token-holders tx-sender))))
    (existing-vote (map-get? votes { proposal-id: proposal-id, voter: tx-sender }))
  )
    (asserts! (>= voter-balance token-amount) err-insufficient-tokens)
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

(begin
  (try! (ft-mint? film-token u100000 contract-owner))
  (map-set token-holders contract-owner
    { balance: u100000, voting-power: u100000 })
)
