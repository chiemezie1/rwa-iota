#!/bin/bash

# Fix script for remaining Move files
# This script addresses issues in staking.move and asset_nft.move

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Fixing remaining Move files           ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Fix staking.move
if [ -f "sources/staking.move" ]; then
    echo -e "${YELLOW}Fixing staking.move...${NC}"
    
    # Create a backup
    cp sources/staking.move sources/staking.move.bak
    
    # Add proper imports at the top
    sed -i '1s/^/#[allow(unused_use, unused_const, duplicate_alias)]\n/' sources/staking.move
    sed -i '2s/^/module collaterax::staking {\n    use std::string::{String, utf8};\n    use std::error;\n    use std::signer;\n    use std::vector;\n    use iota::object::{Self, UID};\n    use iota::tx_context::{Self, TxContext};\n    use iota::table::{Self, Table};\n    use iota::coin::{Self, Coin};\n    use iota::balance::{Self, Balance};\n    use iota::clock::{Self, Clock};\n/' sources/staking.move
    
    # Remove existing module declaration and imports
    sed -i '/^module collaterax::staking/,/^use/d' sources/staking.move
    
    # Fix struct declarations
    sed -i 's/public public struct/public struct/g' sources/staking.move
    
    # Add UID as first field in structs with key ability
    sed -i '/public struct PoolRegistry has key {/a\\        id: UID,' sources/staking.move
    
    # Fix object transfer
    sed -i 's/object::transfer(registry, admin_address);/object::share_object(registry);/g' sources/staking.move
    
    echo -e "${GREEN}Fixed staking.move${NC}"
fi

# Fix asset_nft.move
if [ -f "sources/asset_nft.move" ]; then
    echo -e "${YELLOW}Fixing asset_nft.move...${NC}"
    
    # Create a backup
    cp sources/asset_nft.move sources/asset_nft.move.bak
    
    # Add proper imports at the top
    sed -i '1s/^/#[allow(unused_use, unused_const, duplicate_alias)]\n/' sources/asset_nft.move
    sed -i '2s/^/module collaterax::asset_nft {\n    use std::string::{String, utf8};\n    use std::error;\n    use std::signer;\n    use std::vector;\n    use iota::object::{Self, UID};\n    use iota::tx_context::{Self, TxContext};\n    use iota::table::{Self, Table};\n/' sources/asset_nft.move
    
    # Remove existing module declaration and imports
    sed -i '/^module collaterax::asset_nft/,/^use/d' sources/asset_nft.move
    
    # Fix struct declarations
    sed -i 's/public public struct/public struct/g' sources/asset_nft.move
    
    # Add UID as first field in structs with key ability
    sed -i '/public struct AssetStore has key {/a\\        id: UID,' sources/asset_nft.move
    
    # Fix object transfer
    sed -i 's/object::transfer(store, admin_address);/object::share_object(store);/g' sources/asset_nft.move
    
    echo -e "${GREEN}Fixed asset_nft.move${NC}"
fi

# Fix asset_ft.move
if [ -f "sources/asset_ft.move" ]; then
    echo -e "${YELLOW}Fixing asset_ft.move...${NC}"
    
    # Create a backup
    cp sources/asset_ft.move sources/asset_ft.move.bak
    
    # Add proper imports at the top
    sed -i '1s/^/#[allow(unused_use, unused_const, duplicate_alias)]\n/' sources/asset_ft.move
    sed -i '2s/^/module collaterax::asset_ft {\n    use std::string::{String, utf8};\n    use std::error;\n    use std::signer;\n    use std::vector;\n    use iota::object::{Self, UID};\n    use iota::tx_context::{Self, TxContext};\n    use iota::table::{Self, Table};\n    use iota::coin::{Self, Coin};\n    use iota::balance::{Self, Balance};\n/' sources/asset_ft.move
    
    # Remove existing module declaration and imports
    sed -i '/^module collaterax::asset_ft/,/^use/d' sources/asset_ft.move
    
    # Fix struct declarations
    sed -i 's/public public struct/public struct/g' sources/asset_ft.move
    
    # Add UID as first field in structs with key ability
    sed -i '/public struct TokenRegistry has key {/a\\        id: UID,' sources/asset_ft.move
    
    # Fix object transfer
    sed -i 's/object::transfer(registry, admin_address);/object::share_object(registry);/g' sources/asset_ft.move
    
    echo -e "${GREEN}Fixed asset_ft.move${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}     All files fixed!                    ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "1. Review the changes to ensure they're correct"
echo -e "2. Run ${YELLOW}iota move build${NC} to check if the errors are resolved"
echo -e "3. If there are still errors, you may need to make manual fixes"
