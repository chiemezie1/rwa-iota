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
    use collaterax::errors::{E_NOT_AUTHORIZED, E_ALREADY_EXISTS, E_NOT_FOUND, E_INSUFFICIENT_STAKE, E_ZERO_AMOUNT, E_LOCK_PERIOD_NOT_ENDED};

    /// Stake information for a single user
    public struct Stake has store, drop {
        amount: u64,
        staked_at: u64,
        last_reward_time: u64,
        pending_rewards: u64,
    }

    /// Staking pool with APY and lock period
    public struct StakingPool has key, store {
        id: UID,
        asset_id: String,
        apy_basis_points: u64, // APY in basis points (1% = 100 basis points)
        lock_period_ms: u64,    // Lock period in milliseconds
        total_staked: u64,
        stakes: Table<address, Stake>,
        staker_addresses: vector<address>,
    }

    /// Registry of all staking pools
    public struct PoolRegistry has key {
        id: UID,
        admin: address,
        pools: Table<String, StakingPool>,
        pool_asset_ids: vector<String>,
    }

    /// Initialize the staking registry (shared object)
    public entry fun init_registry(_admin: &signer, ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        let registry = PoolRegistry {
            id: object::new(ctx),
            admin: admin_address,
            pools: table::new(ctx),
            pool_asset_ids: vector::empty(),
        };
        // Share the registry globally
        transfer::share_object(registry);
    }

    /// Create a new staking pool (only admin can call)
    public entry fun create_pool(
        _admin: &signer,
        registry: &mut PoolRegistry,
        asset_id: vector<u8>,
        apy_basis_points: u64,
        lock_period_ms: u64,
        ctx: &mut TxContext
    ) acquires PoolRegistry {
        let admin_address = tx_context::sender(ctx);
        // Check admin
        assert!(admin_address == registry.admin,
                error::permission_denied(E_NOT_AUTHORIZED));

        let asset_id_str = utf8(asset_id);
        // Ensure pool does not already exist
        assert!(!table::contains(&registry.pools, asset_id_str),
                error::already_exists(E_ALREADY_EXISTS));

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

        // Add to registry
        table::add(&mut registry.pools, pool.asset_id, pool);
        vector::push_back(&mut registry.pool_asset_ids, asset_id_str);
    }

    /// Stake tokens in a pool
    public entry fun stake(
        _staker: &signer,
        registry: &mut PoolRegistry,
        asset_id: vector<u8>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires PoolRegistry {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Amount must be non-zero
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        // Pool must exist
        assert!(table::contains(&registry.pools, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        let current_time = clock::timestamp_ms(clock);

        if (table::contains(&pool.stakes, staker_address)) {
            // Update existing stake
            let stake_ref = table::borrow_mut(&mut pool.stakes, staker_address);
            let elapsed_ms = current_time - stake_ref.last_reward_time;
            let rewards = calculate_rewards(stake_ref.amount, pool.apy_basis_points, elapsed_ms);

            stake_ref.pending_rewards = stake_ref.pending_rewards + rewards;
            stake_ref.amount = stake_ref.amount + amount;
            stake_ref.last_reward_time = current_time;
        } else {
            // New stake
            let stake_obj = Stake {
                amount,
                staked_at: current_time,
                last_reward_time: current_time,
                pending_rewards: 0,
            };
            table::add(&mut pool.stakes, staker_address, stake_obj);
            vector::push_back(&mut pool.staker_addresses, staker_address);
        };

        pool.total_staked = pool.total_staked + amount;
    }

    /// Unstake tokens from a pool (after lock period)
    public entry fun unstake(
        _staker: &signer,
        registry: &mut PoolRegistry,
        asset_id: vector<u8>,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires PoolRegistry {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Validate amount
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        // Pool must exist
        assert!(table::contains(&registry.pools, asset_id_str),
                error::not_found(E_NOT_FOUND));

        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);
        // Stake must exist
        assert!(table::contains(&pool.stakes, staker_address),
                error::not_found(E_INSUFFICIENT_STAKE));

        let stake_ref = table::borrow_mut(&mut pool.stakes, staker_address);
        // Must have enough staked
        assert!(stake_ref.amount >= amount,
                error::invalid_argument(E_INSUFFICIENT_STAKE));

        let current_time = clock::timestamp_ms(clock);
        // Ensure lock period ended
        assert!(current_time >= stake_ref.staked_at + pool.lock_period_ms,
                error::invalid_state(E_LOCK_PERIOD_NOT_ENDED));

        let elapsed_ms = current_time - stake_ref.last_reward_time;
        let rewards = calculate_rewards(stake_ref.amount, pool.apy_basis_points, elapsed_ms);

        stake_ref.pending_rewards = stake_ref.pending_rewards + rewards;
        stake_ref.amount = stake_ref.amount - amount;
        stake_ref.last_reward_time = current_time;
        pool.total_staked = pool.total_staked - amount;

        // Remove stake if now zero
        if (stake_ref.amount == 0 && stake_ref.pending_rewards == 0) {
            table::remove(&mut pool.stakes, staker_address);
            let (found, idx) = vector::index_of(&pool.staker_addresses, &staker_address);
            if (found) {
                vector::remove(&mut pool.staker_addresses, idx);
            };
        };
    }

    /// Claim accumulated rewards from a stake
    public entry fun claim_rewards(
        _staker: &signer,
        registry: &mut PoolRegistry,
        asset_id: vector<u8>,
        ctx: &mut TxContext
    ) acquires PoolRegistry {
        let staker_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        // Pool must exist
        assert!(table::contains(&registry.pools, asset_id_str),
                error::not_found(E_NOT_FOUND));
        let pool = table::borrow_mut(&mut registry.pools, asset_id_str);

        // Stake must exist
        assert!(table::contains(&pool.stakes, staker_address),
                error::not_found(E_INSUFFICIENT_STAKE));
        let stake_ref = table::borrow_mut(&mut pool.stakes, staker_address);

        let current_time = tx_context::epoch_timestamp_ms(ctx);
        let elapsed_ms = current_time - stake_ref.last_reward_time;
        let rewards = calculate_rewards(stake_ref.amount, pool.apy_basis_points, elapsed_ms);

        // Reset pending rewards
        stake_ref.pending_rewards = 0;
        stake_ref.last_reward_time = current_time;
    }

    /// Get details of a staking pool
    public fun get_pool_details(
        registry: &PoolRegistry,
        asset_id: vector<u8>
    ): (String, u64, u64, u64, u64) {
        let asset_id_str = utf8(asset_id);
        assert!(table::contains(&registry.pools, asset_id_str),
                error::not_found(E_NOT_FOUND));
        let pool = table::borrow(&registry.pools, asset_id_str);

        (
            pool.asset_id,
            pool.apy_basis_points,
            pool.lock_period_ms,
            pool.total_staked,
            vector::length(&pool.staker_addresses)
        )
    }

    /// Get details of a stake
    public fun get_stake_details(
        registry: &PoolRegistry,
        asset_id: vector<u8>,
        staker: address
    ): (u64, u64, u64, u64) {
        let asset_id_str = utf8(asset_id);
        assert!(table::contains(&registry.pools, asset_id_str),
                error::not_found(E_NOT_FOUND));
        let pool = table::borrow(&registry.pools, asset_id_str);
        assert!(table::contains(&pool.stakes, staker),
                error::not_found(E_INSUFFICIENT_STAKE));

        let stake_ref = table::borrow(&pool.stakes, staker);
        (
            stake_ref.amount,
            stake_ref.staked_at,
            stake_ref.last_reward_time,
            stake_ref.pending_rewards
        )
    }

    /// Calculate staking rewards (based on APY and elapsed time)
    fun calculate_rewards(amount: u64, apy_basis_points: u64, elapsed_ms: u64): u64 {
        // Use u128 to avoid overflow
        let amount_u128 = (amount as u128);
        let apy_u128 = (apy_basis_points as u128);
        let elapsed_u128 = (elapsed_ms as u128);

        // Annual milliseconds
        let annual_ms: u128 = 365 * 24 * 60 * 60 * 1000;
        let reward_rate = amount_u128 * apy_u128 * elapsed_u128;
        let reward = reward_rate / (10000u128 * annual_ms);
        (reward as u64)
    }
}
