#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::spv_registry {
    use std::string::{String, utf8};
    use std::error;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::transfer;
    use collaterax::errors::{E_NOT_AUTHORIZED, E_ALREADY_EXISTS, E_NOT_FOUND};

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

    public struct SPVRegistry has key {
        id: UID,
        admin: address,
        spvs: Table<address, SPVInfo>,
        spv_addresses: vector<address>,
    }

    /// Initialize the SPV registry
    public entry fun init_registry(_admin: &signer, ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        let registry = SPVRegistry {
            id: object::new(ctx),
            admin: admin_address,
            spvs: table::new(ctx),
            spv_addresses: vector::empty(),
        };
        transfer::share_object(registry);
    }

    /// Register a new SPV (pending by default)
    public entry fun register_spv(
        _spv: &signer,
        registry: &mut SPVRegistry,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        registration_date: u64,
        ctx: &mut TxContext
    ) acquires SPVRegistry {
        let spv_address = tx_context::sender(ctx);

        assert!(!table::contains(&registry.spvs, spv_address),
                error::already_exists(E_ALREADY_EXISTS));

        let spv_info = SPVInfo {
            id: object::new(ctx),
            address: spv_address,
            status: STATUS_PENDING,
            name: utf8(name),
            description: utf8(description),
            jurisdiction: utf8(jurisdiction),
            registration_number: utf8(registration_number),
            registration_date,
            last_updated: registration_date,
            verification_date: 0,
        };

        table::add(&mut registry.spvs, spv_address, spv_info);
        vector::push_back(&mut registry.spv_addresses, spv_address);
    }

    /// Approve a pending SPV (admin only)
    public entry fun approve_spv(
        _admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) acquires SPVRegistry {
        assert!(tx_context::sender(ctx) == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_address),
                error::not_found(E_NOT_FOUND));

        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_APPROVED;
        spv_info.verification_date = tx_context::epoch_timestamp_ms(ctx);
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Reject an SPV (admin only)
    public entry fun reject_spv(
        _admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) acquires SPVRegistry {
        assert!(tx_context::sender(ctx) == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_address),
                error::not_found(E_NOT_FOUND));

        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_REJECTED;
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Suspend an SPV (admin only)
    public entry fun suspend_spv(
        _admin: &signer,
        spv_address: address,
        registry: &mut SPVRegistry,
        ctx: &mut TxContext
    ) acquires SPVRegistry {
        assert!(tx_context::sender(ctx) == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_address),
                error::not_found(E_NOT_FOUND));

        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.status = STATUS_SUSPENDED;
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Get information about an SPV
    public fun get_spv_info(
        registry: &SPVRegistry,
        spv_address: address
    ): (String, String, String, String, u64, u64, u64) {
        assert!(table::contains(&registry.spvs, spv_address),
                error::not_found(E_NOT_FOUND));

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

    /// Update SPV's own information
    public entry fun update_spv_info(
        _spv: &signer,
        registry: &mut SPVRegistry,
        name: vector<u8>,
        description: vector<u8>,
        jurisdiction: vector<u8>,
        registration_number: vector<u8>,
        ctx: &mut TxContext
    ) acquires SPVRegistry {
        let spv_address = tx_context::sender(ctx);
        assert!(table::contains(&registry.spvs, spv_address),
                error::not_found(E_NOT_FOUND));

        let spv_info = table::borrow_mut(&mut registry.spvs, spv_address);
        spv_info.name = utf8(name);
        spv_info.description = utf8(description);
        spv_info.jurisdiction = utf8(jurisdiction);
        spv_info.registration_number = utf8(registration_number);
        spv_info.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }
}
