/// DAO Governance Module
///
/// This module implements a decentralized autonomous organization (DAO) for
/// platform governance. It allows token holders to create proposals, vote on them,
/// and execute approved proposals.
///
/// The voting power is proportional to the number of tokens held, ensuring that
/// stakeholders with larger investments have more influence in decision-making.
module collaterax::governance_dao {
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
    const E_PROPOSAL_ALREADY_EXISTS: u64 = 2;
    const E_PROPOSAL_NOT_FOUND: u64 = 3;
    const E_ALREADY_VOTED: u64 = 4;
    const E_VOTING_PERIOD_ENDED: u64 = 5;
    const E_VOTING_PERIOD_NOT_ENDED: u64 = 6;
    const E_PROPOSAL_ALREADY_EXECUTED: u64 = 7;
    const E_PROPOSAL_REJECTED: u64 = 8;
    const E_INSUFFICIENT_VOTING_POWER: u64 = 9;
    const E_INVALID_VOTE: u64 = 10;

    /// Proposal status
    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_EXECUTED: u64 = 3;

    /// Vote options
    const VOTE_FOR: bool = true;
    const VOTE_AGAINST: bool = false;

    /// Minimum voting power required to create a proposal (in tokens)
    const MIN_PROPOSAL_POWER: u64 = 1000;

    /// Represents a governance proposal
    struct Proposal has key, store {
        /// Unique identifier for the proposal
        id: ID,
        /// Title of the proposal
        title: String,
        /// Description of the proposal
        description: String,
        /// Asset ID of the token used for voting
        asset_id: String,
        /// Address of the proposer
        proposer: address,
        /// Number of votes in favor
        for_votes: u64,
        /// Number of votes against
        against_votes: u64,
        /// Table mapping addresses to their votes (true = for, false = against)
        votes: Table<address, bool>,
        /// Status of the proposal
        status: u64,
        /// Timestamp when the proposal was created
        created_at: u64,
        /// Timestamp when voting ends
        voting_end_time: u64,
        /// Timestamp when the proposal was executed (if applicable)
        executed_at: u64
    }

    /// Global registry of all proposals
    struct ProposalRegistry has key {
        /// Table mapping proposal IDs to proposals
        proposals: Table<ID, Proposal>,
        /// List of all proposal IDs for enumeration
        proposal_ids: vector<ID>,
        /// Address of the admin
        admin: address,
        /// Default voting period in milliseconds (7 days)
        default_voting_period_ms: u64
    }

    /// Initialize the proposal registry
    /// Can only be called once by the platform admin
    public entry fun init_registry(
        admin: &signer,
        default_voting_period_ms: u64,
        ctx: &mut TxContext
    ) {
        let admin_address = signer::address_of(admin);
        
        // Create a new proposal registry
        let registry = ProposalRegistry {
            proposals: table::new(ctx),
            proposal_ids: vector::empty<ID>(),
            admin: admin_address,
            default_voting_period_ms: default_voting_period_ms
        };
        
        // Move the registry to the global storage
        object::transfer(registry, admin_address);
    }

    /// Create a new proposal
    /// Requires a minimum voting power to create
    public entry fun create_proposal(
        proposer: &signer,
        title: vector<u8>,
        description: vector<u8>,
        asset_id: vector<u8>,
        registry: &mut ProposalRegistry,
        token_registry: &TokenRegistry,
        ctx: &mut TxContext
    ) {
        let proposer_address = signer::address_of(proposer);
        let asset_id_str = utf8(asset_id);
        
        // Check if the proposer has enough voting power
        let voting_power = asset_ft::balance_of(proposer_address, asset_id_str, token_registry);
        assert!(voting_power >= MIN_PROPOSAL_POWER, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));
        
        // Create a new proposal
        let proposal_id = object::new(ctx);
        let proposal = Proposal {
            id: proposal_id,
            title: utf8(title),
            description: utf8(description),
            asset_id: asset_id_str,
            proposer: proposer_address,
            for_votes: 0,
            against_votes: 0,
            votes: table::new(ctx),
            status: STATUS_ACTIVE,
            created_at: tx_context::epoch_timestamp_ms(ctx),
            voting_end_time: tx_context::epoch_timestamp_ms(ctx) + registry.default_voting_period_ms,
            executed_at: 0
        };
        
        // Add the proposal to the registry
        table::add(&mut registry.proposals, object::id(&proposal_id), proposal);
        vector::push_back(&mut registry.proposal_ids, proposal_id);
    }

    /// Vote on a proposal
    public entry fun vote(
        voter: &signer,
        proposal_id: ID,
        vote: bool,
        registry: &mut ProposalRegistry,
        token_registry: &TokenRegistry,
        ctx: &mut TxContext
    ) {
        let voter_address = signer::address_of(voter);
        
        // Ensure the proposal exists
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_id);
        
        // Ensure the proposal is still active
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_VOTING_PERIOD_ENDED));
        
        // Ensure the voting period hasn't ended
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        assert!(current_time <= proposal.voting_end_time, error::invalid_state(E_VOTING_PERIOD_ENDED));
        
        // Ensure the voter hasn't already voted
        assert!(!table::contains(&proposal.votes, voter_address), error::already_exists(E_ALREADY_VOTED));
        
        // Get the voter's voting power
        let voting_power = asset_ft::balance_of(voter_address, proposal.asset_id, token_registry);
        assert!(voting_power > 0, error::permission_denied(E_INSUFFICIENT_VOTING_POWER));
        
        // Record the vote
        table::add(&mut proposal.votes, voter_address, vote);
        
        // Update vote counts
        if (vote == VOTE_FOR) {
            proposal.for_votes = proposal.for_votes + voting_power;
        } else {
            proposal.against_votes = proposal.against_votes + voting_power;
        };
    }

    /// Finalize a proposal after the voting period ends
    public entry fun finalize_proposal(
        proposal_id: ID,
        registry: &mut ProposalRegistry,
        ctx: &mut TxContext
    ) {
        // Ensure the proposal exists
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_id);
        
        // Ensure the proposal is still active
        assert!(proposal.status == STATUS_ACTIVE, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));
        
        // Ensure the voting period has ended
        let current_time = tx_context::epoch_timestamp_ms(ctx);
        assert!(current_time > proposal.voting_end_time, error::invalid_state(E_VOTING_PERIOD_NOT_ENDED));
        
        // Determine the outcome
        if (proposal.for_votes > proposal.against_votes) {
            proposal.status = STATUS_APPROVED;
        } else {
            proposal.status = STATUS_REJECTED;
        };
    }

    /// Execute an approved proposal
    /// This is a placeholder function that would be implemented differently
    /// depending on the specific actions that proposals can take
    public entry fun execute_proposal(
        executor: &signer,
        proposal_id: ID,
        registry: &mut ProposalRegistry,
        ctx: &mut TxContext
    ) {
        let executor_address = signer::address_of(executor);
        
        // Ensure the proposal exists
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        // Get the proposal
        let proposal = table::borrow_mut(&mut registry.proposals, proposal_id);
        
        // Ensure the proposal is approved
        assert!(proposal.status == STATUS_APPROVED, error::invalid_state(E_PROPOSAL_REJECTED));
        
        // Ensure the proposal hasn't been executed yet
        assert!(proposal.executed_at == 0, error::invalid_state(E_PROPOSAL_ALREADY_EXECUTED));
        
        // In a real implementation, this would execute the proposal's action
        // For now, we just mark it as executed
        proposal.status = STATUS_EXECUTED;
        proposal.executed_at = tx_context::epoch_timestamp_ms(ctx);
    }

    /// Get the number of proposals
    public fun get_proposal_count(registry: &ProposalRegistry): u64 {
        vector::length(&registry.proposal_ids)
    }

    /// Get a proposal ID by index
    public fun get_proposal_id_by_index(registry: &ProposalRegistry, index: u64): ID {
        *vector::borrow(&registry.proposal_ids, index)
    }

    /// Get proposal information
    public fun get_proposal_info(
        proposal_id: ID,
        registry: &ProposalRegistry
    ): (String, String, String, address, u64, u64, u64, u64, u64, u64) {
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        let proposal = table::borrow(&registry.proposals, proposal_id);
        (
            proposal.title,
            proposal.description,
            proposal.asset_id,
            proposal.proposer,
            proposal.for_votes,
            proposal.against_votes,
            proposal.status,
            proposal.created_at,
            proposal.voting_end_time,
            proposal.executed_at
        )
    }

    /// Check if an address has voted on a proposal
    public fun has_voted(
        voter: address,
        proposal_id: ID,
        registry: &ProposalRegistry
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        let proposal = table::borrow(&registry.proposals, proposal_id);
        table::contains(&proposal.votes, voter)
    }

    /// Get an address's vote on a proposal
    public fun get_vote(
        voter: address,
        proposal_id: ID,
        registry: &ProposalRegistry
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_id), error::not_found(E_PROPOSAL_NOT_FOUND));
        
        let proposal = table::borrow(&registry.proposals, proposal_id);
        assert!(table::contains(&proposal.votes, voter), error::not_found(E_NOT_AUTHORIZED));
        
        *table::borrow(&proposal.votes, voter)
    }
}
