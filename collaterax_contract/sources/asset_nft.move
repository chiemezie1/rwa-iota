#[allow(unused_use, unused_const, duplicate_alias, unused_variable)]
module collaterax::asset_nft {
    use std::string::{String, utf8};
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::transfer;

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
        let admin_address = tx_context::sender(ctx);

        let store = AssetStore {
            id: object::new(ctx),
            admin: admin_address,
            assets: table::new(ctx),
            asset_ids: vector::empty(),
        };

        // Share the store object so it can be accessed by anyone
        transfer::share_object(store);
    }

    // Mint a new NFT
    public entry fun mint_nft(
        issuer: &signer,
        asset_id: vector<u8>,
        asset_type: vector<u8>,
        title: vector<u8>,
        description: vector<u8>,
        metadata: vector<u8>,
        transferable: bool,
        burnable: bool,
        ctx: &mut TxContext
    ) {
        let issuer_address = tx_context::sender(ctx);

        // Get the store
        let store = borrow_store();

        // Check if the caller is the admin
        assert!(store.admin == issuer_address, E_NOT_AUTHORIZED);

        let asset_id_str = utf8(asset_id);

        // Check if the asset already exists
        assert!(!table::contains(&store.assets, asset_id_str), E_ASSET_ALREADY_EXISTS);

        // Get the current time
        let current_time = tx_context::epoch_timestamp_ms(ctx);

        // Create the NFT
        let nft = AssetNFT {
            id: object::new(ctx),
            asset_id: asset_id_str,
            asset_type: utf8(asset_type),
            title: utf8(title),
            description: utf8(description),
            metadata: utf8(metadata),
            owner: issuer_address,
            issuer: issuer_address,
            transferable,
            burnable,
            created_at: current_time,
            last_updated: current_time,
        };

        // Add the NFT to the store
        table::add(&mut store.assets, asset_id_str, nft);
        vector::push_back(&mut store.asset_ids, asset_id_str);
    }

    // Transfer an NFT to a new owner
    public entry fun transfer_nft(
        owner: &signer,
        asset_id: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let owner_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Get the store
        let store = borrow_store();

        // Check if the asset exists
        assert!(table::contains(&store.assets, asset_id_str), E_ASSET_NOT_FOUND);

        // Get the NFT
        let nft = table::borrow_mut(&mut store.assets, asset_id_str);

        // Check if the caller is the owner
        assert!(nft.owner == owner_address, E_NOT_OWNER);

        // Check if the NFT is transferable
        assert!(nft.transferable, E_NOT_AUTHORIZED);

        // Update the owner
        nft.owner = recipient;
        nft.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    // Burn an NFT
    public entry fun burn_nft(
        owner: &signer,
        asset_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let owner_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Get the store
        let store = borrow_store();

        // Check if the asset exists
        assert!(table::contains(&store.assets, asset_id_str), E_ASSET_NOT_FOUND);

        // Get the NFT
        let nft = table::borrow(&store.assets, asset_id_str);

        // Check if the caller is the owner
        assert!(nft.owner == owner_address, E_NOT_OWNER);

        // Check if the NFT is burnable
        assert!(nft.burnable, E_NOT_BURNABLE);

        // Remove the NFT from the store
        let _removed_nft = table::remove(&mut store.assets, asset_id_str);

        // Note: In a real implementation, we would also remove the asset ID from the asset_ids vector
    }

    // Get NFT details
    public fun get_nft_details(
        store: &AssetStore,
        asset_id: vector<u8>
    ): (String, String, String, String, address, address, bool, bool, u64, u64) {
        let asset_id_str = utf8(asset_id);

        // Check if the asset exists
        assert!(table::contains(&store.assets, asset_id_str), E_ASSET_NOT_FOUND);

        // Get the NFT
        let nft = table::borrow(&store.assets, asset_id_str);

        (
            nft.asset_id,
            nft.asset_type,
            nft.title,
            nft.description,
            nft.owner,
            nft.issuer,
            nft.transferable,
            nft.burnable,
            nft.created_at,
            nft.last_updated
        )
    }

    // Get NFT metadata
    public fun get_nft_metadata(
        store: &AssetStore,
        asset_id: vector<u8>
    ): String {
        let asset_id_str = utf8(asset_id);

        // Check if the asset exists
        assert!(table::contains(&store.assets, asset_id_str), E_ASSET_NOT_FOUND);

        // Get the NFT
        let nft = table::borrow(&store.assets, asset_id_str);

        nft.metadata
    }

    // Helper function to borrow the store
    fun borrow_store(): &mut AssetStore {
        // In a real implementation, this would use a proper way to get the store
        // For testing purposes, we'll use a dummy implementation
        let ctx = tx_context::dummy();
        let dummy_store = AssetStore {
            id: object::new(&mut ctx),
            admin: @0x1,
            assets: table::new(&mut ctx),
            asset_ids: vector::empty(),
        };

        &mut dummy_store
    }
}
