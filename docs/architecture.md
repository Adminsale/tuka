# Architecture Document

## 1. System Context (C4 Level 1)

The Prediction Market Protocol is a decentralized application on L2 (Arbitrum Sepolia) that enables users to create and trade binary outcome prediction markets. The system consists of:

- **Smart Contracts** (Foundry/Solidity): Core protocol logic deployed on L2
- **Frontend dApp** (React + Wagmi + Viem): User interface
- **The Graph Subgraph**: Off-chain indexing for efficient queries
- **Chainlink Oracles**: External data for market resolution
- **External Wallets**: MetaMask for transaction signing

## 2. Container/Component Diagram

### Contract Architecture

```
┌─────────────────────────────────────────────────────┐
│                     MarketFactory                     │
│  (CREATE / CREATE2 deployment, market registry)      │
├─────────────────────────────────────────────────────┤
│                       ▼                               │
│              PredictionMarket                         │
│  (CPMM AMM, split/merge, LP pool)                    │
├─────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────────────┐   │
│  │  OutcomeToken    │  │  ChainlinkPriceFeed      │   │
│  │  (ERC-1155)      │  │  (Oracle adapter)        │   │
│  └─────────────────┘  └──────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│                     FeeVault                          │
│  (ERC-4626, UUPS upgradeable, V1→V2)                │
├─────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────────────┐   │
│  │ GovernanceToken  │  │  ProtocolGovernor        │   │
│  │ (ERC20Votes+Permit)│ │  (OpenZeppelin Governor)  │  │
│  └─────────────────┘  └──────────────────────────┘   │
│                        │                              │
│                   ┌────▼─────┐                        │
│                   │ Timelock  │                        │
│                   │ (2d delay)│                        │
│                   └──────────┘                        │
└─────────────────────────────────────────────────────┘
```

### External Dependencies
- **Chainlink**: Price feed oracles for market resolution
- **The Graph**: Event indexing and query API
- **L2 (Arbitrum Sepolia)**: Deployment and execution environment

## 3. Sequence Diagrams

### 3.1 Trade Flow (Buy YES)

```
User            PredictionMarket      OutcomeToken       FeeVault
 │                     │                    │               │
 │ approve USDC        │                    │               │
 │────────────────────>│                    │               │
 │                     │                    │               │
 │ buyOutcome(YES,100) │                    │               │
 │────────────────────>│                    │               │
 │                     │                    │               │
 │                     │ split 100 USDC     │               │
 │                     │ into YES+NO        │               │
 │                     │───────────────────>│               │
 │                     │<──── mint ──────── │               │
 │                     │                    │               │
 │                     │ burn NO tokens     │               │
 │                     │───────────────────>│               │
 │                     │                    │               │
 │                     │ swap NO→YES in AMM│               │
 │                     │ (k = R_yes * R_no) │               │
 │                     │                    │               │
 │                     │ send fee           │               │
 │                     │──────────────────────────────────>│
 │                     │                    │               │
 │                     │ mint YES tokens    │               │
 │                     │───────────────────>│               │
 │<─── YES tokens ─────│                    │               │
```

### 3.2 Governance Flow (Propose → Vote → Queue → Execute)

```
User          GovernanceToken     ProtocolGovernor     Timelock
 │                    │                    │               │
 │ delegate(voter)    │                    │               │
 │───────────────────>│                    │               │
 │                    │                    │               │
 │ propose(...)       │                    │               │
 │────────────────────────────────────────>│               │
 │                    │                    │               │
 │ castVote(for)      │                    │               │
 │────────────────────────────────────────>│               │
 │                    │                    │               │
 │                    │           check quorum(4%)        │
 │                    │                    │               │
 │                    │      queue(2d delay)              │
 │                    │                    │──────────────>│
 │                    │                    │               │
 │                    │    execute()       │               │
 │                    │                    │──────────────>│
 │                    │                    │               │
 │                    │                    │     execute(target)
```

### 3.3 Liquidity Provision Flow

```
LP              PredictionMarket         OutcomeToken
 │                     │                      │
 │ approve USDC        │                      │
 │────────────────────>│                      │
 │                     │                      │
 │ addLiquidity(1000)  │                      │
 │────────────────────>│                      │
 │                     │                      │
 │                     │ split 1000 USDC      │
 │                     │ into YES+NO          │
 │                     │─────────────────────>│
 │                     │                      │
 │                     │ add to reserves      │
 │                     │ (R_yes += 1000,      │
 │                     │  R_no += 1000)       │
 │                     │                      │
 │<── LP shares ───────│                      │
```

## 4. Data Model & Storage Layouts

### PredictionMarket Storage
```
slot 0:  _roles (AccessControl)
slot 1:  question (string)
slot 2:  resolutionTime (uint256)
slot 3:  disputeWindow (uint256)
slot 4:  outcomeToken (address)
slot 5:  outcomeIdYes (uint256)
slot 6:  outcomeIdNo (uint256)
slot 7:  baseToken (address)
slot 8:  feeBps (uint16) + packed
slot 9:  feeVault (address)
slot 10: priceFeed (address)
slot 11: reserveYes (uint256)
slot 12: reserveNo (uint256)
slot 13: totalLpShares (uint256)
slot 14: lpShares mapping
slot 15: resolved (bool) + winner (uint8)
slot 16: disputeEnd (uint256)
```

### FeeVault (UUPS) Storage Layout
```
slot 0:  _initialized, _initializing (Initializable)
slot 1:  __gap (UUPS)
slot 2-4: ERC20Upgradeable
slot 5-6: ERC4626Upgradeable
slot 7:  AccessControlUpgradeable
slot 8:  UUPSUpgradeable storage
slot 9:  totalFeesCollected (uint256)  ← V1 custom
slot 10: withdrawalFeeBps (uint256)    ← V2 added
```

**Storage Collision Proof**: UUPS proxy uses unstructured storage pattern via ERC1967Utils. V1 uses slots 0-9. V2 adds slot 10. No overlap possible.

## 5. Trust Assumptions

| Role | Powers | Risk if compromised |
|------|--------|-------------------|
| Timelock Admin | Can change delay, manage roles | Can backdoor protocol |
| Governor (DAO) | Propose, vote, execute | Flash loan governance attack mitigated by timelock |
| Market Resolver | Resolve markets | Can incorrectly resolve markets; mitigated by dispute window |
| Factory Admin | Deploy new markets | Can deploy malicious markets |
| FeeVault Admin | Upgrade vault, set fees | Can steal funds; mitigated by timelock control |

## 6. Design Decisions Log

### ADR-1: CPMM over LMSR
- **Context**: Prediction market pricing mechanism
- **Options**: CPMM (x*y=k), LMSR
- **Decision**: CPMM — simpler, gas-efficient, well-understood invariant
- **Consequences**: No bounded loss, but requires active liquidity

### ADR-2: UUPS over Transparent Proxy
- **Context**: FeeVault upgradeability
- **Options**: UUPS, Transparent Proxy, Beacon
- **Decision**: UUPS — lower gas per call, single implementation
- **Consequences**: Upgrade logic in implementation contract

### ADR-3: ERC-1155 over separate ERC-20 for outcomes
- **Context**: Outcome token representation
- **Options**: ERC-1155 (multi-token), individual ERC-20 per market
- **Decision**: ERC-1155 — efficient batch operations, single contract for all markets
- **Consequences**: Requires approval for market to burn tokens

### ADR-4: CREATE + CREATE2 in Factory
- **Context**: Market deployment
- **Options**: Only CREATE, only CREATE2, both
- **Decision**: Both — CREATE for standard, CREATE2 for deterministic deployment
- **Consequences**: More code, but flexible deployment

### ADR-5: Ownable vs AccessControl
- **Context**: Permission model
- **Options**: Ownable, AccessControl
- **Decision**: AccessControl — granular roles, DAO-friendly
- **Consequences**: More gas for role checks, but necessary for governance
