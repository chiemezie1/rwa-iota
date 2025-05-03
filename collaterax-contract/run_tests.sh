#!/bin/bash

# CollateraX Contract Test Runner
# This script runs all tests for the CollateraX contracts

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}     CollateraX Contract Test Runner     ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if IOTA CLI is installed
if ! command -v iota &> /dev/null; then
    echo -e "${RED}Error: IOTA CLI is not installed.${NC}"
    echo "Please install it from: https://wiki.iota.org/shimmer/iota-cli/welcome/"
    exit 1
fi

# Build the contracts
echo -e "${GREEN}Building contracts...${NC}"
iota move build
echo -e "${GREEN}Build successful!${NC}"
echo ""

# Run the main tests
echo -e "${GREEN}Running main test suite...${NC}"
iota move test collaterax::collaterax_tests
echo -e "${GREEN}Main tests completed successfully!${NC}"
echo ""

# Run the edge case tests
echo -e "${GREEN}Running edge case test suite...${NC}"
iota move test collaterax::collaterax_edge_tests
echo -e "${GREEN}Edge case tests completed successfully!${NC}"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}      All tests passed successfully!     ${NC}"
echo -e "${GREEN}=========================================${NC}"
