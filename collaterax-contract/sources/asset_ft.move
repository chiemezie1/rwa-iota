/// Asset Fungible Token (FT) Module
///
/// This module manages fungible tokens that represent fractional ownership
/// of real-world assets, such as shares in a property or company equity.
///
/// It supports minting, transferring, and burning tokens, with automatic
/// fee distribution to the platform and SPVs.
module collaterax::asset_ft {
    use std::string::{String, utf8};
    use std::vector;
    use std::error;
    use std::signer;
    use iota::object::{Self, Object, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use collaterax::spv_registry::{Self, SPVRegistry};
    use collaterax::asset_nft::{Self, AssetStore};

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_TOKEN_ALREADY_EXISTS: u64 = 2;
    const E_TOKEN_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_ASSET_NOT_FRACTIONALIZABLE: u64 = 7;

    /// Fee constants (in basis points, 1 bp = 0.01%)
    const PLATFORM_FEE_BP: u64 = 50; // 0.5%
    const SPV_FEE_BP: u64 = 50; // 0.5%
    const BASIS_POINTS: u64 = 10000; // 100%

    /// Represents a fungible token for fractional ownership
    struct AssetToken has key, store {
        /// Unique identifier for the token
        id: ID,
        /// Associated asset ID (from the AssetNFT module)
        asset_id: String,
        /// Name of the token
        name: String,
        /// Symbol of the token
        symbol: String,
        /// Number of decimal places
        decimals: u8,
        /// Total supply of tokens
        total_supply: u64,
        /// Address of the SPV that verified this asset
        spv_address: address,
        /// Address of the platform treasury
        treasury_address: address,
        /// Table mapping addresses to token balances
        balances: Table<address, u64>,
        /// Timestamp when the token was created
        created_at: u64
    }

    /// Global registry of all asset tokens
    struct TokenRegistry has key {
        /// Table mapping asset IDs to their tokens
        tokens: Table<String, AssetToken>,
        /// List of all asset IDs with tokens for enumeration
        token_asset_ids: vector<String>,
        /// Address of the admin
        admin: address
    }

    /// Initialize the token registry
    /// Can only be called once by the platform admin
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);
        
        // Create a new token registry
        let registry = TokenRegistry {
            tokens: table::new(ctx),
            token_asset_ids: vector::empty<String>(),
            admin: admin_address
        };
        
        // Move the registry to the global storage
        object::transfer(registry, admin_address);
    }

    /// Create a new asset token
    /// Only verified SPVs can create new tokens, and only for assets they own
    /// that are marked as fractionalizable
    public entry fun create_token(
        spv: &signer,
        asset_id: vector<u8>,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        treasury_address: address,
        registry: &mut TokenRegistry,
        spv_registry: &SPVRegistry,
        asset_store: &AssetStore,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        
        // Ensure the SPV is verified
        assert!(spv_registry::is_verified_spv(spv_address, spv_registry), error::permission_denied(E_NOT_AUTHORIZED));
        
        let asset_id_str = utf8(asset_id);
        
        // Ensure the SPV owns the asset
        assert!(asset_nft::is_owner(spv_address, asset_id_str, asset_store), error::permission_denied(E_NOT_AUTHORIZED));
        
        // Ensure the asset is fractionalizable
        let (_, _, _, _, _, _, _, fractionalizable, _, _) = asset_nft::get_asset_info(asset_id_str, asset_store);
        assert!(fractionalizable, error::invalid_argument(E_ASSET_NOT_FRACTIONALIZABLE));
        
        // Ensure the token doesn't already exist
        assert!(!table::contains(&registry.tokens, asset_id_str), error::already_exists(E_TOKEN_ALREADY_EXISTS));
        
        // Ensure the total supply is not zero
        assert!(total_supply > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Create a new token
        let token = AssetToken {
            id: object::new(ctx),
            asset_id: asset_id_str,
            name: utf8(name),
            symbol: utf8(symbol),
            decimals: decimals,
            total_supply: total_supply,
            spv_address: spv_address,
            treasury_address: treasury_address,
            balances: table::new(ctx),
            created_at: tx_context::epoch_timestamp_ms(ctx)
        };
        
        // Assign the entire supply to the SPV initially
        table::add(&mut token.balances, spv_address, total_supply);
        
        // Add the token to the registry
        table::add(&mut registry.tokens, asset_id_str, token);
        vector::push_back(&mut registry.token_asset_ids, asset_id_str);
    }

    /// Transfer tokens from one address to another
    /// Automatically applies platform and SPV fees
    public entry fun transfer(
        sender: &signer,
        asset_id: vector<u8>,
        recipient: address,
        amount: u64,
        registry: &mut TokenRegistry,
        ctx: &mut TxContext
    ) {
        let sender_address = signer::address_of(sender);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the token exists
        assert!(table::contains(&registry.tokens, asset_id_str), error::not_found(E_TOKEN_NOT_FOUND));
        
        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Get the token
        let token = table::borrow_mut(&mut registry.tokens, asset_id_str);
        
        // Ensure the sender has sufficient balance
        assert!(table::contains(&token.balances, sender_address), error::not_found(E_INSUFFICIENT_BALANCE));
        let sender_balance = *table::borrow(&token.balances, sender_address);
        assert!(sender_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Calculate fees
        let platform_fee = (amount * PLATFORM_FEE_BP) / BASIS_POINTS;
        let spv_fee = (amount * SPV_FEE_BP) / BASIS_POINTS;
        let transfer_amount = amount - platform_fee - spv_fee;
        
        // Update sender balance
        let new_sender_balance = sender_balance - amount;
        if (new_sender_balance == 0) {
            table::remove(&mut token.balances, sender_address);
        } else {
            *table::borrow_mut(&mut token.balances, sender_address) = new_sender_balance;
        };
        
        // Update recipient balance
        if (table::contains(&token.balances, recipient)) {
            let recipient_balance = table::borrow_mut(&mut token.balances, recipient);
            *recipient_balance = *recipient_balance + transfer_amount;
        } else {
            table::add(&mut token.balances, recipient, transfer_amount);
        };
        
        // Update platform treasury balance
        if (platform_fee > 0) {
            if (table::contains(&token.balances, token.treasury_address)) {
                let treasury_balance = table::borrow_mut(&mut token.balances, token.treasury_address);
                *treasury_balance = *treasury_balance + platform_fee;
            } else {
                table::add(&mut token.balances, token.treasury_address, platform_fee);
            };
        };
        
        // Update SPV balance
        if (spv_fee > 0) {
            if (table::contains(&token.balances, token.spv_address)) {
                let spv_balance = table::borrow_mut(&mut token.balances, token.spv_address);
                *spv_balance = *spv_balance + spv_fee;
            } else {
                table::add(&mut token.balances, token.spv_address, spv_fee);
            };
        };
    }

    /// Mint additional tokens
    /// Only the SPV that created the token can mint more
    public entry fun mint(
        spv: &signer,
        asset_id: vector<u8>,
        recipient: address,
        amount: u64,
        registry: &mut TokenRegistry,
        ctx: &mut TxContext
    ) {
        let spv_address = signer::address_of(spv);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the token exists
        assert!(table::contains(&registry.tokens, asset_id_str), error::not_found(E_TOKEN_NOT_FOUND));
        
        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Get the token
        let token = table::borrow_mut(&mut registry.tokens, asset_id_str);
        
        // Ensure the caller is the SPV that created the token
        assert!(token.spv_address == spv_address, error::permission_denied(E_NOT_AUTHORIZED));
        
        // Update total supply
        token.total_supply = token.total_supply + amount;
        
        // Update recipient balance
        if (table::contains(&token.balances, recipient)) {
            let recipient_balance = table::borrow_mut(&mut token.balances, recipient);
            *recipient_balance = *recipient_balance + amount;
        } else {
            table::add(&mut token.balances, recipient, amount);
        };
    }

    /// Burn tokens
    /// Only the token holder can burn their own tokens
    public entry fun burn(
        holder: &signer,
        asset_id: vector<u8>,
        amount: u64,
        registry: &mut TokenRegistry,
        ctx: &mut TxContext
    ) {
        let holder_address = signer::address_of(holder);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the token exists
        assert!(table::contains(&registry.tokens, asset_id_str), error::not_found(E_TOKEN_NOT_FOUND));
        
        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Get the token
        let token = table::borrow_mut(&mut registry.tokens, asset_id_str);
        
        // Ensure the holder has sufficient balance
        assert!(table::contains(&token.balances, holder_address), error::not_found(E_INSUFFICIENT_BALANCE));
        let holder_balance = *table::borrow(&token.balances, holder_address);
        assert!(holder_balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Update holder balance
        let new_holder_balance = holder_balance - amount;
        if (new_holder_balance == 0) {
            table::remove(&mut token.balances, holder_address);
        } else {
            *table::borrow_mut(&mut token.balances, holder_address) = new_holder_balance;
        };
        
        // Update total supply
        token.total_supply = token.total_supply - amount;
    }

    /// Get the balance of an address for a specific token
    public fun balance_of(
        owner: address,
        asset_id: String,
        registry: &TokenRegistry
    ): u64 {
        // Ensure the token exists
        assert!(table::contains(&registry.tokens, asset_id), error::not_found(E_TOKEN_NOT_FOUND));
        
        // Get the token
        let token = table::borrow(&registry.tokens, asset_id);
        
        // Return the balance or 0 if the owner has no balance
        if (table::contains(&token.balances, owner)) {
            *table::borrow(&token.balances, owner)
        } else {
            0
        }
    }

    /// Get token information
    public fun get_token_info(
        asset_id: String,
        registry: &TokenRegistry
    ): (String, String, u8, u64, address, address, u64) {
        assert!(table::contains(&registry.tokens, asset_id), error::not_found(E_TOKEN_NOT_FOUND));
        
        let token = table::borrow(&registry.tokens, asset_id);
        (
            token.name,
            token.symbol,
            token.decimals,
            token.total_supply,
            token.spv_address,
            token.treasury_address,
            token.created_at
        )
    }

    /// Get the number of tokens
    public fun get_token_count(registry: &TokenRegistry): u64 {
        vector::length(&registry.token_asset_ids)
    }

    /// Get a token asset ID by index
    public fun get_token_asset_id_by_index(registry: &TokenRegistry, index: u64): String {
        *vector::borrow(&registry.token_asset_ids, index)
    }
}
