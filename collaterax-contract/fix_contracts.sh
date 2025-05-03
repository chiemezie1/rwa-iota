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

    # Fix incorrect import statements
    sed -i 's/use std::signer;::{String, utf8};/use std::signer;\nuse std::string::{String, utf8};/g' "$file"

    # Clean up duplicate imports
    sed -i '/^use std::string;$/d' "$file"
    sed -i '/^use std::error;$/d' "$file"
    sed -i '/^use std::signer;$/d' "$file"

    # Add proper imports at the top of the file
    sed -i '1s/^/use std::string::{String, utf8};\nuse std::error;\nuse std::signer;\n/' "$file"

    # Fix object imports
    sed -i 's/use iota::object::{Self, Object, ID};/use iota::object::{Self, UID, ID};/g' "$file"
    sed -i 's/use iota::object::{Self, UID, ID};/use iota::object::{Self, UID};/g' "$file"

    # Fix struct visibility (add public to struct declarations)
    sed -i 's/struct \([A-Za-z0-9_]*\) has key/public struct \1 has key/g' "$file"

    # Fix object ID type (replace ID with UID for first field in structs with key ability)
    sed -i 's/id: ID,/id: UID,/g' "$file"

    # Add UID as first field in structs with key ability that don't have it
    sed -i '/public struct \([A-Za-z0-9_]*\) has key {/a\\        id: UID,' "$file"

    # Fix incompatible types in math operations (ensure consistent types)
    sed -i 's/(10000 \* annual_ms)/(10000u128 \* (annual_ms as u128))/g' "$file"
    sed -i 's/reward_rate \/ (10000/(reward_rate \/ (10000u128/g' "$file"

    # Add drop ability to Stake struct if it exists in the file
    if grep -q "struct Stake has store" "$file"; then
        sed -i 's/struct Stake has store/public struct Stake has store, drop/g' "$file"
    fi

    # Fix object transfer
    sed -i 's/object::transfer(registry, admin_address);/object::share_object(registry);/g' "$file"
    sed -i 's/object::transfer(store, admin_address);/object::share_object(store);/g' "$file"

    # Fix unused variables
    sed -i 's/let total_rewards = stake.pending_rewards + reward;/let _total_rewards = stake.pending_rewards + reward;/g' "$file"

    # Fix destructuring of non-droppable types
    sed -i 's/table::remove(&mut pool.stakes, staker_address);/let Stake { amount: _, staked_at: _, last_reward_time: _, pending_rewards: _ } = table::remove(\&mut pool.stakes, staker_address);/g' "$file"

    # Fix AssetNFT drop issue
    sed -i 's/let AssetNFT {/let AssetNFT { id,/g' "$file"
    sed -i 's/id: _,/id: id,/g' "$file"

    echo -e "${GREEN}Fixed ${file}${NC}"
done

# Create a special fix for PoolRegistry and AssetStore to add UID as first field
for file in sources/staking.move sources/asset_nft.move sources/asset_ft.move sources/governance_dao.move; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}Applying special fixes to ${file}...${NC}"

        # Fix PoolRegistry struct
        if grep -q "public struct PoolRegistry has key" "$file"; then
            sed -i '/public struct PoolRegistry has key {/,/}/{/pools: Table<String, StakingPool>,/s/pools: Table<String, StakingPool>,/id: UID,\n        pools: Table<String, StakingPool>,/}' "$file"
        fi

        # Fix AssetStore struct
        if grep -q "public struct AssetStore has key" "$file"; then
            sed -i '/public struct AssetStore has key {/,/}/{/assets: Table<String, AssetNFT>,/s/assets: Table<String, AssetNFT>,/id: UID,\n        assets: Table<String, AssetNFT>,/}' "$file"
        fi

        # Fix TokenRegistry struct
        if grep -q "public struct TokenRegistry has key" "$file"; then
            sed -i '/public struct TokenRegistry has key {/,/}/{/tokens: Table<String, AssetToken>,/s/tokens: Table<String, AssetToken>,/id: UID,\n        tokens: Table<String, AssetToken>,/}' "$file"
        fi

        # Fix ProposalRegistry struct
        if grep -q "public struct ProposalRegistry has key" "$file"; then
            sed -i '/public struct ProposalRegistry has key {/,/}/{/proposals: Table<ID, Proposal>,/s/proposals: Table<ID, Proposal>,/id: UID,\n        proposals: Table<ID, Proposal>,/}' "$file"
        fi

        echo -e "${GREEN}Special fixes applied to ${file}${NC}"
    fi
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
