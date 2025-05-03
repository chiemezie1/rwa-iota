#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::asset_nft {
    use std::string::{String, utf8};
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::transfer;
    use collaterax::errors::{E_NOT_AUTHORIZED, E_ALREADY_EXISTS, E_NOT_FOUND, E_NOT_OWNER, E_NOT_BURNABLE};

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

    public struct AssetStore has key {
        id: UID,
        admin: address,
        assets: Table<String, AssetNFT>,
        asset_ids: vector<String>,
    }

    /// Initialize the NFT store (shared object)
    public entry fun init_store(_admin: &signer, ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        let store = AssetStore {
            id: object::new(ctx),
            admin: admin_address,
            assets: table::new(ctx),
            asset_ids: vector::empty(),
        };
        transfer::share_object(store);
    }

    /// Mint a new NFT (admin only)
    public entry fun mint_nft(
        _issuer: &signer,
        store: &mut AssetStore,
        asset_id: vector<u8>,
        asset_type: vector<u8>,
        title: vector<u8>,
        description: vector<u8>,
        metadata: vector<u8>,
        transferable: bool,
        burnable: bool,
        ctx: &mut TxContext
    ) acquires AssetStore {
        let issuer_address = tx_context::sender(ctx);
        // Only admin can mint
        assert!(store.admin == issuer_address, E_NOT_AUTHORIZED);

        let asset_id_str = utf8(asset_id);
        // Asset ID must be unique
        assert!(!table::contains(&store.assets, asset_id_str), E_ALREADY_EXISTS);

        let current_time = tx_context::epoch_timestamp_ms(ctx);
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

        table::add(&mut store.assets, nft.asset_id, nft);
        vector::push_back(&mut store.asset_ids, asset_id_str);
    }

    /// Transfer an NFT to a new owner
    public entry fun transfer_nft(
        _owner: &signer,
        store: &mut AssetStore,
        asset_id: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ) acquires AssetStore {
        let owner_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        assert!(table::contains(&store.assets, asset_id_str), E_NOT_FOUND);

        let nft = table::borrow_mut(&mut store.assets, asset_id_str);
        assert!(nft.owner == owner_address, E_NOT_OWNER);
        assert!(nft.transferable, E_NOT_AUTHORIZED);

        nft.owner = recipient;
        nft.last_updated = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Burn (destroy) an NFT
    public entry fun burn_nft(
        _owner: &signer,
        store: &mut AssetStore,
        asset_id: vector<u8>,
        ctx: &mut TxContext
    ) acquires AssetStore {
        let owner_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        assert!(table::contains(&store.assets, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let nft = table::borrow(&store.assets, asset_id_str);
        assert!(nft.owner == owner_address,
                error::permission_denied(E_NOT_OWNER));
        assert!(nft.burnable,
                error::invalid_state(E_NOT_BURNABLE));

        let _ = table::remove(&mut store.assets, asset_id_str);
        // (Optionally remove from asset_ids vector)
    }

    /// Get NFT details (read-only)
    public fun get_nft_details(
        store: &AssetStore,
        asset_id: vector<u8>
    ): (String, String, String, String, address, address, bool, bool, u64, u64) {
        let asset_id_str = utf8(asset_id);
        assert!(table::contains(&store.assets, asset_id_str),
                error::not_found(E_NOT_FOUND));
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

    /// Get NFT metadata (read-only)
    public fun get_nft_metadata(
        store: &AssetStore,
        asset_id: vector<u8>
    ): String {
        let asset_id_str = utf8(asset_id);
        assert!(table::contains(&store.assets, asset_id_str),
                error::not_found(E_NOT_FOUND));
        let nft = table::borrow(&store.assets, asset_id_str);
        nft.metadata
    }
}
