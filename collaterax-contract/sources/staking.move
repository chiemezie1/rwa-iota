module collaterax::staking {
<<<<<<< HEAD
    use std::signer;
    use std::vector::{self};
    use std::option::{self, Option};
    use std::string::{self, utf8};
    use iota::error;
    use iota::tx_context::{self, TxContext};
    use iota::object::{self, UID};
    use iota::table::{self, Table};
    use iota::coin;
    use iota::balance::{self, Balance};
    use iota::clock::{self, Clock};
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
    use collaterax::asset_ft::{Self, TokenRegistry};
>>>>>>> b361d09 (update)

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

<<<<<<< HEAD
    // Staking information per user
    public struct Stake has store, drop {
=======
    /// Represents a staking pool for a specific asset token
    public public struct StakingPool has key, store {
        /// Unique identifier for the pool
        id: UID,
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
    public public struct Stake has store, drop, drop {
        /// Amount of tokens staked
>>>>>>> b361d09 (update)
        amount: u64,
        staked_at: u64,
        last_reward_time: u64,
        pending_rewards: u64,
    }

<<<<<<< HEAD
    // Staking pool definition
    public struct StakingPool has store {
        id: UID,
        asset_id: String,
        apy_bps: u64,
        lock_period: u64,
        total_staked: u64,
        stakes: Table<address, Stake>,
    }

    // Registry store for all pools
    public struct RegistryStore has key {
        registry: Option<PoolRegistry>,
    }

    public struct PoolRegistry has store {
        id: UID,
        admin: address,
=======
    /// Global registry of all staking pools
    public public struct PoolRegistry has key {
        /// Table mapping asset IDs to their staking pools
>>>>>>> b361d09 (update)
        pools: Table<String, StakingPool>,
        pool_keys: vector<String>,
    }

    /// Initialize staking registry; one-time admin call
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_addr = signer::address_of(admin);
        assert!(!object::exists<RegistryStore>(admin_addr), error::already_exists(E_POOL_ALREADY_EXISTS));

        let registry = PoolRegistry {
            id: object::new(ctx),
            admin: admin_addr,
            pools: table::new(ctx),
            pool_keys: vector::empty(),
        };
        let store = RegistryStore { registry: option::some(registry) };
        object::publish_object(store);
    }

    /// Create a new staking pool
    public entry fun create_pool(
        admin: &signer,
        asset_id_b: vector<u8>,
        apy_bps: u64,
        lock_ms: u64,
        ctx: &mut TxContext
    ) {
        let admin_addr = signer::address_of(admin);
        let store_ref = object::borrow_global_mut<RegistryStore>(admin_addr);
        let reg = option::borrow_mut(&mut store_ref.registry);
        assert!(reg.admin == admin_addr, error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id = utf8(asset_id_b);
        assert!(!table::contains(&reg.pools, asset_id), error::already_exists(E_POOL_ALREADY_EXISTS));

        let pool = StakingPool {
            id: object::new(ctx),
            asset_id: asset_id.clone(),
            apy_bps,
            lock_period: lock_ms,
            total_staked: 0,
            stakes: table::new(ctx),
        };
        table::add(&mut reg.pools, asset_id.clone(), pool);
        vector::push_back(&mut reg.pool_keys, asset_id);
    }

    /// Stake coins into a pool
    public entry fun stake(
        staker: &signer,
        asset_id: String,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let staker_addr = signer::address_of(staker);
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
<<<<<<< HEAD

        let store_ref = object::borrow_global_mut<RegistryStore>(staker_addr);
        let reg = option::borrow_mut(&mut store_ref.registry);
        assert!(table::contains(&reg.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));

        let pool = table::borrow_mut(&mut reg.pools, asset_id.clone());
        // Transfer coins from user to pool (simulate lock)
        coin::withdraw<Balance>(staker_addr, amount, ctx);

        let now = clock::timestamp_ms(clock);
        if (table::contains(&pool.stakes, staker_addr)) {
            let s = table::borrow_mut(&mut pool.stakes, staker_addr);
            // Calculate and accumulate rewards before updating stake
            let elapsed = now - s.last_reward_time;
            s.pending_rewards = s.pending_rewards + calculate_rewards(s.amount, pool.apy_bps, elapsed);
            s.amount = s.amount + amount;
            s.last_reward_time = now;
=======
        
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
            let reward = (reward_rate / (10000u128 * (annual_ms as u128))) as u64; // Convert basis points to percentage
            
            stake.pending_rewards = stake.pending_rewards + reward;
            stake.amount = stake.amount + amount;
            stake.staked_at = current_time;
            stake.last_reward_time = current_time;
>>>>>>> b361d09 (update)
        } else {
            let stake_info = Stake { amount, staked_at: now, last_reward_time: now, pending_rewards: 0 };
            table::add(&mut pool.stakes, staker_addr, stake_info);
        }
        pool.total_staked = pool.total_staked + amount;
    }

    /// Unstake after lock period
    public entry fun unstake(
        staker: &signer,
        asset_id: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
<<<<<<< HEAD
        let staker_addr = signer::address_of(staker);
        let store_ref = object::borrow_global_mut<RegistryStore>(staker_addr);
        let reg = option::borrow_mut(&mut store_ref.registry);
        assert!(table::contains(&reg.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));

        let pool = table::borrow_mut(&mut reg.pools, asset_id.clone());
        let s = table::borrow_mut(&mut pool.stakes, staker_addr);
        let now = clock::timestamp_ms(clock);
        assert!(now >= s.staked_at + pool.lock_period, error::invalid_state(E_LOCK_PERIOD_NOT_ENDED));

        // Calculate final rewards
        let elapsed = now - s.last_reward_time;
        let total_rewards = s.pending_rewards + calculate_rewards(s.amount, pool.apy_bps, elapsed);
        let amount = s.amount;

        // Remove stake record
        table::remove(&mut pool.stakes, staker_addr);
=======
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
        let reward = (reward_rate / (10000u128 * (annual_ms as u128))) as u64; // Convert basis points to percentage
        
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
>>>>>>> b361d09 (update)
        pool.total_staked = pool.total_staked - amount;

        // Return principal and rewards
        coin::deposit<Balance>(staker_addr, amount + total_rewards, ctx);
    }

<<<<<<< HEAD
    /// View pool info
    public fun get_pool(asset_id: String): StakingPool {
        let caller = signer::borrow_signer();
        let addr = signer::address_of(&caller);
        let store_ref = object::borrow_global<RegistryStore>(addr);
        let reg = option::borrow(&store_ref.registry);
        assert!(table::contains(&reg.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));
        table::borrow(&reg.pools, asset_id)
=======
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
        let reward = (reward_rate / (10000u128 * (annual_ms as u128))) as u64; // Convert basis points to percentage
        
        let total_rewards = stake.pending_rewards + reward;
        
        // In a real implementation, this would transfer the rewards to the staker
        // For now, we just reset the pending rewards
        stake.pending_rewards = 0;
        stake.last_reward_time = current_time;
>>>>>>> b361d09 (update)
    }

    /// List all pools
    public fun list_pools(): vector<String> {
        let caller = signer::borrow_signer();
        let addr = signer::address_of(&caller);
        let store_ref = object::borrow_global<RegistryStore>(addr);
        let reg = option::borrow(&store_ref.registry);
        reg.pool_keys
    }

    /// Calculate staking rewards
    fun calculate_rewards(amount: u64, apy_bps: u64, elapsed_ms: u64): u64 {
        // annual rewards = amount * apy_bps / 10000
        // proportionally by elapsed_ms / (365 days)
        (amount * apy_bps * elapsed_ms) / (10000 * 365 * 24 * 3600 * 1000)
    }
}
