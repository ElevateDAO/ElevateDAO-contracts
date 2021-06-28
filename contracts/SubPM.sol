// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./ProposalManager.sol";

/// @title Account for ETH Management
/// @author ElevateDAO: Research and Development
/// @notice The SubProposalManager for individual departments
/// @dev This contract currently reimplements a function that is in ProposalManager.sol called not_contains
library SubPM {
    
    /// @notice Events
    event ProposalCreated(bytes indexed name, uint16 indexed id, uint8 lifespan, uint timestamp);
    event ProposalRemoved(bytes indexed name, uint16 indexed id);
    event VoteCast(bytes indexed name, uint16 indexed id, address indexed voter);
    
    /// @notice The ProposalManager for departments
    struct SubProposalManager {
        uint16 current_id;
        mapping (uint16 => ProposalManager.MultiTransactionProposal) transactions;
        mapping (uint16 => ProposalManager.DistributionProposal) distributions;
    }
    
    /// @notice Create a transaction proposal
    /// @param targets The addresses to target in the transactions
    /// @param datas The data for the different transactions
    /// @param values How much eth to send in each transaction
    function create_transaction_proposal(SubProposalManager storage spm, bytes memory name, uint8 lifespan, address[] memory targets, bytes[] memory datas, uint[] memory values) internal {
        address[] memory temp;
        spm.transactions[spm.current_id] = ProposalManager.MultiTransactionProposal(ProposalManager.PBase(name, lifespan, spm.current_id, block.timestamp, 0, temp), targets, datas, values);
        spm.current_id++;
        emit ProposalCreated(name, spm.current_id-1, lifespan, block.timestamp);
    }
    
    /// @notice Create a distribution proposal
    /// @param amount The amount to be distributed amongst the department members
    function create_distribution_proposal(SubProposalManager storage spm, bytes memory name, uint8 lifespan, uint amount) internal {
        address[] memory temp;
        spm.distributions[spm.current_id] = ProposalManager.DistributionProposal(ProposalManager.PBase(name, lifespan, spm.current_id, block.timestamp, 0, temp), amount);
        spm.current_id++;
        emit ProposalCreated(name, spm.current_id-1, lifespan, block.timestamp);
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
    function vote(SubProposalManager storage spm, uint16 id, address voter) internal {
        if (spm.transactions[id].base.id != 0) {
            if (not_contains(spm.transactions[id].base.voters, voter)) {
                spm.transactions[id].base.votes++;
                spm.transactions[id].base.voters.push(voter);
                emit VoteCast(spm.transactions[id].base.name, id, voter);
            }
        } else if (spm.distributions[id].base.id != 0) {
            if (not_contains(spm.distributions[id].base.voters, voter)) {
                spm.distributions[id].base.votes++;
                spm.distributions[id].base.voters.push(voter);
                emit VoteCast(spm.distributions[id].base.name, id, voter);
            }
        }
    }
    
    /// @notice Removes any proposal that has expired and exceeded its given lifespan based on id
    function remove_proposal (SubProposalManager storage spm, uint16 id) internal returns (bool) {
        if (spm.transactions[id].base.id != 0 && 
            ((block.timestamp - spm.transactions[id].base.timestamp) >= spm.transactions[id].base.lifespan * 1 days)) {
                emit ProposalRemoved(spm.transactions[id].base.name, id);
                delete spm.transactions[id];
                return true;
        } else if (spm.distributions[id].base.id != 0 && 
            ((block.timestamp - spm.distributions[id].base.timestamp) >= spm.distributions[id].base.lifespan * 1 days)) {
                emit ProposalRemoved(spm.distributions[id].base.name, id);
                delete spm.distributions[id];
                return true;
        }
        return false;
    }
    
    /// @notice Return a proposal from the given id
    function get_proposal(SubProposalManager storage spm, uint16 id) view internal returns (ProposalManager.MultiTransactionProposal memory, ProposalManager.DistributionProposal memory) {
        return (spm.transactions[id], spm.distributions[id]);
    }
}