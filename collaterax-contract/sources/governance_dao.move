module collaterax::governance_dao {
    use std::signer;
    use std::vector::{self};
    use std::option::{self, Option};
    use std::string::{self, String, utf8};
    use iota::error;
    use iota::tx_context::{self, TxContext};
    use iota::object::{self, UID};
    use iota::table::{self, Table};
    use iota::clock::{self, Clock};

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_PROPOSAL_ALREADY_EXISTS: u64 = 2;
    const E_PROPOSAL_NOT_FOUND: u64 = 3;
    const E_ALREADY_VOTED: u64 = 4;
    const E_VOTING_PERIOD_ENDED: u64 = 5;
    const E_VOTING_PERIOD_NOT_ENDED: u64 = 6;
    const E_PROPOSAL_ALREADY_EXECUTED: u64 = 7;
    const E_PROPOSAL_REJECTED: u64 = 8;
    const E_INSUFFICIENT_VOTING_POWER: u64 = 9;

    // Status constants
    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_EXECUTED: u64 = 3;

    // Voting threshold
    const MIN_PROPOSAL_POWER: u64 = 1_000_000;

    // Proposal data structure
    public struct Proposal has store {
        id: UID,
        title: String,
        description: String,
        asset_id: String,
        proposer: address,
        created_at: u64,
        voting_end: u64,
        status: u64,
        for_votes: u64,
        against_votes: u64,
        executed_at: u64,
        votes: Table<address, bool>,
        voting_power: Table<address, u64>,
    }

    // Registry singleton for proposals
    public struct RegistryStore has key {
        registry: Option<ProposalRegistry>,
    }

    public struct ProposalRegistry has store {
        id: UID,
        admin: address,
        proposals: Table<address, Proposal>,
        addresses: vector<address>,
    }

    /// Initialize the DAO registry; only callable once by admin
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_addr = signer::address_of(admin);
        assert!(!object::exists<RegistryStore>(admin_addr), error::already_exists(E_PROPOSAL_ALREADY_EXISTS));

        let registry = ProposalRegistry {
            id: object::new(ctx),
            admin: admin_addr,
            proposals: table::new(ctx),
            addresses: vector::empty(),
        };
        let store = RegistryStore { registry: option::some(registry) };
        object::publish_object(store);
    }

    /// Create and register a new proposal
    public entry fun create_proposal(
        proposer: &signer,
        title_b: vector<u8>,
        desc_b: vector<u8>,
        asset_b: vector<u8>,
        period_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let proposer_addr = signer::address_of(proposer);
        let store_ref = object::borrow_global_mut<RegistryStore>(proposer_addr);
        let registry = option::borrow_mut(&mut store_ref.registry);
        assert!(registry.admin == proposer_addr, error::permission_denied(E_NOT_AUTHORIZED));

        let now = clock::timestamp_ms(clock);
        let power = get_voting_power(proposer_addr);
        assert!(power >= MIN_PROPOSAL_POWER, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));

        let end_time = now + period_ms;
        let proposal = Proposal {
            id: object::new(ctx),
            title: utf8(title_b),
            description: utf8(desc_b),
            asset_id: utf8(asset_b),
            proposer: proposer_addr,
            created_at: now,
            voting_end: end_time,
            status: STATUS_ACTIVE,
            for_votes: 0,
            against_votes: 0,
            executed_at: 0,
            votes: table::new(ctx),
            voting_power: table::new(ctx),
        };
        let p_addr = object::id_address(&proposal.id);
        table::add(&mut registry.proposals, p_addr, proposal);
        vector::push_back(&mut registry.addresses, p_addr);
    }

    /// Vote on an active proposal
    public entry fun vote(
        voter: &signer,
        prop_addr: address,
        in_favor: bool,
        clock: &Clock
    ) {
        let voter_addr = signer::address_of(voter);
        let store_ref = object::borrow_global_mut<RegistryStore>(voter_addr);
        let registry = option::borrow_mut(&mut store_ref.registry);

        assert!(table::contains(&registry.proposals, prop_addr), error::not_found(E_PROPOSAL_NOT_FOUND));
        let proposal = table::borrow_mut(&mut registry.proposals, prop_addr);
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_VOTING_PERIOD_ENDED));

        let now = clock::timestamp_ms(clock);
        assert!(now <= proposal.voting_end, error::invalid_state(E_VOTING_PERIOD_ENDED));
        assert!(!table::contains(&proposal.votes, voter_addr), error::already_exists(E_ALREADY_VOTED));

        let power = get_voting_power(voter_addr);
        assert!(power > 0, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));

        table::add(&mut proposal.votes, voter_addr, in_favor);
        table::add(&mut proposal.voting_power, voter_addr, power);
        if (in_favor) { proposal.for_votes = proposal.for_votes + power; }
        else { proposal.against_votes = proposal.against_votes + power; }
    }

    /// Finalize a proposal after voting period
    public entry fun finalize_proposal(
        prop_addr: address,
        clock: &Clock
    ) {
        let caller = signer::borrow_signer();
        let caller_addr = signer::address_of(&caller);
        let store_ref = object::borrow_global_mut<RegistryStore>(caller_addr);
        let registry = option::borrow_mut(&mut store_ref.registry);

        assert!(table::contains(&registry.proposals, prop_addr), error::not_found(E_PROPOSAL_NOT_FOUND));
        let proposal = table::borrow_mut(&mut registry.proposals, prop_addr);
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));

        let now = clock::timestamp_ms(clock);
        assert!(now > proposal.voting_end, error::invalid_state(E_VOTING_PERIOD_NOT_ENDED));

        proposal.status = if (proposal.for_votes > proposal.against_votes) { STATUS_APPROVED } else { STATUS_REJECTED };
    }

    /// Execute an approved proposal
    public entry fun execute_proposal(
        executor: &signer,
        prop_addr: address,
        clock: &Clock
    ) {
        let executor_addr = signer::address_of(executor);
        let store_ref = object::borrow_global_mut<RegistryStore>(executor_addr);
        let registry = option::borrow_mut(&mut store_ref.registry);

        assert!(table::contains(&registry.proposals, prop_addr), error::not_found(E_PROPOSAL_NOT_FOUND));
        let proposal = table::borrow_mut(&mut registry.proposals, prop_addr);
        assert!(proposal.status == STATUS_APPROVED, error::invalid_state(E_PROPOSAL_REJECTED));
        assert!(proposal.executed_at == 0, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));

        proposal.status = STATUS_EXECUTED;
        proposal.executed_at = clock::timestamp_ms(clock);
        // Business logic execution placeholder
    }

    /// Retrieve proposal details
    public fun get_proposal(prop_addr: address): Proposal {
        let viewer = signer::borrow_signer();
        let viewer_addr = signer::address_of(&viewer);
        let store_ref = object::borrow_global<RegistryStore>(viewer_addr);
        let registry = option::borrow(&store_ref.registry);
        assert!(table::contains(&registry.proposals, prop_addr), error::not_found(E_PROPOSAL_NOT_FOUND));
        table::borrow(&registry.proposals, prop_addr)
    }

    /// List all proposal addresses
    public fun list_proposals(): vector<address> {
        let viewer = signer::borrow_signer();
        let viewer_addr = signer::address_of(&viewer);
        let store_ref = object::borrow_global<RegistryStore>(viewer_addr);
        let registry = option::borrow(&store_ref.registry);
        registry.addresses
    }

    // Placeholder for future voting power logic
    fun get_voting_power(_user: address): u64 {
        // Integrate token-based power here
        1_000_000
    }
}
