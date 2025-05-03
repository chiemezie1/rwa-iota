#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::staking {
    use std::string::{String, utf8};
    use std::error;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::clock::{Self, Clock};
    use iota::transfer;
    // Comment out these imports until we have the correct paths
    // use iota::coin::{Self, Coin};
    // use iota::balance::{Self, Balance};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

    // Stake struct
    public struct Stake has store, drop {
        amount: u64,
        staked_at: u64,
        last_reward_time: u64,
        pending_rewards: u64,
    }

    // Staking pool struct
    public struct StakingPool has key, store {
        id: UID,
        asset_id: String,
        apy_basis_points: u64, // APY in basis points (1% = 100 basis points)
        lock_period_ms: u64, // Lock period in milliseconds
        total_staked: u64,
        stakes: Table<address, Stake>,
        staker_addresses: vector<address>,
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
        let admin_address = tx_context::sender(ctx);

        let registry = PoolRegistry {
            id: object::new(ctx),
            admin: admin_address,
            pools: table::new(ctx),
            pool_asset_ids: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        transfer::share_object(registry);
    }

    // Create a new staking pool
    public entry fun create_pool(
        admin: &signer,
        asset_id: vector<u8>,
        apy_basis_points: u64,
        lock_period_ms: u64,
        ctx: &mut TxContext
    ) {
        let admin_address = tx_context::sender(ctx);

        // Get the registry
        let registry = borrow_registry();

        // Check if the caller is the admin
        assert!(admin_address == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id_str = utf8(asset_id);

        // Check if the pool already exists
        assert!(!table::contains(&registry.pools, asset_id_str), error::already_exists(E_POOL_ALREADY_EXISTS));

        // Create the staking pool
        let pool = StakingPool {
            id: object::new(ctx),
            asset_id: asset_id_str,
            apy_basis_points,
            lock_period_ms,
            total_staked: 0,
            stakes: table::new(ctx),
            staker_addresses: vector::empty(),
        };

        // Add the pool to the registry
        table::add(&mut registry.pools, asset_id_str, pool);
        vector::push_back(&mut registry.pool_asset_ids, asset_id_str);
    }

    // Stake tokens in a pool
    public entry fun stake(
        staker: &signer,
        asset_id: vector<u8>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));

        // Get the registry
        let registry = borrow_registry();

        // Check if the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));

        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Check if the staker already has a stake
        if (table::contains(&pool.stakes, staker_address)) {
            // Update existing stake
            let stake = table::borrow_mut(&mut pool.stakes, staker_address);

            // Calculate pending rewards before adding new stake
            let elapsed_ms = current_time - stake.last_reward_time;
            let rewards = calculate_rewards(stake.amount, pool.apy_basis_points, elapsed_ms);

            stake.pending_rewards = stake.pending_rewards + rewards;
            stake.amount = stake.amount + amount;
            stake.last_reward_time = current_time;
        } else {
            // Create new stake
            let stake = Stake {
                amount,
                staked_at: current_time,
                last_reward_time: current_time,
                pending_rewards: 0,
            };

            // Add the stake to the pool
            table::add(&mut pool.stakes, staker_address, stake);
            vector::push_back(&mut pool.staker_addresses, staker_address);
        };

        // Update total staked amount
        pool.total_staked = pool.total_staked + amount;

        // In a real implementation, this would transfer tokens from the staker to the pool
    }

    // Unstake tokens from a pool
    public entry fun unstake(
        staker: &signer,
        asset_id: vector<u8>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));

        // Get the registry
        let registry = borrow_registry();

        // Check if the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));

        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);

        // Check if the staker has a stake
        assert!(table::contains(&pool.stakes, staker_address), error::not_found(E_INSUFFICIENT_STAKE));

        // Get the stake
        let stake = table::borrow_mut(&mut pool.stakes, staker_address);

        // Check if the staker has enough staked
        assert!(stake.amount >= amount, error::invalid_argument(E_INSUFFICIENT_STAKE));

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Check if the lock period has ended
        assert!(current_time >= stake.staked_at + pool.lock_period_ms, error::invalid_state(E_LOCK_PERIOD_NOT_ENDED));

        // Calculate pending rewards
        let elapsed_ms = current_time - stake.last_reward_time;
        let rewards = calculate_rewards(stake.amount, pool.apy_basis_points, elapsed_ms);

        // Update stake
        stake.pending_rewards = stake.pending_rewards + rewards;
        stake.amount = stake.amount - amount;
        stake.last_reward_time = current_time;

        // Update total staked amount
        pool.total_staked = pool.total_staked - amount;

        // If the stake is now zero and there are no pending rewards, remove it
        if (stake.amount == 0 && stake.pending_rewards == 0) {
            table::remove(&mut pool.stakes, staker_address);

            // Remove the staker from the list
            let (found, index) = vector::index_of(&pool.staker_addresses, &staker_address);
            if (found) {
                vector::remove(&mut pool.staker_addresses, index);
            };
        };

        // In a real implementation, this would transfer tokens from the pool to the staker
    }

    // Claim rewards from a stake
    public entry fun claim_rewards(
        staker: &signer,
        asset_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Get the registry
        let registry = borrow_registry();

        // Check if the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));

        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);

        // Check if the staker has a stake
        assert!(table::contains(&pool.stakes, staker_address), error::not_found(E_INSUFFICIENT_STAKE));

        // Get the stake
        let stake = table::borrow_mut(&mut pool.stakes, staker_address);

        // Calculate pending rewards
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        let elapsed_ms = current_time - stake.last_reward_time;
        let rewards = calculate_rewards(stake.amount, pool.apy_basis_points, elapsed_ms);

        // Get total rewards
        let total_rewards = stake.pending_rewards + rewards;

        // Reset pending rewards and update last reward time
        stake.pending_rewards = 0;
        stake.last_reward_time = current_time;

        // In a real implementation, this would transfer the rewards to the staker
    }

    // Get pool details
    public fun get_pool_details(
        registry: &PoolRegistry,
        asset_id: vector<u8>
    ): (String, u64, u64, u64, u64) {
        let asset_id_str = utf8(asset_id);

        // Check if the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));

        // Get the pool
        let pool = table::borrow(&registry.pools, asset_id_str);

        (
            pool.asset_id,
            pool.apy_basis_points,
            pool.lock_period_ms,
            pool.total_staked,
            vector::length(&pool.staker_addresses)
        )
    }

    // Get stake details
    public fun get_stake_details(
        registry: &PoolRegistry,
        asset_id: vector<u8>,
        staker: address
    ): (u64, u64, u64, u64) {
        let asset_id_str = utf8(asset_id);

        // Check if the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));

        // Get the pool
        let pool = table::borrow(&registry.pools, asset_id_str);

        // Check if the staker has a stake
        assert!(table::contains(&pool.stakes, staker), error::not_found(E_INSUFFICIENT_STAKE));

        // Get the stake
        let stake = table::borrow(&pool.stakes, staker);

        (
            stake.amount,
            stake.staked_at,
            stake.last_reward_time,
            stake.pending_rewards
        )
    }

    // Calculate staking rewards
    fun calculate_rewards(amount: u64, apy_basis_points: u64, elapsed_ms: u64): u64 {
        // Convert to u128 to avoid overflow
        let amount_u128 = (amount as u128);
        let apy_basis_points_u128 = (apy_basis_points as u128);
        let elapsed_ms_u128 = (elapsed_ms as u128);

        // Annual rewards = amount * apy_basis_points / 10000
        // Proportional rewards = annual_rewards * elapsed_ms / (365 days in ms)
        let annual_ms: u128 = 365 * 24 * 60 * 60 * 1000; // milliseconds in a year

        let reward_rate = amount_u128 * apy_basis_points_u128 * elapsed_ms_u128;
        let reward = reward_rate / (10000u128 * annual_ms);

        (reward as u64)
    }

    // Helper function to borrow the registry
    fun borrow_registry(): &mut PoolRegistry {
        // In a real implementation, this would use a proper way to get the registry
        // For testing purposes, we'll use a dummy implementation
        let ctx = tx_context::dummy();
        let dummy_registry = PoolRegistry {
            id: object::new(&mut ctx),
            admin: @0x1,
            pools: table::new(&mut ctx),
            pool_asset_ids: vector::empty(),
        };

        &mut dummy_registry
    }
}
