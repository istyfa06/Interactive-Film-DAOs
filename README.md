# 🎬 Interactive Film DAOs

> **Democratizing storytelling through blockchain governance** 🗳️

## 🎯 Overview

Interactive Film DAOs revolutionizes the film industry by letting token holders vote on crucial story elements, character fates, and production decisions. Create collaborative narratives where the community shapes every twist and turn!

## ✨ Features

### 🎭 Story Governance
- **Proposal Creation**: Submit story directions, plot twists, and narrative choices
- **Democratic Voting**: Token-weighted voting system for fair representation
- **Multiple Options**: Vote between 3 different story paths (A, B, C)

### 👥 Character Management
- **Character Creation**: Introduce new characters to the story
- **Fate Decisions**: Vote on character survival, relationships, and arcs
- **Community Input**: Token holders shape character development

### 🎥 Scene Production
- **Scene Proposals**: Suggest scenes to be filmed next
- **Production Voting**: Decide filming priorities through token voting
- **Progress Tracking**: Monitor which scenes have been completed

### 🪙 Token System
- **Film Tokens**: Governance tokens for voting power
- **Minting Control**: Contract owner distributes tokens to participants
- **Voting Power**: Token balance determines voting influence

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Stacks blockchain

### Installation
```bash
git clone <repository-url>
cd Interactive-Film-DAOs
clarinet check
```

## 📚 Usage Guide

### 1. 🪙 Getting Tokens
Only the contract owner can mint tokens to participants:
```clarity
(contract-call? .Interactive-Film-DAOs mint-tokens 'SP1... u1000)
```

### 2. 📝 Creating Story Proposals
Submit narrative choices for community voting:
```clarity
(contract-call? .Interactive-Film-DAOs create-story-proposal 
  "Character Death Decision"
  "Should the main character sacrifice themselves to save the village?"
  "character-fate"
  "Hero dies saving everyone"
  "Hero finds another way"
  "Villain changes sides"
  u144) ;; 144 blocks voting period
```

### 3. 🗳️ Voting on Proposals
Cast your vote using tokens:
```clarity
(contract-call? .Interactive-Film-DAOs vote-on-proposal u1 "a" u100)
```

### 4. 🏆 Executing Results
After voting ends, execute to determine the winner:
```clarity
(contract-call? .Interactive-Film-DAOs execute-proposal u1)
```

### 5. 🎭 Adding Characters
Create new characters for the story:
```clarity
(contract-call? .Interactive-Film-DAOs create-character 
  "Elena Martinez"
  "A mysterious archaeologist with knowledge of ancient secrets")
```

### 6. 🎬 Managing Scenes
Propose new scenes for filming:
```clarity
(contract-call? .Interactive-Film-DAOs create-scene
  "The Final Confrontation"
  "Epic battle between good and evil in the ancient temple")
```

### 7. 📊 Voting for Scenes
Support scenes you want filmed next:
```clarity
(contract-call? .Interactive-Film-DAOs vote-for-scene u1 u50)
```

## 🔍 Read-Only Functions

### Query Proposals
```clarity
(contract-call? .Interactive-Film-DAOs get-proposal u1)
(contract-call? .Interactive-Film-DAOs get-proposal-count)
```

### Check Voting Power
```clarity
(contract-call? .Interactive-Film-DAOs get-voting-power 'SP1...)
(contract-call? .Interactive-Film-DAOs get-token-balance 'SP1...)
```

### View Characters & Scenes
```clarity
(contract-call? .Interactive-Film-DAOs get-character u1)
(contract-call? .Interactive-Film-DAOs get-scene u1)
(contract-call? .Interactive-Film-DAOs get-character-count)
(contract-call? .Interactive-Film-DAOs get-scene-count)
```

## 🏗️ Contract Structure

### Core Components
- **Fungible Tokens**: Governance and voting power
- **Proposals System**: Democratic decision making
- **Character Registry**: Story character management
- **Scene Tracking**: Production pipeline management

### Voting Requirements
- **Proposal Creation**: Minimum 100 tokens
- **Character/Scene Creation**: Minimum 50 tokens  
- **Voting Participation**: Minimum 10 tokens
- **One Vote Per Proposal**: Prevents vote manipulation

### Proposal Types
- `story-direction`: Main plot decisions
- `character-fate`: Character life/death choices
- `scene-selection`: Production priorities
- `custom`: User-defined categories

## 🔒 Security Features

- **Owner Controls**: Token minting restricted to contract owner
- **Vote Integrity**: One vote per person per proposal
- **Time Limits**: Proposals have defined voting periods
- **Token Requirements**: Minimum thresholds prevent spam

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 📈 Future Enhancements

- 🎨 **NFT Integration**: Character and scene NFTs
- 💰 **Revenue Sharing**: Profit distribution to token holders
- 🌐 **Cross-Chain**: Multi-blockchain compatibility
- 📱 **Mobile App**: Dedicated voting interface
- 🤖 **AI Integration**: Script generation assistance

## 🤝 Contributing

We welcome contributions! Please feel free to submit issues and pull requests.

## 📄 License

This project is open source and available under the MIT License.

---

*Built with ❤️ for the future of collaborative filmmaking*
