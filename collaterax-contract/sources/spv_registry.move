module collaterax::spv_registry {
    use std::signer;
    use std::vector::{self};
    use std::option::{self, Option};
    use std::string::{self, String, utf8};
    use iota::error;
    use iota::tx_context::{self, TxContext};
    use iota::object::{self, UID};
    use iota::table::{self, Table};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_SPV_ALREADY_REGISTERED: u64 = 2;
    const E_SPV_NOT_FOUND: u64 = 3;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 4;

    // SPV status constants
    const STATUS_PENDING: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_SUSPENDED: u64 = 3;

    // SPV Information
    public struct SPVInfo has store {
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

    // Registry singleton storing SPVs
    public struct RegistryStore has key {
        registry: Option<SPVRegistry>,
    }

    public struct SPVRegistry has store {
        id: UID,
        admin: address,
        spvs: Table<address, SPVInfo>,
        addresses: vector<address>,
    }

    // Initialize RegistryStore
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let addr = signer::address_of(admin);
        assert!(!object::exists<RegistryStore>(addr), error::already_exists(E_REGISTRY_ALREADY_EXISTS));

        let registry = SPVRegistry {
            id: object::new(ctx),
            admin: addr,
            spvs: table::new(ctx),
            addresses: vector::empty(),
        };
        let store = RegistryStore { registry: option::some(registry) };
        object::publish_object(store);
    }

    // Register SPV
    public entry fun register_spv(
        spv: &signer,
        name_b: vector<u8>,
        description_b: vector<u8>,
        jurisdiction_b: vector<u8>,
        reg_no_b: vector<u8>,
        reg_date: u64,
        ctx: &mut TxContext
    ) {
        let addr = signer::address_of(spv);
        let store_ref = object::borrow_global_mut<RegistryStore>(addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == addr, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(!table::contains(&registry.spvs, addr), error::already_exists(E_SPV_ALREADY_REGISTERED));

        let info = SPVInfo {
            id: object::new(ctx),
            address: addr,
            status: STATUS_PENDING,
            name: utf8(name_b),
            description: utf8(description_b),
            jurisdiction: utf8(jurisdiction_b),
            registration_number: utf8(reg_no_b),
            registration_date: reg_date,
            last_updated: reg_date,
            verification_date: 0,
        };
        table::add(&mut registry.spvs, addr, info);
        vector::push_back(&mut registry.addresses, addr);
    }

    // Approve SPV
    public entry fun approve_spv(
        admin: &signer,
        spv_addr: address,
        verify_date: u64
    ) {
        let addr = signer::address_of(admin);
        let store_ref = object::borrow_global_mut<RegistryStore>(addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == addr, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_addr), error::not_found(E_SPV_NOT_FOUND));

        let info_ref = table::borrow_mut(&mut registry.spvs, spv_addr);
        info_ref.status = STATUS_APPROVED;
        info_ref.verification_date = verify_date;
        info_ref.last_updated = verify_date;
    }

    // Reject SPV
    public entry fun reject_spv(
        admin: &signer,
        spv_addr: address
    ) {
        let addr = signer::address_of(admin);
        let store_ref = object::borrow_global_mut<RegistryStore>(addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == addr, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_addr), error::not_found(E_SPV_NOT_FOUND));

        let info_ref = table::borrow_mut(&mut registry.spvs, spv_addr);
        info_ref.status = STATUS_REJECTED;
        info_ref.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // Suspend SPV
    public entry fun suspend_spv(
        admin: &signer,
        spv_addr: address
    ) {
        let addr = signer::address_of(admin);
        let store_ref = object::borrow_global_mut<RegistryStore>(addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == addr, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.spvs, spv_addr), error::not_found(E_SPV_NOT_FOUND));

        let info_ref = table::borrow_mut(&mut registry.spvs, spv_addr);
        info_ref.status = STATUS_SUSPENDED;
        info_ref.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // View SPV Info
    public fun get_spv_info(spv_addr: address): SPVInfo {
        let addr = signer::address_of(&signer::borrow_signer());
        let store_ref = object::borrow_global<RegistryStore>(addr);
        let registry = option::borrow(&store_ref.registry);
        assert!(table::contains(&registry.spvs, spv_addr), error::not_found(E_SPV_NOT_FOUND));
        table::borrow(&registry.spvs, spv_addr)
    }

    // List all SPV addresses
    public fun list_spvs(): vector<address> {
        let addr = signer::address_of(&signer::borrow_signer());
        let store_ref = object::borrow_global<RegistryStore>(addr);
        let registry = option::borrow(&store_ref.registry);
        registry.addresses
    }
}
