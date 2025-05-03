module collaterax::staking {
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

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_STAKE: u64 = 5;
    const E_ZERO_AMOUNT: u64 = 6;
    const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

    // Staking information per user
    public struct Stake has store, drop {
        amount: u64,
        staked_at: u64,
        last_reward_time: u64,
        pending_rewards: u64,
    }

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
        pool.total_staked = pool.total_staked - amount;

        // Return principal and rewards
        coin::deposit<Balance>(staker_addr, amount + total_rewards, ctx);
    }

    /// View pool info
    public fun get_pool(asset_id: String): StakingPool {
        let caller = signer::borrow_signer();
        let addr = signer::address_of(&caller);
        let store_ref = object::borrow_global<RegistryStore>(addr);
        let reg = option::borrow(&store_ref.registry);
        assert!(table::contains(&reg.pools, asset_id), error::not_found(E_POOL_NOT_FOUND));
        table::borrow(&reg.pools, asset_id)
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
