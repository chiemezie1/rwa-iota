#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::asset_ft {
    use std::string::{String, utf8};
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::transfer;
    use collaterax::errors::{E_NOT_AUTHORIZED, E_ALREADY_EXISTS, E_NOT_FOUND, E_INSUFFICIENT_BALANCE, E_ZERO_AMOUNT, E_REGISTRY_ALREADY_EXISTS};

    // Fee constants, etc.
    const PLATFORM_FEE_BP: u64 = 50;  // 0.5%
    const SPV_FEE_BP: u64 = 50;       // 0.5%
    const BASIS_POINTS: u64 = 10000;  // 100%

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

    public struct TokenRegistry has key {
        id: UID,
        admin: address,
        tokens: Table<String, AssetToken>,
        token_ids: vector<String>,
    }

    /// Initialize the token registry (shared object)
    public entry fun init_registry(_admin: &signer, ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        let registry = TokenRegistry {
            id: object::new(ctx),
            admin: admin_address,
            tokens: table::new(ctx),
            token_ids: vector::empty(),
        };
        transfer::share_object(registry);
    }

    /// Create a new token type (admin only)
    public entry fun create_token(
        _admin: &signer,
        registry: &mut TokenRegistry,
        asset_id: vector<u8>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        ctx: &mut TxContext
    ) acquires TokenRegistry {
        let admin_address = tx_context::sender(ctx);
        assert!(admin_address == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id_str = utf8(asset_id);
        assert!(!table::contains(&registry.tokens, asset_id_str),
                error::already_exists(E_ALREADY_EXISTS));

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

        table::add(&mut registry.tokens, asset_id_str, token);
        vector::push_back(&mut registry.token_ids, asset_id_str);
    }

    /// Mint additional tokens to a recipient (admin only)
    public entry fun mint(
        _admin: &signer,
        registry: &mut TokenRegistry,
        asset_id: vector<u8>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) acquires TokenRegistry {
        let admin_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        assert!(admin_address == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));
        assert!(table::contains(&registry.tokens, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let token_ref = table::borrow_mut(&mut registry.tokens, asset_id_str);
        token_ref.total_supply = token_ref.total_supply + amount;
        // (Token balances to recipient would be updated here in a real implementation)
    }

    /// Transfer tokens (balance checks omitted here)
    public entry fun transfer(
        _sender: &signer,
        registry: &mut TokenRegistry,
        asset_id: vector<u8>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) acquires TokenRegistry {
        let _sender_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        assert!(table::contains(&registry.tokens, asset_id_str),
                error::not_found(E_NOT_FOUND));

        // (Balance checks and ledger updates would go here)
    }

    /// Burn tokens (owner must have enough supply)
    public entry fun burn(
        _owner: &signer,
        registry: &mut TokenRegistry,
        asset_id: vector<u8>,
        amount: u64,
        ctx: &mut TxContext
    ) acquires TokenRegistry {
        let _owner_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        assert!(table::contains(&registry.tokens, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let token_ref = table::borrow_mut(&mut registry.tokens, asset_id_str);
        assert!(token_ref.total_supply >= amount,
                error::invalid_argument(E_INSUFFICIENT_BALANCE));

        token_ref.total_supply = token_ref.total_supply - amount;
        // (Owner's balance would be decremented here)
    }

    /// Get token metadata/details
    public fun get_token_details(
        registry: &TokenRegistry,
        asset_id: vector<u8>
    ): (String, String, String, u8, u64, address, u64) {
        let asset_id_str = utf8(asset_id);
        assert!(table::contains(&registry.tokens, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let token_ref = table::borrow(&registry.tokens, asset_id_str);
        (
            token_ref.asset_id,
            token_ref.name,
            token_ref.symbol,
            token_ref.decimals,
            token_ref.total_supply,
            token_ref.issuer,
            token_ref.created_at
        )
    }
}
