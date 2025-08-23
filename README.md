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

## 📄 License

MIT License - See LICENSE file for details
