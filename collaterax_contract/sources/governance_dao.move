#[allow(unused_use, unused_const, duplicate_alias, unused_variable)]
module collaterax::governance_dao {
    use std::string::{String, utf8};
    use std::vector;
    use iota::tx_context::{Self, TxContext};
    use iota::object::{Self, UID, ID};
    use iota::table::{Self, Table};
    use iota::clock::{Self, Clock};
    use iota::transfer;
    use collaterax::errors::{E_NOT_AUTHORIZED, E_NOT_FOUND, E_ALREADY_VOTED, E_VOTING_PERIOD_ENDED, E_VOTING_PERIOD_NOT_ENDED, E_PROPOSAL_ALREADY_EXECUTED, E_PROPOSAL_REJECTED, E_INSUFFICIENT_VOTING_POWER, E_INVALID_VOTE};

    const MIN_PROPOSAL_POWER: u64 = 1000000;       // Minimum voting power to create a proposal
    const MIN_VOTING_PERIOD_MS: u64 = 86400000;    // 1 day in milliseconds
    const VOTE_FOR: bool = true;
    const VOTE_AGAINST: bool = false;

    // Status constants
    const STATUS_ACTIVE: u64 = 0;
    const STATUS_APPROVED: u64 = 1;
    const STATUS_REJECTED: u64 = 2;
    const STATUS_EXECUTED: u64 = 3;

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
        votes: Table<address, bool>,
        voting_power: Table<address, u64>,
    }

    public struct ProposalRegistry has key {
        id: UID,
        admin: address,
        proposals: Table<address, Proposal>,
        proposal_ids: vector<address>,
    }

    /// Initialize the proposal registry
    public entry fun init_registry(_admin: &signer, ctx: &mut TxContext) {
        let admin_address = tx_context::sender(ctx);
        let registry = ProposalRegistry {
            id: object::new(ctx),
            admin: admin_address,
            proposals: table::new(ctx),
            proposal_ids: vector::empty(),
        };
        transfer::share_object(registry);
    }

    /// Create a new proposal (requires minimum voting power)
    public entry fun create_proposal(
        _proposer: &signer,
        registry: &mut ProposalRegistry,
        title: vector<u8>,
        description: vector<u8>,
        asset_id: vector<u8>,
        voting_period_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires ProposalRegistry {
        let proposer_address = tx_context::sender(ctx);
        let asset_id_str = utf8(asset_id);

        let current_time = clock::timestamp_ms(clock);
        let voting_power = get_voting_power(proposer_address);
        assert!(voting_power >= MIN_PROPOSAL_POWER,
                error::insufficient_voting_power(E_INSUFFICIENT_VOTING_POWER));

        let voting_period = if (voting_period_ms < MIN_VOTING_PERIOD_MS) {
            MIN_VOTING_PERIOD_MS
        } else {
            voting_period_ms
        };

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

        let proposal_addr = object::uid_to_address(&proposal.id);
        table::add(&mut registry.proposals, proposal_addr, proposal);
        vector::push_back(&mut registry.proposal_ids, proposal_addr);
    }

    /// Vote on a proposal (true = for, false = against)
    public entry fun vote(
        _voter: &signer,
        registry: &mut ProposalRegistry,
        proposal_addr: address,
        vote_for: bool,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires ProposalRegistry {
        let voter_address = tx_context::sender(ctx);

        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow_mut(&mut registry.proposals, proposal_addr);

        assert!(proposal_ref.status == STATUS_ACTIVE,
                error::voting_period_ended(E_VOTING_PERIOD_ENDED));

        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= proposal_ref.voting_end_time,
                error::voting_period_ended(E_VOTING_PERIOD_ENDED));

        assert!(!table::contains(&proposal_ref.votes, voter_address),
                error::already_voted(E_ALREADY_VOTED));

        let voting_power = get_voting_power(voter_address);
        assert!(voting_power > 0,
                error::insufficient_voting_power(E_INSUFFICIENT_VOTING_POWER));

        table::add(&mut proposal_ref.votes, voter_address, vote_for);
        table::add(&mut proposal_ref.voting_power, voter_address, voting_power);

        if (vote_for) {
            proposal_ref.for_votes = proposal_ref.for_votes + voting_power;
        } else {
            proposal_ref.against_votes = proposal_ref.against_votes + voting_power;
        }
    }

    /// Finalize a proposal after voting period ends
    public entry fun finalize_proposal(
        registry: &mut ProposalRegistry,
        proposal_addr: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires ProposalRegistry {
        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow_mut(&mut registry.proposals, proposal_addr);

        assert!(proposal_ref.status == STATUS_ACTIVE,
                error::already_executed(E_PROPOSAL_ALREADY_EXECUTED));

        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > proposal_ref.voting_end_time,
                error::invalid_argument(E_VOTING_PERIOD_NOT_ENDED));

        // Determine outcome
        if (proposal_ref.for_votes > proposal_ref.against_votes) {
            proposal_ref.status = STATUS_APPROVED;
        } else {
            proposal_ref.status = STATUS_REJECTED;
        }
    }

    /// Execute an approved proposal
    public entry fun execute_proposal(
        _executor: &signer,
        registry: &mut ProposalRegistry,
        proposal_addr: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) acquires ProposalRegistry {
        let _executor_address = tx_context::sender(ctx);

        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow_mut(&mut registry.proposals, proposal_addr);

        assert!(proposal_ref.status == STATUS_APPROVED,
                error::invalid_argument(E_PROPOSAL_REJECTED));
        assert!(proposal_ref.executed_at == 0,
                error::already_executed(E_PROPOSAL_ALREADY_EXECUTED));

        let current_time = clock::timestamp_ms(clock);
        proposal_ref.status = STATUS_EXECUTED;
        proposal_ref.executed_at = current_time;

        // (Proposal-specific logic would go here)
    }

    /// Get proposal details
    public fun get_proposal_details(
        registry: &ProposalRegistry,
        proposal_addr: address
    ): (String, String, String, address, u64, u64, u64, u64, u64, u64) {
        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow(&registry.proposals, proposal_addr);

        (
            proposal_ref.title,
            proposal_ref.description,
            proposal_ref.asset_id,
            proposal_ref.proposer,
            proposal_ref.created_at,
            proposal_ref.voting_end_time,
            proposal_ref.status,
            proposal_ref.for_votes,
            proposal_ref.against_votes,
            proposal_ref.executed_at
        )
    }

    /// Get total votes (for and against)
    public fun get_total_votes(
        registry: &ProposalRegistry,
        proposal_addr: address
    ): (u64, u64) {
        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow(&registry.proposals, proposal_addr);
        (proposal_ref.for_votes, proposal_ref.against_votes)
    }

    /// Check if an address has voted on a proposal
    public fun has_voted(
        registry: &ProposalRegistry,
        proposal_addr: address,
        voter: address
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow(&registry.proposals, proposal_addr);
        table::contains(&proposal_ref.votes, voter)
    }

    /// Get a specific vote (true=for, false=against)
    public fun get_vote(
        registry: &ProposalRegistry,
        proposal_addr: address,
        voter: address
    ): bool {
        assert!(table::contains(&registry.proposals, proposal_addr),
                error::not_found(E_NOT_FOUND));
        let proposal_ref = table::borrow(&registry.proposals, proposal_addr);
        assert!(table::contains(&proposal_ref.votes, voter),
                error::permission_denied(E_NOT_AUTHORIZED));
        *table::borrow(&proposal_ref.votes, voter)
    }

    /// Dummy voting power (replace with actual token balance logic)
    fun get_voting_power(voter: address): u64 {
        if (voter == @0x1) {
            2000000
        } else {
            1000000
        }
    }
}
