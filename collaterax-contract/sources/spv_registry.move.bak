use std::string::{String, utf8};
use std::error;
use std::signer;
/// SPV Registry Module
/// 
/// This module manages the registration and verification of Special Purpose Vehicles (SPVs)
/// that are authorized to tokenize real-world assets on the CollateraX platform.
/// 
/// SPVs are legal entities that verify and hold real-world assets, ensuring compliance
/// and proper custody. Only registered SPVs can create and verify new assets.
module collaterax::spv_registry {
    use std::string::{String, utf8};
    use std::vector;
    use std::error;
    use std::signer;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_SPV_ALREADY_REGISTERED: u64 = 2;
    const E_SPV_NOT_FOUND: u64 = 3;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 4;
    const E_INVALID_STATUS: u64 = 5;

    /// SPV verification status
    const STATUS_PENDING: u64 = 0;
    const STATUS_VERIFIED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_SUSPENDED: u64 = 3;

    /// Stores information about a registered SPV
    public struct SPVInfo has key, store {
        /// Unique identifier for the SPV
        id: UID,
        /// Address of the SPV
        address: address,
        /// Legal name of the SPV
        name: String,
        /// Description of the SPV
        description: String,
        /// Jurisdiction where the SPV is registered
        jurisdiction: String,
        /// Registration number or identifier in the jurisdiction
        registration_number: String,
        /// Verification status (0=pending, 1=verified, 2=rejected, 3=suspended)
        status: u64,
        /// Timestamp when the SPV was registered
        registered_at: u64,
        /// Timestamp when the SPV was last updated
        updated_at: u64
    }

    /// Global registry of SPVs
    public struct SPVRegistry has key {
        id: UID,
        /// Table mapping SPV addresses to their info
        spvs: Table<address, SPVInfo>,
        /// List of all SPV addresses for enumeration
        spv_addresses: vector<address>,
        /// Address of the admin who can verify SPVs
        admin: address
    }

    /// Initialize the SPV registry
    /// Can only be called once by the platform admin
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);
        
        // Create a new registry object
        let registry = SPVRegistry {
            spvs: table::new(ctx),
            spv_addresses: vector::empty<address>(),
            admin: admin_address
        };
        
        // Move the registry to the global storage
        object::share_object(registry);
    }

    /// Register a new SPV
    /// Any address can register as an SPV, but they start with pending status
    public entry fun register_spv(
        spv: &signer,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        
        // Ensure the SPV is not already registered
        assert!(!table::contains(&registry.spvs, spv_address), error::already_exists(E_SPV_ALREADY_REGISTERED));
        
        // Create a new SPV info object
        let spv_info = SPVInfo {
            id: object::new(ctx),
            address: spv_address,
            name: utf8(name),
            description: utf8(description),
            jurisdiction: utf8(jurisdiction),
            registration_number: utf8(registration_number),
            status: STATUS_PENDING,
            registered_at: tx_context::epoch_timestamp_ms(ctx),
            updated_at: tx_context::epoch_timestamp_ms(ctx)
        };
        
        // Add the SPV to the registry
        table::add(&mut registry.spvs, spv_address, spv_info);
        vector::push_back(&mut registry.spv_addresses, spv_address);
    }

    /// Verify an SPV
    /// Only the admin can verify SPVs
    public entry fun verify_spv(
        admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the admin
        assert!(signer::address_of(admin) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Ensure the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Update the SPV status to verified
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_VERIFIED;
        spv_info.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Reject an SPV
    /// Only the admin can reject SPVs
    public entry fun reject_spv(
        admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the admin
        assert!(signer::address_of(admin) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Ensure the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Update the SPV status to rejected
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_REJECTED;
        spv_info.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Suspend an SPV
    /// Only the admin can suspend SPVs
    public entry fun suspend_spv(
        admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) {
        // Ensure the caller is the admin
        assert!(signer::address_of(admin) == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Ensure the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Update the SPV status to suspended
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_SUSPENDED;
        spv_info.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Update SPV information
    /// Only the SPV itself can update its information
    public entry fun update_spv_info(
        spv: &signer,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        
        // Ensure the SPV exists
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        // Update the SPV information
        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.name = utf8(name);
        spv_info.description = utf8(description);
        spv_info.jurisdiction = utf8(jurisdiction);
        spv_info.registration_number = utf8(registration_number);
        spv_info.updated_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Check if an address is a verified SPV
    public fun is_verified_spv(spv_address: address, registry: &SPVRegistry): bool {
        if (!table::contains(&registry.spvs, spv_address)) {
            return false
        };
        
        let spv_info = table::borrow(&registry.spvs, spv_address);
        spv_info.status == STATUS_VERIFIED
    }

    /// Get the number of registered SPVs
    public fun get_spv_count(registry: &SPVRegistry): u64 {
        vector::length(&registry.spv_addresses)
    }

    /// Get an SPV address by index
    public fun get_spv_address_by_index(registry: &SPVRegistry, index: u64): address {
        *vector::borrow(&registry.spv_addresses, index)
    }

    /// Get SPV information
    public fun get_spv_info(
        spv_address: address,
        registry: &SPVRegistry
    ): (String, String, String, String, u64, u64, u64) {
        assert!(table::contains(&registry.spvs, spv_address), error::not_found(E_SPV_NOT_FOUND));
        
        let spv_info = table::borrow(&registry.spvs, spv_address);
        (
            spv_info.name,
            spv_info.description,
            spv_info.jurisdiction,
            spv_info.registration_number,
            spv_info.status,
            spv_info.registered_at,
            spv_info.updated_at
        )
    }
}
