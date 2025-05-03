#[test_only]
module collaterax::collaterax_edge_tests {
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
    const UNAUTHORIZED: address = @0xUNAUTHORIZED;

    // Test constants
    const VOTING_PERIOD_MS: u64 = 604800000; // 7 days
    const LOCK_PERIOD_MS: u64 = 2592000000; // 30 days
    const APY_BASIS_POINTS: u64 = 500; // 5%

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ALREADY_EXISTS: u64 = 2;
    const E_NOT_FOUND: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 5;

    // Helper function to set up a basic test scenario with initialized registries
    fun setup_basic_scenario(): Scenario {
        let scenario = ts::begin(ADMIN);
        
        // Initialize all registries
        ts::next_tx(&mut scenario, ADMIN);
        {
            let ctx = ts::ctx(&mut scenario);
            spv_registry::init_registry(ts::sender(&scenario), ctx);
            asset_nft::init_store(ts::sender(&scenario), ctx);
            asset_ft::init_registry(ts::sender(&scenario), ctx);
            governance_dao::init_registry(ts::sender(&scenario), VOTING_PERIOD_MS, ctx);
            staking::init_registry(ts::sender(&scenario), ctx);
        };
        
        scenario
    }

    // Helper function to register and verify an SPV
    fun register_and_verify_spv(scenario: &mut Scenario, spv_address: address) {
        ts::next_tx(scenario, spv_address);
        {
            let registry = ts::take_shared<SPVRegistry>(scenario);
            let ctx = ts::ctx(scenario);
            
            spv_registry::register_spv(
                ts::sender(scenario),
                b"Test SPV",
                b"A test SPV",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );
            
            ts::return_shared(registry);
        };
        
        ts::next_tx(scenario, ADMIN);
        {
            let registry = ts::take_shared<SPVRegistry>(scenario);
            let ctx = ts::ctx(scenario);
            
            spv_registry::verify_spv(
                ts::sender(scenario),
                spv_address,
                &mut registry,
                ctx
            );
            
            ts::return_shared(registry);
        };
    }

    // Helper function to create an asset NFT
    fun create_asset_nft(scenario: &mut Scenario, spv_address: address, asset_id: vector<u8>) {
        ts::next_tx(scenario, spv_address);
        {
            let registry = ts::take_shared<SPVRegistry>(scenario);
            let store = ts::take_shared<AssetStore>(scenario);
            let ctx = ts::ctx(scenario);
            
            asset_nft::create_asset(
                ts::sender(scenario),
                asset_id,
                b"real_estate",
                b"Test Asset",
                b"A test asset",
                b"{\"test\":\"metadata\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );
            
            ts::return_shared(registry);
            ts::return_shared(store);
        };
    }

    // Helper function to create a fungible token
    fun create_asset_token(scenario: &mut Scenario, spv_address: address, asset_id: vector<u8>, total_supply: u64) {
        ts::next_tx(scenario, spv_address);
        {
            let spv_registry = ts::take_shared<SPVRegistry>(scenario);
            let asset_store = ts::take_shared<AssetStore>(scenario);
            let token_registry = ts::take_shared<TokenRegistry>(scenario);
            let ctx = ts::ctx(scenario);
            
            asset_ft::create_token(
                ts::sender(scenario),
                asset_id,
                b"Test Token",
                b"TST",
                18,
                total_supply,
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
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED)]
    public fun test_unauthorized_spv_verification() {
        let scenario = setup_basic_scenario();
        
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
        
        // Try to verify the SPV with an unauthorized account (not admin)
        ts::next_tx(&mut scenario, UNAUTHORIZED);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_NOT_AUTHORIZED
            spv_registry::verify_spv(
                ts::sender(&scenario),
                SPV1,
                &mut registry,
                ctx
            );
            
            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_EXISTS)]
    public fun test_duplicate_spv_registration() {
        let scenario = setup_basic_scenario();
        
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
        
        // Try to register the same SPV again
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_ALREADY_EXISTS
            spv_registry::register_spv(
                ts::sender(&scenario),
                b"Test SPV 1 Again",
                b"A test SPV again",
                b"United States",
                b"12345",
                &mut registry,
                ctx
            );
            
            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED)]
    public fun test_unverified_spv_create_asset() {
        let scenario = setup_basic_scenario();
        
        // Register an SPV but don't verify it
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
        
        // Try to create an asset with an unverified SPV
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_NOT_AUTHORIZED
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
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_OWNER)]
    public fun test_unauthorized_asset_transfer() {
        let scenario = setup_basic_scenario();
        
        // Register and verify an SPV
        register_and_verify_spv(&mut scenario, SPV1);
        
        // Create an asset
        create_asset_nft(&mut scenario, SPV1, b"ASSET001");
        
        // Try to transfer the asset with an unauthorized account
        ts::next_tx(&mut scenario, UNAUTHORIZED);
        {
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_NOT_OWNER
            asset_nft::transfer_asset(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                &mut store,
                ctx
            );
            
            ts::return_shared(store);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_EXISTS)]
    public fun test_duplicate_asset_creation() {
        let scenario = setup_basic_scenario();
        
        // Register and verify an SPV
        register_and_verify_spv(&mut scenario, SPV1);
        
        // Create an asset
        create_asset_nft(&mut scenario, SPV1, b"ASSET001");
        
        // Try to create another asset with the same ID
        ts::next_tx(&mut scenario, SPV1);
        {
            let registry = ts::take_shared<SPVRegistry>(&scenario);
            let store = ts::take_shared<AssetStore>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_ALREADY_EXISTS
            asset_nft::create_asset(
                ts::sender(&scenario),
                b"ASSET001", // Same asset ID
                b"real_estate",
                b"Another Asset",
                b"Another test asset",
                b"{\"test\":\"metadata\"}",
                true,
                true,
                &mut store,
                &registry,
                ctx
            );
            
            ts::return_shared(registry);
            ts::return_shared(store);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_INSUFFICIENT_BALANCE)]
    public fun test_transfer_more_than_balance() {
        let scenario = setup_basic_scenario();
        
        // Register and verify an SPV
        register_and_verify_spv(&mut scenario, SPV1);
        
        // Create an asset and token
        create_asset_nft(&mut scenario, SPV1, b"ASSET001");
        create_asset_token(&mut scenario, SPV1, b"ASSET001", 1000000);
        
        // Transfer some tokens to USER1
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
        
        // Try to transfer more tokens than USER1 has
        ts::next_tx(&mut scenario, USER1);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_INSUFFICIENT_BALANCE
            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER2,
                200000, // 200k tokens (more than the 99k USER1 has after fees)
                &mut token_registry,
                ctx
            );
            
            ts::return_shared(token_registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = E_NOT_AUTHORIZED)]
    public fun test_unauthorized_token_minting() {
        let scenario = setup_basic_scenario();
        
        // Register and verify SPVs
        register_and_verify_spv(&mut scenario, SPV1);
        register_and_verify_spv(&mut scenario, SPV2);
        
        // Create an asset and token with SPV1
        create_asset_nft(&mut scenario, SPV1, b"ASSET001");
        create_asset_token(&mut scenario, SPV1, b"ASSET001", 1000000);
        
        // Try to mint more tokens with SPV2 (not the original creator)
        ts::next_tx(&mut scenario, SPV2);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            // This should fail with E_NOT_AUTHORIZED
            asset_ft::mint(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                100000,
                &mut token_registry,
                ctx
            );
            
            ts::return_shared(token_registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    public fun test_successful_full_flow() {
        let scenario = setup_basic_scenario();
        
        // Register and verify an SPV
        register_and_verify_spv(&mut scenario, SPV1);
        
        // Create an asset and token
        create_asset_nft(&mut scenario, SPV1, b"ASSET001");
        create_asset_token(&mut scenario, SPV1, b"ASSET001", 1000000);
        
        // Transfer tokens to users
        ts::next_tx(&mut scenario, SPV1);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER1,
                200000,
                &mut token_registry,
                ctx
            );
            
            asset_ft::transfer(
                ts::sender(&scenario),
                b"ASSET001",
                USER2,
                300000,
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
                50000,
                &mut pool_registry,
                &token_registry,
                ctx
            );
            
            ts::return_shared(pool_registry);
            ts::return_shared(token_registry);
        };
        
        // Create a governance proposal
        ts::next_tx(&mut scenario, USER2);
        {
            let proposal_registry = ts::take_shared<ProposalRegistry>(&scenario);
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            let ctx = ts::ctx(&mut scenario);
            
            governance_dao::create_proposal(
                ts::sender(&scenario),
                b"Test Proposal",
                b"A test proposal description",
                b"ASSET001",
                &mut proposal_registry,
                &token_registry,
                ctx
            );
            
            ts::return_shared(proposal_registry);
            ts::return_shared(token_registry);
        };
        
        // Verify final balances
        ts::next_tx(&mut scenario, ADMIN);
        {
            let token_registry = ts::take_shared<TokenRegistry>(&scenario);
            
            // Check USER1 balance (original - transfer fees - staked amount)
            let user1_balance = asset_ft::balance_of(USER1, utf8(b"ASSET001"), &token_registry);
            assert!(user1_balance == 198000 - 50000, 0); // 198k (after fees) - 50k staked
            
            // Check USER2 balance (original - transfer fees)
            let user2_balance = asset_ft::balance_of(USER2, utf8(b"ASSET001"), &token_registry);
            assert!(user2_balance == 297000, 0); // 297k after fees
            
            // Check SPV balance (original - transfers + fees)
            let spv_balance = asset_ft::balance_of(SPV1, utf8(b"ASSET001"), &token_registry);
            assert!(spv_balance == 1000000 - 200000 - 300000 + 2500, 0); // Original - transfers + SPV fees
            
            // Check treasury balance (fees)
            let treasury_balance = asset_ft::balance_of(TREASURY, utf8(b"ASSET001"), &token_registry);
            assert!(treasury_balance == 2500, 0); // Platform fees
            
            ts::return_shared(token_registry);
        };
        
        ts::end(scenario);
    }
}
