#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::asset_ft {
    use std::string::{String, utf8};
    use iota::error;
    use iota::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::coin::{Self, Coin};
    use iota::balance::{Self, Balance};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_TOKEN_ALREADY_EXISTS: u64 = 2;
    const E_TOKEN_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_ZERO_AMOUNT: u64 = 5;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 6;

    // Fee constants (in basis points, 1 bp = 0.01%)
    const PLATFORM_FEE_BP: u64 = 50; // 0.5%
    const SPV_FEE_BP: u64 = 50; // 0.5%
    const BASIS_POINTS: u64 = 10000; // 100%

    // Asset token struct
    public struct AssetToken has key, store {
        id: UID,
        asset_id: String,
        name: String,
        symbol: String,
        decimals: u8,
        total_supply: u64,
        issuer: address,
        admin: address,
        created_at: u64,
    }

    // Registry to store all tokens
    public struct TokenRegistry has key {
        id: UID,
        admin: address,
        tokens: Table<String, AssetToken>,
        token_ids: vector<String>,
    }

    // Initialize the token registry
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);

        let registry = TokenRegistry {
            id: object::new(ctx),
            admin: admin_address,
            tokens: table::new(ctx),
            token_ids: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        object::share_object(registry);
    }

    // Create a new token
    public entry fun create_token(
        admin: &signer,
        asset_id: vector<u8>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        ctx: &mut TxContext
    ) {
        let admin_address = signer::address_of(admin);

        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(admin_address == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id_str = utf8(asset_id);

        // Check if the token already exists
        assert!(!table::contains(&registry.tokens, asset_id_str), error::already_exists(E_TOKEN_ALREADY_EXISTS));

        // Create the token
        let token = AssetToken {
            id: object::new(ctx),
            asset_id: asset_id_str,
            name: utf8(name),
            symbol: utf8(symbol),
            decimals,
            total_supply,
            issuer: admin_address,
            admin: admin_address,
            created_at: tx_context::epoch_timestamp_ms(ctx),
        };

        // Add the token to the registry
        table::add(&mut registry.tokens, asset_id_str, token);
        vector::push_back(&mut registry.token_ids, asset_id_str);
    }

    /// Mint coins of an existing AssetToken into recipient balance
    public entry fun mint(
        admin: &signer,
        asset_id: String,
        amount: u64,
        recipient: &signer,
        ctx: &mut TxContext
    ) {
        let admin_addr = signer::address_of(admin);
        let store_ref = object::borrow_global_mut<RegistryStore>(admin_addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == admin_addr, error::permission_denied(E_NOT_AUTHORIZED));

        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        assert!(table::contains(&registry.tokens, asset_id), error::not_found(E_TOKEN_NOT_FOUND));

        // Increase total supply
        let token_ref = table::borrow_mut(&mut registry.tokens, asset_id);
        token_ref.total_supply = token_ref.total_supply + amount;

        // Mint coins using IOTA Coin module
        let recipient_addr = signer::address_of(recipient);
        coin::deposit<Balance>(recipient_addr, amount, ctx);
    }

    /// Transfer coins of an AssetToken from sender to receiver
    public entry fun transfer(
        sender: &signer,
        asset_id: String,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sender_addr = signer::address_of(sender);
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));

        // Check token exists
        let store_ref = object::borrow_global<RegistryStore>(sender_addr);
        let registry = option::borrow(&store_ref.registry);
        assert!(table::contains(&registry.tokens, asset_id), error::not_found(E_TOKEN_NOT_FOUND));

        // Perform coin transfer
        coin::withdraw<Balance>(sender_addr, amount, ctx);
        coin::deposit<Balance>(recipient, amount, ctx);
    }

    /// Retrieve a token's metadata
    public fun get_token(asset_id: String): AssetToken {
        let caller = signer::borrow_signer();
        let caller_addr = signer::address_of(&caller);
        let store_ref = object::borrow_global<RegistryStore>(caller_addr);
        let registry = option::borrow(&store_ref.registry);
        assert!(table::contains(&registry.tokens, asset_id), error::not_found(E_TOKEN_NOT_FOUND));
        table::borrow(&registry.tokens, asset_id)
    }

    /// List all token IDs
    public fun list_tokens(): vector<String> {
        let caller = signer::borrow_signer();
        let caller_addr = signer::address_of(&caller);
        let store_ref = object::borrow_global<RegistryStore>(caller_addr);
        let registry = option::borrow(&store_ref.registry);
        registry.token_keys
    }
}
