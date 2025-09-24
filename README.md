# 💧 Hydrobit - Water Usage Smart Metering

A Clarity smart contract for managing water usage through token-based daily allowances on the Stacks blockchain.

## 🌟 Overview

Hydrobit enables smart water metering with the following key features:
- 🎫 **Token-based daily limits**: Users purchase tokens to exceed their base daily allowance
- 📊 **Usage tracking**: Real-time monitoring of water consumption
- 🔒 **Authorized readings**: Only authorized meter readers can record usage
- 📅 **Daily reset system**: Allowances automatically reset each day
- 💰 **Flexible pricing**: Dynamic token rates for excess usage

## 🚀 Core Features

### User Management
- **Registration**: Users register with their meter ID
- **Token system**: Purchase tokens for excess usage beyond daily limits
- **Allowance upgrades**: Increase daily allowance using tokens

### Usage Recording
- **Meter readings**: Authorized personnel record water usage
- **Automatic calculations**: Smart excess usage and token deduction
- **History tracking**: Complete usage history per user per day

### Administrative Controls
- **Owner functions**: Manage token rates, allowances, and authorized readers
- **Contract pause**: Emergency stop functionality
- **Reader authorization**: Control who can record meter readings

## 📋 Contract Functions

### Public Functions

#### `register-user(meter-id)`
Register a new user with their meter ID
```clarity
(contract-call? .hydrobit register-user "METER_12345")
```

#### `purchase-tokens(amount)`
Purchase tokens to cover excess water usage
```clarity
(contract-call? .hydrobit purchase-tokens u100)
```

#### `record-usage(user, usage-amount, meter-id)`
Record water usage for a user (authorized readers only)
```clarity
(contract-call? .hydrobit record-usage 'ST1... u150 "METER_12345")
```

#### `transfer-tokens(recipient, amount)`
Transfer tokens to another user
```clarity
(contract-call? .hydrobit transfer-tokens 'ST2... u50)
```

#### `increase-daily-allowance(additional-allowance)`
Increase daily water allowance using tokens
```clarity
(contract-call? .hydrobit increase-daily-allowance u200)
```

### Read-Only Functions

#### `get-user-info(user)`
Get complete user profile information

#### `get-daily-usage-info(user)`
Get current day usage and allowance details

#### `get-contract-stats()`
Get overall contract statistics

#### `calculate-excess-cost(user, projected-usage)`
Calculate cost for projected excess usage

## 🔧 Setup & Deployment

### Prerequisites
- Clarinet CLI installed
- Stacks wallet configured

### Local Development
```bash
clarinet check
clarinet test
clarinet console
```

### Contract Interaction Examples

#### Register as a new user
```clarity
(contract-call? .hydrobit register-user "METER_001")
```

#### Check your daily usage status
```clarity
(contract-call? .hydrobit get-daily-usage-info tx-sender)
```

#### Purchase tokens for excess usage
```clarity
(contract-call? .hydrobit purchase-tokens u500)
```

## ⚙️ Configuration

### Default Settings
- **Base daily allowance**: 1000 units
- **Token rate for excess**: 10 tokens per unit
- **Allowance upgrade cost**: 5 tokens per unit

### Admin Functions
- `set-daily-token-rate(new-rate)`: Update token cost for excess usage
- `set-base-daily-allowance(new-allowance)`: Update default daily allowance
- `authorize-reader(reader)`: Grant meter reading permissions
- `toggle-contract-pause()`: Emergency pause/unpause

## 💡 Usage Scenarios

### Daily Water Management
1. Users receive base daily allowance (1000 units)
2. Usage within allowance is free
3. Excess usage requires tokens at current rate
4. Allowances reset automatically each day

### Token Economics
- Purchase tokens in advance for predictable excess usage
- Transfer tokens between users for flexibility
- Upgrade daily allowance permanently using tokens

### Meter Reading Workflow
1. Authorized readers record actual usage
2. Contract calculates excess and deducts tokens
3. Usage history stored for analytics
4. Real-time balance updates

## 🛡️ Security Features

- **Owner-only admin functions**
- **Authorized reader system**
- **Contract pause mechanism**
- **Input validation and error handling**
- **Automatic daily resets**

## 📊 Data Structures

### User Profile
- Registration timestamp
- Total lifetime usage
- Current token balance
- Daily allowance and usage
- Associated meter ID
- Account status

### Usage History
- Daily usage records per user
- Token expenditure tracking
- Allowance utilization metrics

## 🤝 Contributing

Contributions welcome! Please ensure all changes pass `clarinet check` before submitting.

## 🏆 Conservation Analytics & Gamification

Hydrobit now includes **integrated conservation analytics and gamification** features that transform water conservation into an engaging, rewarding experience:

### 🎯 Core Features
- **Smart Efficiency Scoring**: Dynamic 0-100 score comparing your usage against community average
- **Tiered Conservation System**: 5-tier ranking system (Bronze→Silver→Gold→Platinum)
- **Milestone Achievements**: Unlock badges for conservation milestones (1K, 5K, 10K+ liters saved)
- **Weekly Usage Predictions**: AI-powered forecasting for better water planning
- **Community Benchmarking**: Real-time comparison with other users
- **Token Rewards**: Earn hydrobit tokens for conservation efforts

### 🎮 Gamification Tiers
- **🥉 Bronze (Tier 1)**: 50+ efficiency score → 25 tokens/week
- **🥈 Silver (Tier 2)**: 60+ efficiency score → 50 tokens/week  
- **🥇 Gold (Tier 3)**: 75+ efficiency score → 75 tokens/week
- **💎 Platinum (Tier 4)**: 90+ efficiency score → 100 tokens/week

### 🏅 Achievement Milestones
- **🥉 Bronze Badge**: Save 1,000+ liters vs community average
- **🥈 Silver Badge**: Save 5,000+ liters vs community average
- **🥇 Gold Badge**: Save 10,000+ liters + 80+ efficiency score

### 📈 New Functions

#### Conservation Analytics
```clarity
;; Automatically updates after each usage recording
(contract-call? .hydrobit update-conservation-analytics user)

;; Claim weekly conservation rewards
(contract-call? .hydrobit claim-conservation-reward)

;; Predict next week's usage
(contract-call? .hydrobit predict-weekly-usage user)
```

#### Read-Only Analytics
- `get-efficiency-score(user)`: Get current efficiency score (0-100)
- `get-conservation-tier(user)`: Get current tier (0-4)
- `get-conservation-milestones(user)`: Check achievement status
- `get-conservation-summary(user)`: Complete analytics overview
- `get-community-average()`: Community usage benchmark
- `get-weekly-prediction(user, week)`: Usage forecasts

### 💡 Smart Benefits
- **🎯 Behavioral Incentives**: Gamified conservation motivates reduced usage
- **📊 Data-Driven Insights**: Track efficiency trends and community ranking
- **💰 Token Earnings**: Convert conservation into real rewards
- **🔮 Predictive Planning**: Forecast usage to optimize token spending
- **🏘️ Community Engagement**: Foster conservation through friendly competition

## 📄 License

MIT License - See LICENSE file for details
