#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::asset_nft {
    use std::string::{String, utf8};
    use std::error;
    use std::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ASSET_ALREADY_EXISTS: u64 = 2;
    const E_ASSET_NOT_FOUND: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_STORE_ALREADY_EXISTS: u64 = 5;
    const E_NOT_BURNABLE: u64 = 6;
    const E_INVALID_METADATA: u64 = 7;

    // Asset NFT struct
    public struct AssetNFT has key, store {
        id: UID,
        asset_id: String,
        asset_type: String,
        title: String,
        description: String,
        metadata: String,
        owner: address,
        issuer: address,
        transferable: bool,
        burnable: bool,
        created_at: u64,
        last_updated: u64,
    }

    // Store to manage all assets
    public struct AssetStore has key {
        id: UID,
        admin: address,
        assets: Table<String, AssetNFT>,
        asset_ids: vector<String>,
    }

    // Initialize the asset store
    public entry fun init_store(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);

        let store = AssetStore {
            id: object::new(ctx),
            admin: admin_address,
            assets: table::new(ctx),
            asset_ids: vector::empty(),
        };

        // Share the store object so it can be accessed by anyone
        object::share_object(store);
    }

    // Helper function to borrow the store
    fun borrow_store(): &mut AssetStore {
        // In a real implementation, this would use a proper way to get the store
        // For testing purposes, we'll use a dummy implementation
        let dummy_store = AssetStore {
            id: object::new_for_testing(),
            admin: @0x1,
            assets: table::new_for_testing(),
            asset_ids: vector::empty(),
        };

        &mut dummy_store
    }
}
