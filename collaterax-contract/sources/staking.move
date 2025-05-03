#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::staking {
    use std::string::{String, utf8};
    use std::error;
    use std::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::coin::{Self, Coin};
    use iota::balance::{Self, Balance};
    use iota::clock::{Self, Clock};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

    // Staking pool struct
    public struct StakingPool has store {
        asset_id: String,
        apy_basis_points: u64, // APY in basis points (1% = 100 basis points)
        lock_period_ms: u64, // Lock period in milliseconds
        total_staked: u64,
        stakes: Table<address, Stake>,
    }

    // Stake struct
    public struct Stake has store, drop {
        amount: u64,
        staked_at: u64,
        last_reward_time: u64,
        pending_rewards: u64,
    }

    // Registry to store all staking pools
    public struct PoolRegistry has key {
        id: UID,
        admin: address,
        pools: Table<String, StakingPool>,
        pool_asset_ids: vector<String>,
    }

    // Initialize the staking registry
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);

        let registry = PoolRegistry {
            id: object::new(ctx),
            admin: admin_address,
            pools: table::new(ctx),
            pool_asset_ids: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        object::share_object(registry);
    }

    // Create a new staking pool
    public entry fun create_pool(
        admin: &signer,
        asset_id: vector<u8>,
        apy_basis_points: u64,
        lock_period_ms: u64,
        ctx: &mut TxContext
    ) {
        let admin_address = signer::address_of(admin);

        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(admin_address == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id_str = utf8(asset_id);

        // Check if the pool already exists
        assert!(!table::contains(&registry.pools, asset_id_str), error::already_exists(E_POOL_ALREADY_EXISTS));

        // Create the staking pool
        let pool = StakingPool {
            asset_id: asset_id_str,
            apy_basis_points,
            lock_period_ms,
            total_staked: 0,
            stakes: table::new(ctx),
        };

        // Add the pool to the registry
        table::add(&mut registry.pools, asset_id_str, pool);
        vector::push_back(&mut registry.pool_asset_ids, asset_id_str);
    }

    // Helper function to borrow the registry
    fun borrow_registry(): &mut PoolRegistry {
        // In a real implementation, this would use a proper way to get the registry
        // For testing purposes, we'll use a dummy implementation
        let dummy_registry = PoolRegistry {
            id: object::new_for_testing(),
            admin: @0x1,
            pools: table::new_for_testing(),
            pool_asset_ids: vector::empty(),
        };

        &mut dummy_registry
    }
}
