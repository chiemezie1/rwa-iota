#!/bin/bash

# Fix script specifically for spv_registry.move
# This script addresses the specific issues in the spv_registry.move file

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Fixing spv_registry.move file         ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Check if the file exists
if [ ! -f "sources/spv_registry.move" ]; then
    echo -e "${RED}Error: sources/spv_registry.move not found.${NC}"
    exit 1
fi

# Create a backup
cp sources/spv_registry.move sources/spv_registry.move.bak

# Create a new file with the correct content
cat > sources/spv_registry.move << 'EOL'
#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::spv_registry {
    use std::string::{String, utf8};
    use std::error;
    use std::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_SPV_ALREADY_REGISTERED: u64 = 2;
    const E_SPV_NOT_FOUND: u64 = 3;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 4;
    const E_INVALID_STATUS: u64 = 5;

    // SPV status constants
    const STATUS_PENDING: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_SUSPENDED: u64 = 3;

    // SPV information struct
    public struct SPVInfo has key, store {
        id: UID,
        address: address,
        status: u64,
        name: String,
        description: String,
        jurisdiction: String,
        registration_number: String,
        registration_date: u64,
        last_updated: u64,
        verification_date: u64,
    }

    // Registry to store all SPVs
    public struct SPVRegistry has key {
        id: UID,
        admin: address,
        spvs: Table<address, SPVInfo>,
        spv_addresses: vector<address>, // Store SPV addresses for iteration
    }

    // Initialize the SPV registry
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);

        let registry = SPVRegistry {
            id: object::new(ctx),
            admin: admin_address,
            spvs: table::new(ctx),
            spv_addresses: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        object::share_object(registry);
    }

    // Register a new SPV
    public entry fun register_spv(
        spv: &signer,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        registration_date: u64,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        
        // Get the registry
        let registry = borrow_registry();
        
        // Check if the SPV is already registered
        assert!(!table::contains(&registry.spvs, spv_address), error::already_exists(E_SPV_ALREADY_REGISTERED));
        
        // Create the SPV info
        let spv_info = SPVInfo {
            id: object::new(ctx),
            address: spv_address,
            status: STATUS_PENDING,
            name: utf8(name),
            description: utf8(description),
            jurisdiction: utf8(jurisdiction),
            registration_number: utf8(registration_number),
            registration_date: registration_date,
            last_updated: registration_date,
            verification_date: 0,
        };
        
        // Add the SPV to the registry
        table::add(&mut registry.spvs, spv_address, spv_info);
        vector::push_back(&mut registry.spv_addresses, spv_address);
    }

    // Approve an SPV
    public entry fun approve_spv(
        admin: &signer,
        spv_address: address,
        verification_date: u64,
        ctx: &mut TxContext
    ) {
        // Check if the caller is the admin
        assert!(signer::address_of(admin) == borrow_registry().admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Get the registry
        let registry = borrow_registry();
        
        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        
        // Update the SPV status
        spv_info.status = STATUS_APPROVED;
        spv_info.verification_date = verification_date;
        spv_info.last_updated = verification_date;
    }

    // Reject an SPV
    public entry fun reject_spv(
        admin: &signer,
        spv_address: address,
        ctx: &mut TxContext
    ) {
        // Check if the caller is the admin
        assert!(signer::address_of(admin) == borrow_registry().admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Get the registry
        let registry = borrow_registry();
        
        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        
        // Update the SPV status
        spv_info.status = STATUS_REJECTED;
        spv_info.last_updated = ctx.timestamp_ms();
    }

    // Suspend an SPV
    public entry fun suspend_spv(
        admin: &signer,
        spv_address: address,
        ctx: &mut TxContext
    ) {
        // Check if the caller is the admin
        assert!(signer::address_of(admin) == borrow_registry().admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Get the registry
        let registry = borrow_registry();
        
        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        
        // Update the SPV status
        spv_info.status = STATUS_SUSPENDED;
        spv_info.last_updated = ctx.timestamp_ms();
    }

    // Update SPV information
    public entry fun update_spv_info(
        spv: &signer,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        
        // Get the registry
        let registry = borrow_registry();
        
        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        
        // Update the SPV info
        spv_info.name = utf8(name);
        spv_info.description = utf8(description);
        spv_info.jurisdiction = utf8(jurisdiction);
        spv_info.registration_number = utf8(registration_number);
        spv_info.last_updated = ctx.timestamp_ms();
    }

    // Check if an SPV is verified
    public fun is_verified_spv(spv_address: address, registry: &SPVRegistry): bool {
        if (!table::contains(&registry.spvs, spv_address)) {
            return false;
        }
        
        let spv_info = table::borrow(&registry.spvs, spv_address);
        
        spv_info.status == STATUS_APPROVED
    }

    // Get SPV information
    public fun get_spv_info(
        registry: &SPVRegistry,
        spv_address: address
    ): (String, String, String, String, u64, u64, u64) {
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        let spv_info = table::borrow(&registry.spvs, spv_address);
        
        (
            spv_info.name,
            spv_info.description,
            spv_info.jurisdiction,
            spv_info.registration_number,
            spv_info.registration_date,
            spv_info.verification_date,
            spv_info.status
        )
    }

    // Helper function to borrow the registry
    fun borrow_registry(): &mut SPVRegistry {
        // In a real implementation, this would use object::borrow_global_mut
        // For now, we'll just return a placeholder
        abort 0 // This will be replaced in the actual implementation
    }
}
EOL

echo -e "${GREEN}Fixed spv_registry.move file${NC}"
echo -e "The original file has been backed up as sources/spv_registry.move.bak"
echo ""
echo -e "${YELLOW}Note: This is a complete rewrite of the file with corrected code.${NC}"
echo -e "${YELLOW}You will need to implement the borrow_registry() function properly.${NC}"
echo ""
echo -e "Next steps:"
echo -e "1. Review the changes to ensure they're correct"
echo -e "2. Run ${YELLOW}iota move build${NC} to check if the errors are resolved"
echo -e "3. If there are still errors, you may need to make manual fixes"
