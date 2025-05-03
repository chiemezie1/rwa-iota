#!/bin/bash

# CollateraX Contract Fix Script V2
# This script fixes specific issues in the Move contracts

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   CollateraX Contract Fix Script V2     ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "sources" ]; then
    echo -e "${RED}Error: 'sources' directory not found.${NC}"
    echo "Please run this script from the collaterax-contract directory."
    exit 1
fi

echo -e "${YELLOW}Fixing specific issues in Move contracts...${NC}"

# Process each Move file
for file in sources/*.move; do
    echo -e "${GREEN}Processing ${file}...${NC}"
    
    # Create a backup
    cp "$file" "${file}.bak"
    
    # Fix imports at the top of the file
    cat > "$file" << EOL
module collaterax::$(basename "$file" .move) {
    use std::string::{String, utf8};
    use std::error;
    use std::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
EOL

    # Append the rest of the file, skipping the module declaration and imports
    sed -n '/^module/,${p}' "${file}.bak" | 
    sed '1,/use/d' | 
    sed '/^use/d' >> "$file"
    
    # Fix duplicate public modifiers
    sed -i 's/public public struct/public struct/g' "$file"
    
    # Fix object ID type (replace ID with UID for first field in structs with key ability)
    sed -i 's/id: ID,/id: UID,/g' "$file"
    
    # Add UID as first field in structs with key ability that don't have it
    sed -i '/public struct \([A-Za-z0-9_]*\) has key {/a\\        id: UID,' "$file"
    
    # Fix object transfer
    sed -i 's/object::transfer(registry, admin_address);/object::share_object(registry);/g' "$file"
    sed -i 's/object::transfer(store, admin_address);/object::share_object(store);/g' "$file"
    
    # Fix proposal ID type in function parameters
    sed -i 's/proposal_id: UID,/proposal_id: ID,/g' "$file"
    
    # Fix unused variables
    sed -i 's/let total_rewards = stake.pending_rewards + reward;/let _total_rewards = stake.pending_rewards + reward;/g' "$file"
    sed -i 's/let executor_address = signer::address_of(executor);/let _executor_address = signer::address_of(executor);/g' "$file"
    
    # Fix destructuring of non-droppable types
    sed -i 's/table::remove(&mut pool.stakes, staker_address);/let Stake { amount: _, staked_at: _, last_reward_time: _, pending_rewards: _ } = table::remove(\&mut pool.stakes, staker_address);/g' "$file"
    
    # Fix AssetNFT drop issue
    sed -i 's/let AssetNFT {/let AssetNFT { id,/g' "$file"
    sed -i 's/id: _,/id: id,/g' "$file"
    
    # Add #[allow] attributes to suppress warnings
    sed -i '1s/^module/\n#[allow(unused_use, unused_const, duplicate_alias)]\nmodule/' "$file"
    
    echo -e "${GREEN}Fixed ${file}${NC}"
done

# Create a special fix for struct declarations
for file in sources/*.move; do
    echo -e "${YELLOW}Applying special fixes to ${file}...${NC}"
    
    # Remove duplicate UID fields that might have been added
    sed -i '/id: UID,/{n;/id: UID,/d;}' "$file"
    
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
        # Fix the ID type in the table
        sed -i 's/proposals: Table<ID, Proposal>,/proposals: Table<UID, Proposal>,/g' "$file"
    fi
    
    # Fix SPVRegistry struct
    if grep -q "public struct SPVRegistry has key" "$file"; then
        sed -i '/public struct SPVRegistry has key {/,/}/{/spvs: Table<address, SPVInfo>,/s/spvs: Table<address, SPVInfo>,/id: UID,\n        spvs: Table<address, SPVInfo>,/}' "$file"
    fi
    
    # Fix Proposal struct
    if grep -q "public struct Proposal has key" "$file"; then
        sed -i '/public struct Proposal has key, store {/,/}/{/title: String,/s/title: String,/id: UID,\n        title: String,/}' "$file"
    fi
    
    echo -e "${GREEN}Special fixes applied to ${file}${NC}"
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
