module collaterax::asset_nft {
<<<<<<< HEAD
    use std::signer;
    use std::vector::{self};
    use std::option::{self, Option};
    use std::string::{self, String, utf8};
    use iota::error;
    use iota::tx_context::{self, TxContext};
    use iota::object::{self, UID};
    use iota::table::{self, Table};
=======
    use std::string;
use std::error;
use std::signer;;
use std::error;
use std::signer;::{String, utf8};
    use std::vector;
    use std::error;
    use std::signer;
    use iota::object::{Self, UID, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use collaterax::spv_registry::{Self, SPVRegistry};
>>>>>>> b361d09 (update)

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ASSET_ALREADY_EXISTS: u64 = 2;
    const E_ASSET_NOT_FOUND: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_STORE_ALREADY_EXISTS: u64 = 5;
    const E_NOT_BURNABLE: u64 = 6;
    const E_INVALID_METADATA: u64 = 7;

<<<<<<< HEAD
    // Asset NFT definition
    public struct AssetNFT has store {
        id: UID,
=======
    /// Represents a unique real-world asset as an NFT
    public public struct AssetNFT has key, store {
        /// Unique identifier for the asset
        id: UID,
        /// Asset identifier (e.g., property address, deed number)
>>>>>>> b361d09 (update)
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

<<<<<<< HEAD
    // Registry storage for NFTs
    public struct RegistryStore has key {
        registry: Option<AssetStore>,
    }

    public struct AssetStore has store {
        id: UID,
        admin: address,
=======
    /// Global store for all asset NFTs
    public public struct AssetStore has key {
        /// Table mapping asset IDs to their NFTs
>>>>>>> b361d09 (update)
        assets: Table<String, AssetNFT>,
        asset_keys: vector<String>,
    }

    /// Initialize the NFT store; only once
    public entry fun init_store(admin: &signer, ctx: &mut TxContext) {
        let admin_addr = signer::address_of(admin);
        assert!(!object::exists<RegistryStore>(admin_addr), error::already_exists(E_STORE_ALREADY_EXISTS));

        let store = AssetStore {
            id: object::new(ctx),
            admin: admin_addr,
            assets: table::new(ctx),
            asset_keys: vector::empty(),
        };
        let registry = RegistryStore { registry: option::some(store) };
        object::publish_object(registry);
    }

    /// Mint a new NFT
    public entry fun mint_nft(
        issuer: &signer,
        asset_id_b: vector<u8>,
        asset_type_b: vector<u8>,
        title_b: vector<u8>,
        desc_b: vector<u8>,
        metadata_b: vector<u8>,
        transferable: bool,
        burnable: bool,
        ctx: &mut TxContext
    ) {
        let issuer_addr = signer::address_of(issuer);
        let store_ref = object::borrow_global_mut<RegistryStore>(issuer_addr);
        let store = option::borrow_mut(&mut store_ref.registry);
        assert!(store.admin == issuer_addr, error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id = utf8(asset_id_b);
        assert!(!table::contains(&store.assets, asset_id), error::already_exists(E_ASSET_ALREADY_EXISTS));

        let now = tx_context::epoch_timestamp_ms(ctx);
        let nft = AssetNFT {
            id: object::new(ctx),
            asset_id: asset_id.clone(),
            asset_type: utf8(asset_type_b),
            title: utf8(title_b),
            description: utf8(desc_b),
            metadata: utf8(metadata_b),
            owner: issuer_addr,
            issuer: issuer_addr,
            transferable,
            burnable,
            created_at: now,
            last_updated: now,
        };
        table::add(&mut store.assets, asset_id.clone(), nft);
        vector::push_back(&mut store.asset_keys, asset_id);
    }

    /// Transfer NFT to a new owner
    public entry fun transfer_nft(
        sender: &signer,
        asset_id: String,
        recipient: address
    ) {
        let sender_addr = signer::address_of(sender);
        let store_ref = object::borrow_global_mut<RegistryStore>(sender_addr);
        let store = option::borrow_mut(&mut store_ref.registry);
        assert!(table::contains(&store.assets, asset_id), error::not_found(E_ASSET_NOT_FOUND));

        let nft_ref = table::borrow_mut(&mut store.assets, asset_id.clone());
        assert!(nft_ref.owner == sender_addr, error::permission_denied(E_NOT_OWNER));
        assert!(nft_ref.transferable, error::invalid_state(E_NOT_AUTHORIZED));

        nft_ref.owner = recipient;
        nft_ref.last_updated = tx_context::epoch_timestamp_ms(&mut TxContext::new());
    }

    /// Burn an NFT if allowed
    public entry fun burn_nft(
        owner: &signer,
        asset_id: String
    ) {
        let owner_addr = signer::address_of(owner);
        let store_ref = object::borrow_global_mut<RegistryStore>(owner_addr);
        let store = option::borrow_mut(&mut store_ref.registry);
        assert!(table::contains(&store.assets, asset_id), error::not_found(E_ASSET_NOT_FOUND));

        let nft_ref = table::borrow(&store.assets, asset_id.clone());
        assert!(nft_ref.owner == owner_addr, error::permission_denied(E_NOT_OWNER));
        assert!(nft_ref.burnable, error::invalid_state(E_NOT_BURNABLE));

        table::remove(&mut store.assets, asset_id.clone());
        // Optionally remove key from asset_keys vector
    }

    /// Get NFT metadata
    public fun get_nft(asset_id: String): AssetNFT {
        let viewer = signer::borrow_signer();
        let viewer_addr = signer::address_of(&viewer);
        let store_ref = object::borrow_global<RegistryStore>(viewer_addr);
        let store = option::borrow(&store_ref.registry);
        assert!(table::contains(&store.assets, asset_id), error::not_found(E_ASSET_NOT_FOUND));
        table::borrow(&store.assets, asset_id)
    }

    /// List all NFT IDs
    public fun list_nfts(): vector<String> {
        let viewer = signer::borrow_signer();
        let viewer_addr = signer::address_of(&viewer);
        let store_ref = object::borrow_global<RegistryStore>(viewer_addr);
        let store = option::borrow(&store_ref.registry);
        store.asset_keys
    }
}
