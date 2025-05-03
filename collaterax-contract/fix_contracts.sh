#!/bin/bash

# CollateraX Contract Fix Script
# This script fixes common issues in the Move contracts

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}     CollateraX Contract Fix Script      ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "sources" ]; then
    echo -e "${RED}Error: 'sources' directory not found.${NC}"
    echo "Please run this script from the collaterax-contract directory."
    exit 1
fi

echo -e "${YELLOW}Fixing common issues in Move contracts...${NC}"

# Fix missing imports and other issues in all Move files
for file in sources/*.move; do
    echo -e "${GREEN}Processing ${file}...${NC}"
    
    # Add missing imports
    sed -i '1,20s/use std::string/use std::string;\nuse std::error;\nuse std::signer;/g' "$file"
    
    # Fix object ID type (replace ID with UID for first field in structs with key ability)
    sed -i 's/id: ID,/id: UID,/g' "$file"
    sed -i 's/use iota::object::{Self, Object, ID};/use iota::object::{Self, UID, ID};/g' "$file"
    
    # Fix struct visibility (add public to struct declarations)
    sed -i 's/struct \([A-Za-z0-9_]*\) has key/public struct \1 has key/g' "$file"
    
    # Fix incompatible types in math operations (ensure consistent types)
    sed -i 's/(10000 \* annual_ms)/(10000u128 \* (annual_ms as u128))/g' "$file"
    
    # Fix object creation (ensure we're using object::new correctly)
    sed -i 's/id: object::new(ctx),/id: object::new(ctx),/g' "$file"
    
    # Add drop ability to Stake struct if it exists in the file
    if grep -q "struct Stake has store" "$file"; then
        sed -i 's/struct Stake has store/public struct Stake has store, drop/g' "$file"
    fi
    
    echo -e "${GREEN}Fixed ${file}${NC}"
done

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}     Contract fixes applied!             ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "1. Review the changes to ensure they're correct"
echo -e "2. Run ${YELLOW}iota move build${NC} to check if the errors are resolved"
echo -e "3. If there are still errors, you may need to make manual fixes"
echo ""
echo -e "For more detailed instructions, refer to the README.md file."
