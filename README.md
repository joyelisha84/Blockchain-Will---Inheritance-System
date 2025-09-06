# 🏛️ Blockchain Will & Inheritance System

A decentralized smart contract system built on Stacks blockchain that enables secure digital inheritance and asset distribution through automated will execution.

## 📋 Overview

This smart contract allows users to create digital wills that automatically distribute their assets to designated beneficiaries upon death confirmation or after a specified time period. The system uses a combination of multi-signature witness confirmation and time-based locks for secure execution.

## ✨ Features

- 📝 **Digital Will Creation**: Set up wills with multiple beneficiaries and percentage-based distribution
- 👥 **Multi-Witness System**: Require multiple witnesses to confirm death before execution
- ⏰ **Time-Lock Mechanism**: Automatic execution after specified block height
- 💰 **Flexible Asset Management**: Deposit, withdraw, and manage inheritance funds
- 🔄 **Will Updates**: Modify beneficiaries and timelock settings before execution
- 🔒 **Secure Execution**: Prevents double execution and unauthorized access

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing
- Basic understanding of Clarity smart contracts

### Installation

```bash
clarinet new blockchain-will-project
cd blockchain-will-project
```

Copy the contract code into `contracts/Blockchain-Will-Inheritance-System.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage Guide

### 1. Creating a Will 🆕

```clarity
(contract-call? .Blockchain-Will-Inheritance-System create-will
  (list 
    { recipient: 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7, percentage: u60 }
    { recipient: 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9, percentage: u40 }
  )
  u1000  ;; timelock blocks
  u2     ;; required witnesses
  (list 'SPWITNESS1 'SPWITNESS2 'SPWITNESS3)
)
```

### 2. Depositing Assets 💳

```clarity
(contract-call? .Blockchain-Will-Inheritance-System deposit-to-will u1000000)
```

### 3. Witness Death Confirmation ✅

```clarity
(contract-call? .Blockchain-Will-Inheritance-System confirm-death 'SP-TESTATOR-ADDRESS)
```

### 4. Executing the Will ⚡

```clarity
(contract-call? .Blockchain-Will-Inheritance-System execute-will 'SP-TESTATOR-ADDRESS)
```

### 5. Updating Will Settings 🔧

```clarity
;; Update timelock
(contract-call? .Blockchain-Will-Inheritance-System update-will-timelock u2000)

;; Update beneficiaries
(contract-call? .Blockchain-Will-Inheritance-System update-beneficiaries
  (list { recipient: 'SP-NEW-BENEFICIARY, percentage: u100 })
)
```

## 🔍 Read-Only Functions

- `get-will`: Retrieve will details for a testator
- `get-will-balance`: Check current balance in a will
- `get-witness-confirmation`: Check if witness has confirmed death
- `can-execute-will`: Check if will is ready for execution

## ⚠️ Error Codes

- `u100`: Not authorized
- `u101`: Will not found
- `u102`: Will already exists
- `u103`: Invalid beneficiary configuration
- `u104`: Will not executable
- `u105`: Insufficient balance
- `u106`: Already executed
- `u107`: Invalid witness
- `u108`: Witness already confirmed
- `u109`: Invalid timelock

## 🛡️ Security Features

- Only testator can modify their will before execution
- Witnesses must be pre-approved and can only confirm once
- Beneficiary percentages must total exactly 100%
- Executed wills cannot be modified or re-executed
- Time-lock provides fallback execution mechanism

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## ⚠️ Disclaimer

This smart contract is for educational and experimental purposes. Always conduct thorough testing and security audits before using in production environments involving real assets.
```


