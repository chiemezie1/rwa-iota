#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::spv_registry {
    use std::string::{String, utf8};
    use std::error;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::transfer;

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
        let admin_address = tx_context::sender(ctx);

        let registry = SPVRegistry {
            id: object::new(ctx),
            admin: admin_address,
            spvs: table::new(ctx),
            spv_addresses: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        transfer::share_object(registry);
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
        let spv_address = tx_context::sender(ctx);

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
        ctx: &mut TxContext
    ) {
        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(tx_context::sender(ctx) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));

        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);

        // Update the SPV status
        spv_info.status = STATUS_APPROVED;
        spv_info.verification_date = tx_context::epoch_timestamp_ms(ctx);
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // Reject an SPV
    public entry fun reject_spv(
        admin: &signer,
        spv_address: address,
        ctx: &mut TxContext
    ) {
        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(tx_context::sender(ctx) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));

        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);

        // Update the SPV status
        spv_info.status = STATUS_REJECTED;
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // Suspend an SPV
    public entry fun suspend_spv(
        admin: &signer,
        spv_address: address,
        ctx: &mut TxContext
    ) {
        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(tx_context::sender(ctx) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));

        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);

        // Update the SPV status
        spv_info.status = STATUS_SUSPENDED;
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
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
            spv_info.status,
            spv_info.registration_date,
            spv_info.verification_date
        )
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
        let spv_address = tx_context::sender(ctx);

        // Get the registry
        let registry = borrow_registry();

        // Check if the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));

        // Get the SPV info
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);

        // Update the SPV information
        spv_info.name = utf8(name);
        spv_info.description = utf8(description);
        spv_info.jurisdiction = utf8(jurisdiction);
        spv_info.registration_number = utf8(registration_number);
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // Helper function to borrow the registry
    fun borrow_registry(): &mut SPVRegistry {
        // In a real implementation, this would use a proper way to get the registry
        // For testing purposes, we'll use a dummy implementation
        let ctx = tx_context::dummy();
        let dummy_registry = SPVRegistry {
            id: object::new(&mut ctx),
            admin: @0x1,
            spvs: table::new(&mut ctx),
            spv_addresses: vector::empty(),
        };

        &mut dummy_registry
    }
}
