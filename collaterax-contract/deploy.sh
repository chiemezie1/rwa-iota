#!/bin/bash

# CollateraX Contract Deployment Script
# This script automates the deployment of CollateraX contracts to the IOTA testnet

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CollateraX Contract Deployment Tool   ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if IOTA CLI is installed
if ! command -v iota &> /dev/null; then
    echo -e "${RED}Error: IOTA CLI is not installed.${NC}"
    echo "Please install it from: https://wiki.iota.org/shimmer/iota-cli/welcome/"
    exit 1
fi

# Check if admin address is provided
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: ./deploy.sh <admin_address> [treasury_address]${NC}"
    echo "If treasury_address is not provided, admin_address will be used as treasury."
    exit 1
fi

ADMIN_ADDRESS=$1
TREASURY_ADDRESS=${2:-$ADMIN_ADDRESS}

echo -e "${YELLOW}Admin Address:${NC} $ADMIN_ADDRESS"
echo -e "${YELLOW}Treasury Address:${NC} $TREASURY_ADDRESS"
echo ""

# Build the contracts
echo -e "${GREEN}Building contracts...${NC}"
iota move build
echo -e "${GREEN}Build successful!${NC}"
echo ""

# Publish the package
echo -e "${GREEN}Publishing package to IOTA testnet...${NC}"
PACKAGE_ID=$(iota move publish | grep -oP 'Package ID: \K[0-9a-f]+')
echo -e "${GREEN}Package published successfully!${NC}"
echo -e "${YELLOW}Package ID:${NC} $PACKAGE_ID"
echo ""

# Initialize the contracts
echo -e "${GREEN}Initializing contracts...${NC}"

# Initialize SPV registry
echo "Initializing SPV registry..."
iota client call --function init_registry --module spv_registry --args $ADMIN_ADDRESS

# Initialize asset store
echo "Initializing asset store..."
iota client call --function init_store --module asset_nft --args $ADMIN_ADDRESS

# Initialize token registry
echo "Initializing token registry..."
iota client call --function init_registry --module asset_ft --args $ADMIN_ADDRESS

# Initialize governance (7 days voting period)
echo "Initializing governance DAO..."
iota client call --function init_registry --module governance_dao --args $ADMIN_ADDRESS 604800000

# Initialize staking
echo "Initializing staking..."
iota client call --function init_registry --module staking --args $ADMIN_ADDRESS

echo -e "${GREEN}All contracts initialized successfully!${NC}"
echo ""

# Save deployment info
echo -e "${GREEN}Saving deployment information...${NC}"
cat > deployment_info.json << EOL
{
  "deploymentTimestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "network": "testnet",
  "packageId": "$PACKAGE_ID",
  "adminAddress": "$ADMIN_ADDRESS",
  "treasuryAddress": "$TREASURY_ADDRESS",
  "modules": {
    "spv_registry": {
      "initialized": true
    },
    "asset_nft": {
      "initialized": true
    },
    "asset_ft": {
      "initialized": true
    },
    "governance_dao": {
      "initialized": true,
      "votingPeriodMs": 604800000
    },
    "staking": {
      "initialized": true
    }
  }
}
EOL

echo -e "${GREEN}Deployment information saved to deployment_info.json${NC}"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Deployment completed successfully!    ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "1. Register SPVs using: ${YELLOW}iota client call --function register_spv --module spv_registry${NC}"
echo -e "2. Verify SPVs using: ${YELLOW}iota client call --function verify_spv --module spv_registry${NC}"
echo -e "3. Create assets using: ${YELLOW}iota client call --function create_asset --module asset_nft${NC}"
echo ""
echo -e "For more details, refer to the README.md file."
