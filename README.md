# Prediction Market Protocol

**Blockchain Technologies 2 — Final Project**

A full-stack decentralized binary outcome prediction market protocol deployed on Arbitrum Sepolia (L2). Features CPMM AMM pricing, ERC-1155 outcome tokens, ERC-4626 fee vault, Chainlink oracle integration, and OpenZeppelin DAO governance.

## Architecture

```
┌──────────────────────────────────────────────┐
│              Frontend (React)                 │
│  ┌─────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ Markets │ │Governance│ │    Vault      │   │
│  └────┬────┘ └────┬─────┘ └──────┬───────┘   │
│       │           │              │            │
│       ▼           ▼              ▼            │
│  ┌────────────────────────────────────────┐   │
│  │   Wagmi / Viem (Web3 Interface)        │   │
│  └────────────────────────────────────────┘   │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│              Smart Contracts (L2)             │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │  Market  │ │Governance│ │  FeeVault     │  │
│  │ Factory  │ │ (DAO)    │ │ (ERC-4626)   │  │
│  ├──────────┤ ├──────────┤ ├──────────────┤  │
│  │Prediction│ │  Gov     │ │  UUPS Proxy  │  │
│  │ Market   │ │  Token   │ │  V1 → V2     │  │
│  │ (CPMM)   │ │(Votes)   │ │              │  │
│  └──────────┘ └──────────┘ └──────────────┘  │
│        │            │                        │
│        ▼            ▼                        │
│  ┌──────────┐ ┌──────────────┐               │
│  │Outcome   │ │   Chainlink  │               │
│  │Token     │ │  Price Feed  │               │
│  │(ERC-1155)│ │  (Oracle)    │               │
│  └──────────┘ └──────────────┘               │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│           The Graph Subgraph                  │
│  (Indexing markets, trades, proposals)        │
└──────────────────────────────────────────────┘
```

## Tech Stack

- **Smart Contracts**: Solidity 0.8.23, Foundry
- **Frontend**: React, TypeScript, Vite, Wagmi, Viem
- **Indexing**: The Graph (subgraph)
- **Oracles**: Chainlink Price Feeds
- **L2**: Arbitrum Sepolia
- **Governance**: OpenZeppelin Governor + TimelockController
- **Static Analysis**: Slither

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Explorer |
|----------|---------|----------|
| MarketFactory | `0x...` | [Link] |
| FeeVault (Proxy) | `0x...` | [Link] |
| GovernanceToken | `0x...` | [Link] |
| ProtocolGovernor | `0x...` | [Link] |
| TimelockController | `0x...` | [Link] |
| ChainlinkPriceFeed | `0x...` | [Link] |

## Quick Start

### Prerequisites
- Node.js v18+
- Foundry
- MetaMask

### Installation

```bash
# Clone repo
git clone <repo-url>
cd prediction-market

# Install Foundry dependencies
cd contracts
forge install
cd ..

# Install frontend dependencies
cd frontend
npm install
cd ..
```

### Compile Contracts
```bash
cd contracts
forge build
```

### Run Tests
```bash
cd contracts
forge test -vvv
```

### Coverage
```bash
cd contracts
forge coverage
```

### Run Slither
```bash
cd contracts
slither . --filter-paths "@openzeppelin|forge-std"
```

### Start Frontend
```bash
cd frontend
npm run dev
```

### Deploy to L2
```bash
cd contracts
forge script script/DeployL2.s.sol \
  --rpc-url arbitrum_sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## Test Suite

- **Unit tests**: 55+ covering all public/external functions including revert paths
- **Fuzz tests**: 10+ including AMM swap, vault deposit/withdraw, governance voting
- **Invariant tests**: 6 including k-constant, total supply, treasury accounting
- **Fork tests**: 3 against mainnet (Chainlink, USDC)

Line coverage: ≥90% across `contracts/src/`

## Design Patterns Used

1.  **Factory** — MarketFactory deploys markets via CREATE and CREATE2
2.  **Proxy/UUPS** — FeeVault is upgradeable with V1→V2 path
3.  **Checks-Effects-Interactions** — All state-modifying functions follow CEI
4.  **Access Control** — OpenZeppelin AccessControl for granular permissions
5.  **Timelock** — 2-day delay on all governance actions
6.  **Reentrancy Guard** — OpenZeppelin ReentrancyGuard on all critical functions
7.  **Oracle Adapter** — ChainlinkPriceFeed abstracts oracle interaction
8.  **Pull-over-Push** — redeem() function uses pull pattern for payouts

## Governance Parameters

| Parameter | Value |
|-----------|-------|
| Voting Delay | 1 day |
| Voting Period | 1 week |
| Quorum | 4% |
| Proposal Threshold | 1% |
| Timelock Delay | 2 days |

## Security

- Zero High/Medium findings in Slither
- All privileged functions use AccessControl or Ownable
- No tx.origin usage
- No block.timestamp for randomness
- SafeERC20 for all ERC-20 interactions
- Checks-effects-interactions pattern throughout
- ReentrancyGuard on all state-changing functions
- Reentrancy and access-control vulnerabilities reproduced and fixed (with tests)
- Post-deployment verification script confirms no admin backdoors

## Subgraph

The subgraph indexes the following entities:
- **Market**: Market metadata, reserves, resolution state
- **Trade**: Individual buy/sell trades
- **LiquidityChange**: LP additions/removals
- **Proposal**: Governance proposals with vote counts
- **User**: Trader/user data

### Example Queries

```graphql
# All active markets
{ markets(where: { resolved: false }) { id question reserveYes reserveNo } }

# Top traders
{ trades(first: 10, orderBy: amountIn, orderDirection: desc) { trader amountIn } }

# Proposal details
{ proposals { id description forVotes againstVotes } }
```

## Team Ownership

| Member | Area |
|--------|------|
| Team Member 1 | Smart Contracts (core AMM, factory, oracles) |
| Team Member 2 | Governance, vault, upgradeability |
| Team Member 3 | Frontend, subgraph, deployment |

## License

MIT
