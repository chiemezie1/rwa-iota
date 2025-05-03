#[allow(unused_use, unused_const, duplicate_alias)]
module collaterax::governance_dao {
    use std::string::{String, utf8};
    use iota::error;
    use iota::signer;
    use std::vector;
    use iota::object::{Self, UID};
    use iota::tx_context::{Self, TxContext};
    use iota::table::{Self, Table};
    use iota::coin::{Self, Coin};
    use iota::balance::{Self, Balance};
    use iota::clock::{Self, Clock};

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
    const E_INVALID_VOTE: u64 = 10;

    // Status constants
    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_EXECUTED: u64 = 3;

    // Voting constants
    const MIN_PROPOSAL_POWER: u64 = 1000000; // Minimum voting power to create a proposal
    const MIN_VOTING_PERIOD_MS: u64 = 86400000; // 1 day in milliseconds
    const VOTE_FOR: bool = true;
    const VOTE_AGAINST: bool = false;

    // Proposal struct
    public struct Proposal has key, store {
        id: UID,
        title: String,
        description: String,
        asset_id: String,
        proposer: address,
        created_at: u64,
        voting_end_time: u64,
        status: u64,
        for_votes: u64,
        against_votes: u64,
        executed_at: u64,
        votes: Table<address, bool>, // Maps voter address to their vote (true = for, false = against)
        voting_power: Table<address, u64>, // Maps voter address to their voting power
    }

    // Registry to store all proposals
    public struct ProposalRegistry has key {
        id: UID,
        admin: address,
        proposals: Table<address, Proposal>, // Using address as key instead of UID
        proposal_ids: vector<address>, // Store proposal IDs for iteration
    }

    // Initialize the proposal registry
    public entry fun init_registry(admin: &signer, ctx: &mut TxContext) {
        let admin_address = signer::address_of(admin);

        let registry = ProposalRegistry {
            id: object::new(ctx),
            admin: admin_address,
            proposals: table::new(ctx),
            proposal_ids: vector::empty(),
        };

        // Share the registry object so it can be accessed by anyone
        object::share_object(registry);
    }

    // Create a new proposal
    public entry fun create_proposal(
        proposer: &signer,
        title: vector<u8>,
        description: vector<u8>,
        asset_id: vector<u8>,
        voting_period_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let proposer_address = signer::address_of(proposer);
        let asset_id_str = utf8(asset_id);

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Check if proposer has enough voting power
        let voting_power = get_voting_power(proposer_address);
        assert!(voting_power >= MIN_PROPOSAL_POWER, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));

        // Ensure voting period is at least the minimum
        let voting_period = if (voting_period_ms < MIN_VOTING_PERIOD_MS) { MIN_VOTING_PERIOD_MS } else { voting_period_ms };

        // Create the proposal
        let proposal = Proposal {
            id: object::new(ctx),
            title: utf8(title),
            description: utf8(description),
            asset_id: asset_id_str,
            proposer: proposer_address,
            created_at: current_time,
            voting_end_time: current_time + voting_period,
            status: STATUS_ACTIVE,
            for_votes: 0,
            against_votes: 0,
            executed_at: 0,
            votes: table::new(ctx),
            voting_power: table::new(ctx),
        };

        // Get the registry
        let registry = borrow_registry();

        // Add the proposal to the registry
        let proposal_addr = object::id_address(&proposal.id);
        table::add(&mut registry.proposals, proposal_addr, proposal);
        vector::push_back(&mut registry.proposal_ids, proposal_addr);
    }

    // Vote on a proposal
    public entry fun vote(
        voter: &signer,
        proposal_addr: address,
        vote_for: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let voter_address = signer::address_of(voter);

        // Get the registry
        let registry = borrow_registry();

        // Check if the proposal exists
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_addr);

        // Check if the proposal is still active
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_VOTING_PERIOD_ENDED));

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Check if the voting period has ended
        assert!(current_time <= proposal.voting_end_time, error::invalid_state(E_VOTING_PERIOD_ENDED));

        // Check if the voter has already voted
        assert!(!table::contains(&proposal.votes, voter_address), error::already_exists(E_ALREADY_VOTED));

        // Get the voter's voting power
        let voting_power = get_voting_power(voter_address);
        assert!(voting_power > 0, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));

        // Record the vote
        table::add(&mut proposal.votes, voter_address, vote_for);
        table::add(&mut proposal.voting_power, voter_address, voting_power);

        // Update the vote counts
        if (vote_for) {
            proposal.for_votes = proposal.for_votes + voting_power;
        } else {
            proposal.against_votes = proposal.against_votes + voting_power;
        }
    }

    // Finalize a proposal after the voting period ends
    public entry fun finalize_proposal(
        proposal_addr: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Get the registry
        let registry = borrow_registry();

        // Check if the proposal exists
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_addr);

        // Check if the proposal is still active
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Check if the voting period has ended
        assert!(current_time > proposal.voting_end_time, error::invalid_state(E_VOTING_PERIOD_NOT_ENDED));

        // Determine the outcome
        if (proposal.for_votes > proposal.against_votes) {
            proposal.status = STATUS_APPROVED;
        } else {
            proposal.status = STATUS_REJECTED;
        }
    }

    // Execute an approved proposal
    public entry fun execute_proposal(
        executor: &signer,
        proposal_addr: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let _executor_address = signer::address_of(executor);

        // Get the registry
        let registry = borrow_registry();

        // Check if the proposal exists
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_addr);

        // Check if the proposal is approved
        assert!(proposal.status == STATUS_APPROVED, error::invalid_state(E_PROPOSAL_REJECTED));

        // Check if the proposal has already been executed
        assert!(proposal.executed_at == 0, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));

        // Get the current time
        let current_time = clock::timestamp_ms(clock);

        // Mark the proposal as executed
        proposal.status = STATUS_EXECUTED;
        proposal.executed_at = current_time;

        // Execute the proposal logic here
        // This would typically involve calling other modules or functions
        // For now, we just mark it as executed
    }

    // Get proposal details
    public fun get_proposal_details(
        registry: &ProposalRegistry,
        proposal_addr: address
    ): (String, String, String, address, u64, u64, u64, u64, u64, u64) {
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        let proposal = table::borrow(&registry.proposals, proposal_addr);

        (
            proposal.title,
            proposal.description,
            proposal.asset_id,
            proposal.proposer,
            proposal.created_at,
            proposal.voting_end_time,
            proposal.status,
            proposal.for_votes,
            proposal.against_votes,
            proposal.executed_at
        )
    }

    // Get the total number of votes for a proposal
    public fun get_total_votes(
        registry: &ProposalRegistry,
        proposal_addr: address
    ): (u64, u64) {
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        let proposal = table::borrow(&registry.proposals, proposal_addr);

        (proposal.for_votes, proposal.against_votes)
    }

    // Check if a voter has voted on a proposal
    public fun has_voted(
        registry: &ProposalRegistry,
        proposal_addr: address,
        voter: address
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        let proposal = table::borrow(&registry.proposals, proposal_addr);

        table::contains(&proposal.votes, voter)
    }

    // Get a voter's vote on a proposal
    public fun get_vote(
        registry: &ProposalRegistry,
        proposal_addr: address,
        voter: address
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_addr), error::not_found(E_PROPOSAL_NOT_FOUND));

        let proposal = table::borrow(&registry.proposals, proposal_addr);

        assert!(table::contains(&proposal.votes, voter), error::not_found(E_NOT_AUTHORIZED));

        *table::borrow(&proposal.votes, voter)
    }

    // Helper function to get a user's voting power
    // In a real implementation, this would likely be based on token holdings
    fun get_voting_power(voter: address): u64 {
        // For simplicity, we'll return a fixed value
        // In a real implementation, this would query token balances
        if (voter == @0x1) {
            return 2000000; // Admin has more voting power
        } else {
            return 1000000; // Regular users have standard voting power
        }
    }

    // Helper function to borrow the registry
    fun borrow_registry(): &mut ProposalRegistry {
        // In a real implementation, this would use a proper way to get the registry
        // For testing purposes, we'll use a dummy implementation
        let dummy_registry = ProposalRegistry {
            id: object::new_for_testing(),
            admin: @0x1,
            proposals: table::new_for_testing(),
            proposal_ids: vector::empty(),
        };

        &mut dummy_registry
    }
}
