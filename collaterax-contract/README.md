# CollateraX Smart Contract Suite

A Move-based smart contract platform for tokenizing real-world assets (RWA) on the IOTA blockchain.

## 📋 Quick Start

```bash
# Build the contracts
iota move build

# Run the tests
iota move test

# Deploy to testnet
iota move publish
```

## 🏗️ What is CollateraX?

CollateraX is a blockchain platform that enables the tokenization of real-world assets like real estate and company equity. It allows for:

- **Fractional ownership** of high-value assets
- **Transparent trading** of asset tokens
- **Decentralized governance** through DAO voting
- **Staking rewards** for token holders
- **Collateralized lending** using tokenized assets

## 📁 Contract Structure

```
collaterax-contract/
├── sources/
│   ├── spv_registry.move    # SPV management
│   ├── asset_nft.move       # Non-fungible asset tokens
│   ├── asset_ft.move        # Fungible tokens for fractional ownership
│   ├── governance_dao.move  # Governance and voting
│   └── staking.move         # Token staking and rewards
├── tests/
│   └── collaterax_tests.move # Comprehensive test suite
└── Move.toml                # Package configuration
```

## 🔧 Setup & Installation

### Prerequisites

- [IOTA CLI](https://wiki.iota.org/shimmer/iota-cli/welcome/) with Move support
- Access to IOTA testnet

### Installation Steps

1. **Install IOTA CLI**

   Follow the [official installation guide](https://wiki.iota.org/shimmer/iota-cli/welcome/).

2. **Configure IOTA CLI**

   ```bash
   iota config set node.url https://api.testnet.shimmer.network
   ```

3. **Clone this repository**

   ```bash
   git clone https://github.com/yourusername/collaterax.git
   cd collaterax/collaterax-contract
   ```

## 🧪 Testing

Run the comprehensive test suite:

```bash
iota move test
```

The test suite covers:
- SPV registration and verification
- Asset NFT creation and transfer
- Fungible token creation and trading
- Governance proposal creation and voting
- Token staking and reward distribution

## 🚀 Deployment

### 1. Build the contracts

```bash
iota move build
```

### 2. Create a wallet (if you don't have one)

```bash
iota wallet new
```

### 3. Get testnet tokens

Visit the [IOTA Testnet Faucet](https://faucet.testnet.shimmer.network/)

### 4. Publish the package

```bash
iota move publish
```

### 5. Initialize the contracts

```bash
# Set your admin address
ADMIN=0x123...abc

# Initialize all registries
iota client call --function init_registry --module spv_registry --args $ADMIN
iota client call --function init_store --module asset_nft --args $ADMIN
iota client call --function init_registry --module asset_ft --args $ADMIN
iota client call --function init_registry --module governance_dao --args $ADMIN 604800000
iota client call --function init_registry --module staking --args $ADMIN
```

## 📝 Contract Usage Examples

### Register an SPV

```bash
iota client call --function register_spv --module spv_registry --args \
  "Acme Real Estate SPV" \
  "SPV for Manhattan properties" \
  "United States" \
  "LLC-12345-NY"
```

### Create an Asset NFT

```bash
iota client call --function create_asset --module asset_nft --args \
  "ASSET001" \
  "real_estate" \
  "Luxury Apartment" \
  "A luxury apartment in downtown Manhattan" \
  "{\"location\":\"New York\",\"size\":\"2000 sqft\"}" \
  true \
  true
```

### Create Fungible Tokens

```bash
iota client call --function create_token --module asset_ft --args \
  "ASSET001" \
  "Luxury Apartment Token" \
  "LAT" \
  18 \
  1000000 \
  0xTREASURY_ADDRESS
```

### Transfer Tokens

```bash
iota client call --function transfer --module asset_ft --args \
  "ASSET001" \
  0xRECIPIENT_ADDRESS \
  100000
```

### Create a Governance Proposal

```bash
iota client call --function create_proposal --module governance_dao --args \
  "Increase APY for staking" \
  "Proposal to increase the APY for staking from 5% to 7%" \
  "ASSET001"
```

### Stake Tokens

```bash
iota client call --function stake --module staking --args \
  "ASSET001" \
  50000
```

## 🔍 Key Contract Features

### SPV Registry

- **Verified SPVs**: Only verified Special Purpose Vehicles can create assets
- **Admin Control**: Platform admin verifies, rejects, or suspends SPVs
- **Transparent Registry**: Public registry of all SPVs and their status

### Asset NFT

- **Unique Assets**: Each NFT represents a unique real-world asset
- **Metadata Storage**: Comprehensive metadata for each asset
- **Ownership Transfer**: Secure transfer of asset ownership

### Asset FT (Fungible Token)

- **Fractional Ownership**: Divisible tokens representing asset shares
- **Automatic Fee Distribution**: Fees split between platform and SPVs
- **Supply Management**: Controlled minting and burning of tokens

### Governance DAO

- **Proposal System**: Create and vote on platform proposals
- **Token-Weighted Voting**: Voting power proportional to token holdings
- **Execution Mechanism**: Automatic execution of approved proposals

### Staking

- **Reward Generation**: Earn rewards by staking asset tokens
- **Lock Periods**: Configurable lock periods for staked tokens
- **APY Management**: Adjustable annual percentage yield

## 🛡️ Security Notes

- Admin keys should be properly secured (consider multisig in production)
- SPV verification should include thorough off-chain due diligence
- Fee parameters are currently fixed but could be made configurable
- Consider formal verification for production deployment

## 📚 Additional Resources

- [IOTA Move Documentation](https://wiki.iota.org/shimmer/smart-contracts/guide/move/overview/)
- [Move Language Reference](https://move-language.github.io/move/)
- [IOTA Testnet Explorer](https://explorer.shimmer.network/testnet/)

## 📄 License

[MIT License](LICENSE)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
