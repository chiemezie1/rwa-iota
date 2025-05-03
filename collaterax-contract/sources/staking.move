/// Staking Module
///
/// This module allows token holders to stake their tokens and earn rewards.
/// Staking increases platform engagement and provides a passive income stream
/// for long-term token holders.
module collaterax::staking {
    use std::string::{String, utf8};
    use std::vector;
    use std::error;
    use std::signer;
    use iota::object::{Self, Object, ID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use collaterax::asset_ft::{Self, TokenRegistry};

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

    /// Represents a staking pool for a specific asset token
    struct StakingPool has key, store {
        /// Unique identifier for the pool
        id: ID,
        /// Asset ID of the token being staked
        asset_id: String,
        /// Total amount of tokens staked in the pool
        total_staked: u64,
        /// Annual percentage yield (APY) in basis points (1 bp = 0.01%)
        apy_basis_points: u64,
        /// Lock period in milliseconds
        lock_period_ms: u64,
        /// Table mapping addresses to their stake information
        stakes: Table<address, Stake>,
        /// List of staker addresses for enumeration
        staker_addresses: vector<address>,
        /// Address of the reward distributor
        reward_distributor: address,
        /// Timestamp when the pool was created
        created_at: u64
    }

    /// Represents a stake by an individual
    struct Stake has store {
        /// Amount of tokens staked
        amount: u64,
        /// Timestamp when the stake was created or last updated
        staked_at: u64,
        /// Timestamp when rewards were last claimed
        last_reward_time: u64,
        /// Accumulated rewards that haven't been claimed yet
        pending_rewards: u64
    }

    /// Global registry of all staking pools
    struct PoolRegistry has key {
        /// Table mapping asset IDs to their staking pools
        pools: Table<String, StakingPool>,
        /// List of all asset IDs with pools for enumeration
        pool_asset_ids: vector<String>,
        /// Address of the admin
        admin: address
    }

    /// Initialize the pool registry
    /// Can only be called once by the platform admin
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);
        
        // Create a new pool registry
        let registry = PoolRegistry {
            pools: table::new(ctx),
            pool_asset_ids: vector::empty<String>(),
            admin: admin_address
        };
        
        // Move the registry to the global storage
        object::transfer(registry, admin_address);
    }

    /// Create a new staking pool
    /// Only the admin can create staking pools
    public entry fun create_pool(
        admin: &signer,
        asset_id: vector<u8>,
        apy_basis_points: u64,
        lock_period_ms: u64,
        reward_distributor: address,
        registry: &mut PoolRegistry,
        ctx: &mut TxContext
    ) {
        let admin_address = signer::address_of(admin);
        
        // Ensure the caller is the admin
        assert!(admin_address == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        let asset_id_str = utf8(asset_id);
        
        // Ensure the pool doesn't already exist
        assert!(!table::contains(&registry.pools, asset_id_str), error::already_exists(E_POOL_ALREADY_EXISTS));
        
        // Create a new staking pool
        let pool = StakingPool {
            id: object::new(ctx),
            asset_id: asset_id_str,
            total_staked: 0,
            apy_basis_points: apy_basis_points,
            lock_period_ms: lock_period_ms,
            stakes: table::new(ctx),
            staker_addresses: vector::empty<address>(),
            reward_distributor: reward_distributor,
            created_at: tx_context::epoch_timestamp_ms(ctx)
        };
        
        // Add the pool to the registry
        table::add(&mut registry.pools, asset_id_str, pool);
        vector::push_back(&mut registry.pool_asset_ids, asset_id_str);
    }

    /// Stake tokens in a pool
    public entry fun stake(
        staker: &signer,
        asset_id: vector<u8>,
        amount: u64,
        registry: &mut PoolRegistry,
        token_registry: &TokenRegistry,
        ctx: &mut TxContext
    ) {
        let staker_address = signer::address_of(staker);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));
        
        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Ensure the staker has enough tokens
        let balance = asset_ft::balance_of(staker_address, asset_id_str, token_registry);
        assert!(balance >= amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        
        // If the staker already has a stake, update it and calculate pending rewards
        if (table::contains(&pool.stakes, staker_address)) {
            let stake = table::borrow_mut(&mut pool.stakes, staker_address);
            
            // Calculate pending rewards before adding new stake
            let stake_duration_ms = current_time - stake.last_reward_time;
            let annual_ms: u64 = 365 * 24 * 60 * 60 * 1000; // milliseconds in a year
            let reward_rate = (pool.apy_basis_points as u128) * (stake.amount as u128) * (stake_duration_ms as u128);
            let reward = (reward_rate / (10000 * annual_ms)) as u64; // Convert basis points to percentage
            
            stake.pending_rewards = stake.pending_rewards + reward;
            stake.amount = stake.amount + amount;
            stake.staked_at = current_time;
            stake.last_reward_time = current_time;
        } else {
            // Create a new stake
            let stake = Stake {
                amount: amount,
                staked_at: current_time,
                last_reward_time: current_time,
                pending_rewards: 0
            };
            
            table::add(&mut pool.stakes, staker_address, stake);
            vector::push_back(&mut pool.staker_addresses, staker_address);
        };
        
        // Update total staked amount
        pool.total_staked = pool.total_staked + amount;
    }

    /// Unstake tokens from a pool
    public entry fun unstake(
        staker: &signer,
        asset_id: vector<u8>,
        amount: u64,
        registry: &mut PoolRegistry,
        ctx: &mut TxContext
    ) {
        let staker_address = signer::address_of(staker);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));
        
        // Ensure the amount is not zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        
        // Ensure the staker has a stake
        assert!(table::contains(&pool.stakes, staker_address), error::not_found(E_INSUFFICIENT_STAKE));
        
        let stake = table::borrow_mut(&mut pool.stakes, staker_address);
        
        // Ensure the staker has enough staked
        assert!(stake.amount >= amount, error::invalid_argument(E_INSUFFICIENT_STAKE));
        
        // Ensure the lock period has ended
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        assert!(current_time >= stake.staked_at + pool.lock_period_ms, error::invalid_state(E_LOCK_PERIOD_NOT_ENDED));
        
        // Calculate pending rewards before unstaking
        let stake_duration_ms = current_time - stake.last_reward_time;
        let annual_ms: u64 = 365 * 24 * 60 * 60 * 1000; // milliseconds in a year
        let reward_rate = (pool.apy_basis_points as u128) * (stake.amount as u128) * (stake_duration_ms as u128);
        let reward = (reward_rate / (10000 * annual_ms)) as u64; // Convert basis points to percentage
        
        stake.pending_rewards = stake.pending_rewards + reward;
        stake.amount = stake.amount - amount;
        stake.last_reward_time = current_time;
        
        // If the stake is now zero, remove it
        if (stake.amount == 0 && stake.pending_rewards == 0) {
            table::remove(&mut pool.stakes, staker_address);
            
            // Remove the staker from the list
            let (found, index) = vector::index_of(&pool.staker_addresses, &staker_address);
            if (found) {
                vector::remove(&mut pool.staker_addresses, index);
            };
        };
        
        // Update total staked amount
        pool.total_staked = pool.total_staked - amount;
    }

    /// Claim rewards from a stake
    public entry fun claim_rewards(
        staker: &signer,
        asset_id: vector<u8>,
        registry: &mut PoolRegistry,
        ctx: &mut TxContext
    ) {
        let staker_address = signer::address_of(staker);
        let asset_id_str = utf8(asset_id);
        
        // Ensure the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));
        
        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        
        // Ensure the staker has a stake
        assert!(table::contains(&pool.stakes, staker_address), error::not_found(E_INSUFFICIENT_STAKE));
        
        let stake = table::borrow_mut(&mut pool.stakes, staker_address);
        
        // Calculate pending rewards
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        let stake_duration_ms = current_time - stake.last_reward_time;
        let annual_ms: u64 = 365 * 24 * 60 * 60 * 1000; // milliseconds in a year
        let reward_rate = (pool.apy_basis_points as u128) * (stake.amount as u128) * (stake_duration_ms as u128);
        let reward = (reward_rate / (10000 * annual_ms)) as u64; // Convert basis points to percentage
        
        let total_rewards = stake.pending_rewards + reward;
        
        // In a real implementation, this would transfer the rewards to the staker
        // For now, we just reset the pending rewards
        stake.pending_rewards = 0;
        stake.last_reward_time = current_time;
    }

    /// Update the APY of a staking pool
    /// Only the admin can update the APY
    public entry fun update_apy(
        admin: &signer,
        asset_id: vector<u8>,
        new_apy_basis_points: u64,
        registry: &mut PoolRegistry,
        ctx: &mut TxContext
    ) {
        let admin_address = signer::address_of(admin);
        
        // Ensure the caller is the admin
        assert!(admin_address == registry.admin, error::permission_denied(E_NOT_AUTHORIZED));
        
        let asset_id_str = utf8(asset_id);
        
        // Ensure the pool exists
        assert!(table::contains(&registry.pools, asset_id_str), error::not_found(E_POOL_NOT_FOUND));
        
        // Get the pool
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        
        // Update the APY
        pool.apy_basis_points = new_apy_basis_points;
    }

    /// Get staking pool information
    public fun get_pool_info(
        asset_id: String,
        registry: &PoolRegistry
    ): (u64, u64, u64, address, u64, u64) {
        assert!(table::contains(&registry.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));
        
        let pool = table::borrow(&registry.pools, asset_id);
        (
            pool.total_staked,
            pool.apy_basis_points,
            pool.lock_period_ms,
            pool.reward_distributor,
            vector::length(&pool.staker_addresses),
            pool.created_at
        )
    }

    /// Get stake information for a specific staker
    public fun get_stake_info(
        staker: address,
        asset_id: String,
        registry: &PoolRegistry
    ): (u64, u64, u64, u64) {
        assert!(table::contains(&registry.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));
        
        let pool = table::borrow(&registry.pools, asset_id);
        assert!(table::contains(&pool.stakes, staker), error::not_found(E_INSUFFICIENT_STAKE));
        
        let stake = table::borrow(&pool.stakes, staker);
        (
            stake.amount,
            stake.staked_at,
            stake.last_reward_time,
            stake.pending_rewards
        )
    }

    /// Get the number of staking pools
    public fun get_pool_count(registry: &PoolRegistry): u64 {
        vector::length(&registry.pool_asset_ids)
    }

    /// Get a pool asset ID by index
    public fun get_pool_asset_id_by_index(registry: &PoolRegistry, index: u64): String {
        *vector::borrow(&registry.pool_asset_ids, index)
    }
}
