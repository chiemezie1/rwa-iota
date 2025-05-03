#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::asset_ft {
    use std::string::{String, utf8};
    use std::error;
    use std::signer;
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

    // Asset token struct
    public struct AssetToken has store {
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

    // Helper function to borrow the registry
    fun borrow_registry(): &mut TokenRegistry {
        // In a real implementation, this would use a proper way to get the registry
        // For testing purposes, we'll use a dummy implementation
        let dummy_registry = TokenRegistry {
            id: object::new_for_testing(),
            admin: @0x1,
            tokens: table::new_for_testing(),
            token_ids: vector::empty(),
        };

        &mut dummy_registry
    }
}
