/// CollateraX Test Module
///
/// This module contains unit tests for the CollateraX platform's smart contracts.
#[test_only]
module collaterax::collaterax_tests {
    use std::string::{utf8};
    use std::signer;
    use iota::test_scenario::{Self as ts, Scenario};
    use iota::tx_context::{Self, TxContext};
    use collaterax::spv_registry::{Self, SPVRegistry};
    use collaterax::asset_nft::{Self, AssetStore};
    use collaterax::asset_ft::{Self, TokenRegistry};
    use collaterax::governance_dao::{Self, ProposalRegistry};
    use collaterax::staking::{Self, PoolRegistry};

    // Test addresses
    const ADMIN: address = @0xADMIN;
    const SPV1: address = @0xSPV1;
    const SPV2: address = @0xSPV2;
    const USER1: address = @0xUSER1;
    const USER2: address = @0xUSER2;
    const TREASURY: address = @0xTREASURY;

    // Test constants
    const VOTING_PERIOD_MS: u64 = 604800000; // 7 days
    const LOCK_PERIOD_MS: u64 = 2592000000; // 30 days
    const APY_BASIS_POINTS: u64 = 500; // 5%

    #[test]
    public fun test_spv_registry() {
        let scenario = ts::begin(ADMIN);

        // Initialize SPV registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
        };

        // Register an SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        // Verify the SPV
        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );

            // Check if the SPV is verified
            assert!(spv_registry::is_verified_spv(SPV1, &registry), 0);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    public fun test_asset_nft() {
        let scenario = ts::begin(ADMIN);

        // Initialize SPV registry and asset store
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
            asset_nft::init_store(ts::sender(&scenario), ctx);
        };

        // Register and verify an SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        // Create an asset NFT
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_nft::create_asset(
                ts::sender(&scenario),
                b"ASSET001",
                b"real_estate",
                b"Luxury Apartment",
                b"A luxury apartment in downtown",
                b"{\"location\":\"New York\",\"size\":\"2000 sqft\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );

            ts::return_shared(registry);
            ts::return_shared(store);
        };

        // Transfer the asset to a user
        ts::next_tx(&mut scenario, SPV1);
        {
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_nft::transfer_asset(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                &mut store,
                ctx
            );

            // Check if the user is now the owner
            assert!(asset_nft::is_owner(USER1, utf8(b"ASSET001"), &store), 0);

            ts::return_shared(store);
        };

        ts::end(scenario);
    }

    #[test]
    public fun test_asset_ft() {
        let scenario = ts::begin(ADMIN);

        // Initialize all required registries and stores
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
            asset_nft::init_store(ts::sender(&scenario), ctx);
            asset_ft::init_registry(ts::sender(&scenario), ctx);
        };

        // Register and verify an SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        // Create an asset NFT
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_nft::create_asset(
                ts::sender(&scenario),
                b"ASSET001",
                b"real_estate",
                b"Luxury Apartment",
                b"A luxury apartment in downtown",
                b"{\"location\":\"New York\",\"size\":\"2000 sqft\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );

            ts::return_shared(registry);
            ts::return_shared(store);
        };

        // Create a fungible token for the asset
        ts::next_tx(&mut scenario, SPV1);
        {
            let spv_registry = ts::take_shared<SPVRegistry>(&scenario);
            let asset_store = ts::take_shared<AssetStore>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::create_token(
                ts::sender(&scenario),
                b"ASSET001",
                b"Luxury Apartment Token",
                b"LAT",
                18,
                1000000, // 1 million tokens
                TREASURY,
                &mut token_registry,
                &spv_registry,
                &asset_store,
                ctx
            );

            // Check if the SPV has the full supply
            assert!(asset_ft::balance_of(SPV1, utf8(b"ASSET001"), &token_registry) == 1000000, 0);

            ts::return_shared(spv_registry);
            ts::return_shared(asset_store);
            ts::return_shared(token_registry);
        };

        // Transfer tokens to a user
        ts::next_tx(&mut scenario, SPV1);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                100000, // 100k tokens
                &mut token_registry,
                ctx
            );

            // Check balances after transfer (accounting for fees)
            let spv_balance = asset_ft::balance_of(SPV1, utf8(b"ASSET001"), &token_registry);
            let user_balance = asset_ft::balance_of(USER1, utf8(b"ASSET001"), &token_registry);
            let treasury_balance = asset_ft::balance_of(TREASURY, utf8(b"ASSET001"), &token_registry);

            // SPV should have original amount - transfer amount + SPV fee
            assert!(spv_balance == 900500, 0); // 1000000 - 100000 + 500 (SPV fee)

            // User should have transfer amount - fees
            assert!(user_balance == 99000, 0); // 100000 - 1000 (total fees)

            // Treasury should have platform fee
            assert!(treasury_balance == 500, 0); // 0.5% of 100000

            ts::return_shared(token_registry);
        };

        ts::end(scenario);
    }

    #[test]
    public fun test_governance() {
        let scenario = ts::begin(ADMIN);

        // Initialize all required registries and stores
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
            asset_nft::init_store(ts::sender(&scenario), ctx);
            asset_ft::init_registry(ts::sender(&scenario), ctx);
            governance_dao::init_registry(ts::sender(&scenario), VOTING_PERIOD_MS, ctx);
        };

        // Set up an SPV, asset, and token (similar to previous tests)
        // Register and verify an SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        // Create an asset NFT and token
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_nft::create_asset(
                ts::sender(&scenario),
                b"ASSET001",
                b"real_estate",
                b"Luxury Apartment",
                b"A luxury apartment in downtown",
                b"{\"location\":\"New York\",\"size\":\"2000 sqft\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );

            ts::return_shared(registry);
            ts::return_shared(store);
        };

        ts::next_tx(&mut scenario, SPV1);
        {
            let spv_registry = ts::take_shared<SPVRegistry>(&scenario);
            let asset_store = ts::take_shared<AssetStore>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::create_token(
                ts::sender(&scenario),
                b"ASSET001",
                b"Luxury Apartment Token",
                b"LAT",
                18,
                1000000, // 1 million tokens
                TREASURY,
                &mut token_registry,
                &spv_registry,
                &asset_store,
                ctx
            );

            ts::return_shared(spv_registry);
            ts::return_shared(asset_store);
            ts::return_shared(token_registry);
        };

        // Transfer tokens to users for voting
        ts::next_tx(&mut scenario, SPV1);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                200000, // 200k tokens
                &mut token_registry,
                ctx
            );

            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER2,
                300000, // 300k tokens
                &mut token_registry,
                ctx
            );

            ts::return_shared(token_registry);
        };

        // Create a proposal
        ts::next_tx(&mut scenario, USER1);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            governance_dao::create_proposal(
                ts::sender(&scenario),
                b"Increase APY for staking",
                b"Proposal to increase the APY for staking from 5% to 7%",
                b"ASSET001",
                &mut proposal_registry,
                &token_registry,
                ctx
            );

            ts::return_shared(proposal_registry);
            ts::return_shared(token_registry);
        };

        // Get the proposal ID (in a real test, we would need to extract this)
        let proposal_id = object::new(tx_context::dummy()); // Placeholder

        // Vote on the proposal
        ts::next_tx(&mut scenario, USER1);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            governance_dao::vote(
                ts::sender(&scenario),
                proposal_id,
                true, // Vote in favor
                &mut proposal_registry,
                &token_registry,
                ctx
            );

            ts::return_shared(proposal_registry);
            ts::return_shared(token_registry);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            governance_dao::vote(
                ts::sender(&scenario),
                proposal_id,
                false, // Vote against
                &mut proposal_registry,
                &token_registry,
                ctx
            );

            ts::return_shared(proposal_registry);
            ts::return_shared(token_registry);
        };

        // Fast-forward time to end the voting period
        // In a real test, we would need to manipulate the timestamp

        // Finalize the proposal
        ts::next_tx(&mut scenario, ADMIN);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            governance_dao::finalize_proposal(
                proposal_id,
                &mut proposal_registry,
                ctx
            );

            ts::return_shared(proposal_registry);
        };

        // Execute the proposal
        ts::next_tx(&mut scenario, ADMIN);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            governance_dao::execute_proposal(
                ts::sender(&scenario),
                proposal_id,
                &mut proposal_registry,
                ctx
            );

            ts::return_shared(proposal_registry);
        };

        ts::end(scenario);
    }

    #[test]
    public fun test_staking() {
        let scenario = ts::begin(ADMIN);

        // Initialize all required registries and stores
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
            asset_nft::init_store(ts::sender(&scenario), ctx);
            asset_ft::init_registry(ts::sender(&scenario), ctx);
            staking::init_registry(ts::sender(&scenario), ctx);
        };

        // Set up an SPV, asset, and token (similar to previous tests)
        // Register and verify an SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );

            ts::return_shared(registry);
        };

        // Create an asset NFT and token
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_nft::create_asset(
                ts::sender(&scenario),
                b"ASSET001",
                b"real_estate",
                b"Luxury Apartment",
                b"A luxury apartment in downtown",
                b"{\"location\":\"New York\",\"size\":\"2000 sqft\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );

            ts::return_shared(registry);
            ts::return_shared(store);
        };

        ts::next_tx(&mut scenario, SPV1);
        {
            let spv_registry = ts::take_shared<SPVRegistry>(&scenario);
            let asset_store = ts::take_shared<AssetStore>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::create_token(
                ts::sender(&scenario),
                b"ASSET001",
                b"Luxury Apartment Token",
                b"LAT",
                18,
                1000000, // 1 million tokens
                TREASURY,
                &mut token_registry,
                &spv_registry,
                &asset_store,
                ctx
            );

            ts::return_shared(spv_registry);
            ts::return_shared(asset_store);
            ts::return_shared(token_registry);
        };

        // Transfer tokens to a user
        ts::next_tx(&mut scenario, SPV1);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                100000, // 100k tokens
                &mut token_registry,
                ctx
            );

            ts::return_shared(token_registry);
        };

        // Create a staking pool
        ts::next_tx(&mut scenario, ADMIN);
        {
            let pool_registry = ts::take_shared<PoolRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            staking::create_pool(
                ts::sender(&scenario),
                b"ASSET001",
                APY_BASIS_POINTS,
                LOCK_PERIOD_MS,
                TREASURY,
                &mut pool_registry,
                ctx
            );

            ts::return_shared(pool_registry);
        };

        // Stake tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let pool_registry = ts::take_shared<PoolRegistry>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            staking::stake(
                ts::sender(&scenario),
                b"ASSET001",
                50000, // Stake 50k tokens
                &mut pool_registry,
                &token_registry,
                ctx
            );

            // Check staking info
            let (amount, _, _, _) = staking::get_stake_info(USER1, utf8(b"ASSET001"), &pool_registry);
            assert!(amount == 50000, 0);

            ts::return_shared(pool_registry);
            ts::return_shared(token_registry);
        };

        // Fast-forward time to accumulate rewards
        // In a real test, we would need to manipulate the timestamp

        // Claim rewards
        ts::next_tx(&mut scenario, USER1);
        {
            let pool_registry = ts::take_shared<PoolRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            staking::claim_rewards(
                ts::sender(&scenario),
                b"ASSET001",
                &mut pool_registry,
                ctx
            );

            ts::return_shared(pool_registry);
        };

        // Fast-forward time past the lock period
        // In a real test, we would need to manipulate the timestamp

        // Unstake tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let pool_registry = ts::take_shared<PoolRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            staking::unstake(
                ts::sender(&scenario),
                b"ASSET001",
                25000, // Unstake half of the tokens
                &mut pool_registry,
                ctx
            );

            // Check staking info after unstaking
            let (amount, _, _, _) = staking::get_stake_info(USER1, utf8(b"ASSET001"), &pool_registry);
            assert!(amount == 25000, 0);

            ts::return_shared(pool_registry);
        };

        ts::end(scenario);
    }
}
