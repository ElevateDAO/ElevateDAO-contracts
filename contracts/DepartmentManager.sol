// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./ProposalManager.sol";
import "./SubPM.sol";
import "./SubManager.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title Account for ETH Management
/// @author ElevateDAO: Research and Development
/// @notice This is department manager for the DAO and decides how members are ordered on-chain
/// @dev This contracts and some of its previous ones depend on openzeppelin contracts
contract DepartmentManager is Account, ProposalManager {
    
    using EnumerableSet for EnumerableSet.AddressSet;
    using SubPM for SubPM.SubProposalManager;
    
    /// @notice The standard department structure consisting of a SubManager, SubProposalManager, and member list
    struct Department {
        bytes32 name;
        EnumerableSet.AddressSet members;
        SubManager sm;
        SubPM.SubProposalManager spm;
    }
    
    /// @notice Four Departments: Researach & Development, Finance, Legal, and Public Outreach
    Department[4] private _departments;
    
    /// @notice Mappings that track executed proposals
    mapping (uint16 => bool) passed_proposals;
    mapping (uint => mapping (uint16 => bool)) passed_department_proposals;
    
    /// @notice Used to prevent departments from interfering with one another
    modifier onlyDepartmentMember(address m, uint d_id) {
        require(_departments[d_id].members.contains(m));
        _;
    }
    
    constructor() {
        _departments[0].name = "Research & Development";
        _departments[1].name = "Finance";
        _departments[2].name = "Legal";
        _departments[3].name = "Public Outreach";
        
        for (uint i = 0; i < 4; i++) {
            _departments[i].sm = new SubManager();
            _departments[i].spm.current_id++;
        }
        
        members.add(msg.sender);
        _departments[0].members.add(msg.sender);
    }
    
    /// @notice Executes a DAO-wide proposal that has been voted ond passed
    /// @param id The id of the proposal to execute
    function execute(uint16 id) external {
        require(passed_proposals[id] == false);
        if (transactions[id].base.id != 0 && transactions[id].base.votes > members.length()/2) {
            MultiTransactionProposal storage temp = transactions[id];
            passed_proposals[id] = true;
            for (uint i = 0; i < temp.targets.length; i++) {
                if (temp.datas[i].length == 0) {
                    _transfer(temp.values[i], payable(temp.targets[i]));
                } else {
                    _transact_with_value(temp.targets[i], temp.datas[i], temp.values[i]);
                }
            }
            emit ProposalExecuted(temp.base.name, temp.base.id);
        } else if (management[id].base.id != 0 && management[id].base.votes > members.length()/2) {
            ManagementProposal storage temp = management[id];
            passed_proposals[id] = true;
            if (temp.adding) {
                for (uint i = 0; i < temp.targets.length; i++) {
                    members.add(temp.targets[i]);
                    _departments[temp.department_ids[i]].members.add(temp.targets[i]);
                }
            } else {
                for (uint i = 0; i < temp.targets.length; i++) {
                    members.remove(temp.targets[i]);
                    _departments[temp.department_ids[i]].members.remove(temp.targets[i]);
                }
            }
            emit ProposalExecuted(temp.base.name, temp.base.id);
        } else if (moves[id].base.id != 0 && moves[id].base.votes > members.length()/2) {
            MoveProposal storage temp = moves[id];
            passed_proposals[id] = true;
            _departments[temp.old_department_id].members.remove(temp.target);
            _departments[temp.new_department_id].members.add(temp.target);
            emit ProposalExecuted(temp.base.name, temp.base.id);
        } else if (governance[id].votes > members.length()/2) {
            passed_proposals[id] = true;
            emit ProposalExecuted(governance[id].name, governance[id].id);
        }
    }
    
    /// @notice Executes a department-contained proposal for distribution or transacting
    /// @param d_id The department that contains the proposal
    /// @param p_id The id of the proposal to exectute
    function execute_department_proposal(uint d_id, uint16 p_id) external {
        require(passed_department_proposals[d_id][p_id] == false);
        if (_departments[d_id].spm.transactions[p_id].base.id != 0 && 
        _departments[d_id].spm.transactions[p_id].base.votes > _departments[d_id].members.length()/2) {
            MultiTransactionProposal storage temp = _departments[d_id].spm.transactions[p_id];
            passed_department_proposals[d_id][p_id] = true;
            for (uint i = 0; i < temp.targets.length; i++) {
                if (temp.datas[i].length == 0) {
                    _transfer(temp.values[i], payable(temp.targets[i]));
                } else {
                    _transact_with_value(temp.targets[i], temp.datas[i], temp.values[i]);
                }
            }
            emit ProposalExecuted(temp.base.name, temp.base.id);
        } else if (_departments[d_id].spm.distributions[p_id].base.id != 0 && 
        _departments[d_id].spm.distributions[p_id].base.votes > _departments[d_id].members.length()/2) {
            DistributionProposal storage temp = _departments[d_id].spm.distributions[p_id];
            passed_department_proposals[d_id][p_id] = true;
            address[] memory m = new address[](_departments[d_id].members.length());
            for (uint i = 0; i < _departments[d_id].members.length(); i++) {
                m[i] = _departments[d_id].members.at(i);
            }
            _departments[d_id].sm.distribute(m, temp.amount);
            emit ProposalExecuted(temp.base.name, temp.base.id);
        }
    }
    
    /// @notice Create a transacting proposal in a department
    function create_department_tproposal(uint d_id, bytes memory name, uint8 lifespan, address[] memory targets, bytes[] memory datas, uint[] memory values) external onlyDepartmentMember(msg.sender, d_id) {
        _departments[d_id].spm.create_transaction_proposal(name, lifespan, targets, datas, values);
    }
    
    /// @notice Create a distribution proposal in a department
    function create_department_dproposal(uint d_id, bytes memory name, uint8 lifespan, uint amount) external onlyDepartmentMember(msg.sender, d_id) {
        _departments[d_id].spm.create_distribution_proposal(name, lifespan, amount);
    }
    
    /// @notice Vote for proposal contained in a department
    function department_vote(uint d_id, uint16 p_id) external onlyDepartmentMember(msg.sender, d_id) {
        _departments[d_id].spm.vote(p_id, msg.sender);
    }
    
    /// @notice Remove a proposal contained in a department that has expired
    function remove_department_proposal(uint d_id, uint16 p_id) external onlyDepartmentMember(msg.sender, d_id) {
        _departments[d_id].spm.remove_proposal(p_id);
    }
    
    /// @notice Get information about a particular department
    function get_department_info(uint d_id) view external returns (bytes32, address, address[] memory) {
        address[] memory m = new address[](_departments[d_id].members.length());
        for (uint i = 0; i < _departments[d_id].members.length(); i++) {
            m[i] = _departments[d_id].members.at(i);
        }
        return (_departments[d_id].name, address(_departments[d_id].sm), m);
    }
    
    /// Get a department-contained proposal
    function get_department_proposal(uint d_id, uint16 p_id) view external returns (MultiTransactionProposal memory, DistributionProposal memory) {
        return _departments[d_id].spm.get_proposal(p_id);
    }
    
    function is_department_member(uint d_id, address m) view external returns (bool) {
        if (_departments[d_id].members.contains(m)) {
            return true;
        }
        return false;
    }
}