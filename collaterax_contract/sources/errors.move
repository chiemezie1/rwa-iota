module collaterax::errors {
    // Centralized error codes for Collaterax modules
    public const E_NOT_AUTHORIZED: u64 = 1;
    public const E_POOL_ALREADY_EXISTS: u64 = 2;
    public const E_POOL_NOT_FOUND: u64 = 3;
    public const E_INSUFFICIENT_BALANCE: u64 = 4;
    public const E_INSUFFICIENT_STAKE: u64 = 5;
    public const E_ZERO_AMOUNT: u64 = 6;
    public const E_LOCK_PERIOD_NOT_ENDED: u64 = 7;

    public const E_SPV_ALREADY_REGISTERED: u64 = 8;
    public const E_SPV_NOT_FOUND: u64 = 9;
    public const E_REGISTRY_ALREADY_EXISTS: u64 = 10;
    public const E_INVALID_STATUS: u64 = 11;

    public const E_PROPOSAL_ALREADY_EXISTS: u64 = 12;
    public const E_PROPOSAL_NOT_FOUND: u64 = 13;
    public const E_ALREADY_VOTED: u64 = 14;
    public const E_VOTING_PERIOD_ENDED: u64 = 15;
    public const E_VOTING_PERIOD_NOT_ENDED: u64 = 16;
    public const E_PROPOSAL_ALREADY_EXECUTED: u64 = 17;
    public const E_PROPOSAL_REJECTED: u64 = 18;
    public const E_INSUFFICIENT_VOTING_POWER: u64 = 19;
    public const E_INVALID_VOTE: u64 = 20;

    public const E_ASSET_ALREADY_EXISTS: u64 = 21;
    public const E_ASSET_NOT_FOUND: u64 = 22;
    public const E_NOT_OWNER: u64 = 23;
    public const E_STORE_ALREADY_EXISTS: u64 = 24;
    public const E_NOT_BURNABLE: u64 = 25;
    public const E_INVALID_METADATA: u64 = 26;

    public const E_TOKEN_ALREADY_EXISTS: u64 = 27;
    public const E_TOKEN_NOT_FOUND: u64 = 28;
    
    // Error utility functions
    public fun require_authorized(condition: bool) {
        assert!(condition, E_NOT_AUTHORIZED)
    }
    
    public fun require_exists<T>(exists: bool) {
        assert!(exists, E_ASSET_NOT_FOUND)
    }
    
    public fun require_not_exists<T>(exists: bool) {
        assert!(!exists, E_ASSET_ALREADY_EXISTS)
    }
    
    public fun require_owner(actual: address, expected: address) {
        assert!(actual == expected, E_NOT_OWNER)
    }
}
