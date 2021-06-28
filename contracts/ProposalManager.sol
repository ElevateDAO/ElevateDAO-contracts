// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Account.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title Account for ETH Management
/// @author ElevateDAO: Research and Development
/// @notice The proposal manager for voting and retrieving information about proposals
contract ProposalManager is Account {
    
    using EnumerableSet for EnumerableSet.AddressSet;
    
    /// @notice Events
    event ProposalCreated(bytes indexed name, uint16 indexed id, uint8 lifespan, uint timestamp);
    event ProposalRemoved(bytes indexed name, uint16 indexed id);
    event ProposalExecuted(bytes indexed name, uint16 id);
    event VoteCast(bytes indexed name, uint16 indexed id, address indexed voter);
    
    /// @notice Base structure for different proposals, has name, the lifetime of the proposal, and the number of votes
    struct PBase {
        bytes name;
        uint8 lifespan;
        uint16 id;
        uint timestamp;
        uint votes;
        address[] voters;
    }
    
    /// @notice For SubProposalManager to handle paying department members
    struct DistributionProposal {
        PBase base;
        uint amount;
    }
    
    /// @notice A multi-transaction proposal for interacting with other contracts and wallets
    /// @dev Supports an undefined number of transactions
    struct MultiTransactionProposal {
        PBase base;
        address[] targets;
        bytes[] datas;
        uint[] values;
    }
    
    /// @notice A proposal for adding and removing people from the DAO
    /// @dev Each proposal can only either add or remove
    struct ManagementProposal {
        PBase base;
        address[] targets;
        bool adding;
        uint8[] department_ids;
    }
    
    /// @notice A proposal for moving individuals between departments
    /// @dev only supports one person at a time
    struct MoveProposal {
        PBase base;
        address target;
        uint8 old_department_id;
        uint8 new_department_id;
    }
    
    /// @notice Counter for the current proposal
    uint16 current_id = 1;
    
    /// @notice Member list
    EnumerableSet.AddressSet members;
    
    /// @notice Proposal lists
    mapping (uint16 => MultiTransactionProposal) transactions;
    mapping (uint16 => PBase) governance;
    mapping (uint16 => ManagementProposal) management;
    mapping (uint16 => MoveProposal) moves;
    
    /// @notice Only allows DAO members to access certain functions
    modifier onlyMember (address m) {
        require (members.contains(m));
        _;
    }
    
    /// @notice Create a transaction proposal
    /// @param targets The addresses to target in the transactions
    /// @param datas The data for the different transactions
    /// @param values How much eth to send in each transaction
    function create_transaction_proposal(bytes memory name, uint8 lifespan, address[] memory targets, bytes[] memory datas, uint[] memory values) external onlyMember(msg.sender) {
        address[] memory temp;
        transactions[current_id] = MultiTransactionProposal(PBase(name, lifespan, current_id, block.timestamp, 0, temp), targets, datas, values);
        current_id++;
        emit ProposalCreated(name, current_id-1, lifespan, block.timestamp);
    }
    
    /// @notice Creates a simple governance proposal, these are used to decide the direction of the DAO and what projects and research we take on.
    function create_governance_proposal(bytes memory name, uint8 lifespan) external onlyMember(msg.sender) {
        address[] memory temp;
        governance[current_id] = PBase(name, lifespan, current_id, block.timestamp, 0, temp);
        current_id++;
        emit ProposalCreated(name, current_id-1, lifespan, block.timestamp);
    }
    
    /// @notice Create a management proposal
    /// @param targets The people or contracts to either add or remove from the DAO
    /// @param adding Determines whether the targets are being added or removed from the DAO. False is removal.
    /// @param d_ids The departments which the targets are going to be added to
    function create_management_proposal(bytes memory name, uint8 lifespan, address[] memory targets, bool adding, uint8[] memory d_ids) external onlyMember(msg.sender) {
        address[] memory temp;
        management[current_id] = ManagementProposal(PBase(name, lifespan, current_id, block.timestamp, 0, temp), targets, adding, d_ids);
        current_id++;
        emit ProposalCreated(name, current_id-1, lifespan, block.timestamp);
    }
    
    /// @notice Create a move proposal
    /// @param target The DAO member to move
    /// @param old_d_id The member's former department
    /// @param new_d_id The member's new department
    function create_move_proposal(bytes memory name, uint8 lifespan, address target, uint8 old_d_id, uint8 new_d_id) external onlyMember(msg.sender) {
        address[] memory temp;
        moves[current_id] = MoveProposal(PBase(name, lifespan, current_id, block.timestamp, 0, temp), target, old_d_id, new_d_id);
        current_id++;
        emit ProposalCreated(name, current_id-1, lifespan, block.timestamp);
    }
    
    /// @notice A simple function to ensure a list does not contain an item
    /// @dev This function is private and may not be used elsewhere
    function not_contains (address[] memory list, address item) pure private returns (bool) {
        for (uint i = 0; i < list.length; i++) {
            if (list[i] == item)
                return false;
        }
        return true;
    }
    
    /// @notice A function to vote on proposals, finds proposals based on their id
    /// @param id The id to search for
    function vote(uint16 id) external onlyMember(msg.sender) {
        address voter = msg.sender;
        if (transactions[id].base.id != 0) {
            if (not_contains(transactions[id].base.voters, voter)) {
                transactions[id].base.votes++;
                transactions[id].base.voters.push(voter);
                emit VoteCast(transactions[id].base.name, id, voter);
            }
        } else if (governance[id].id != 0) {
            if (not_contains(governance[id].voters, voter)) {
                governance[id].votes++;
                governance[id].voters.push(voter);
                emit VoteCast(transactions[id].base.name, id, voter);
            }
        } else if (management[id].base.id != 0) {
            if (not_contains(management[id].base.voters, voter)) {
                management[id].base.votes++;
                management[id].base.voters.push(voter);
                emit VoteCast(transactions[id].base.name, id, voter);
            }
        } else if (moves[id].base.id != 0) {
            if (not_contains(moves[id].base.voters, voter)) {
                moves[id].base.votes++;
                moves[id].base.voters.push(voter);
                emit VoteCast(transactions[id].base.name, id, voter);
            }
        }
    }
    
    /// @notice Removes any proposal that has expired and exceeded its given lifespan based on id
    function remove_proposal(uint16 id) external onlyMember(msg.sender) returns (bool) {
        if (transactions[id].base.id != 0 && 
            ((block.timestamp - transactions[id].base.timestamp) >= transactions[id].base.lifespan * 1 days)) {
                emit ProposalRemoved(transactions[id].base.name, id);
                delete transactions[id];
                return true;
        } else if (governance[id].id != 0 && 
            ((block.timestamp - governance[id].timestamp) >= governance[id].lifespan * 1 days)) {
                emit ProposalRemoved(transactions[id].base.name, id);
                delete governance[id];
                return true;
        } else if (management[id].base.id != 0 && 
            ((block.timestamp - management[id].base.timestamp) >= management[id].base.lifespan * 1 days)) {
                emit ProposalRemoved(transactions[id].base.name, id);
                delete management[id];
                return true;
        } else if (moves[id].base.id != 0 && 
            ((block.timestamp - moves[id].base.timestamp) >= moves[id].base.lifespan * 1 days)) {
                emit ProposalRemoved(transactions[id].base.name, id);
                delete moves[id];
                return true;
        }
        return false;
    }
    
    /// @notice Return a proposal from the given id
    function get_proposal(uint16 id) view external returns (MultiTransactionProposal memory, PBase memory, ManagementProposal memory, MoveProposal memory) {
        return (transactions[id], governance[id], management[id], moves[id]);
    }
    
    /// @notice See current members of the DAO
    function check_members() view external returns (bytes32[] memory) {
        return members._inner._values;
    }
}