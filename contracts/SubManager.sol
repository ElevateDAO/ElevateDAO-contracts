// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./Account.sol";

/// @title Account for ETH Management
/// @author ElevateDAO: Research and Development
/// @notice This the funds and transaction manager for individual departments
/// @dev This an independent contract this is owned by the main contract
contract SubManager is Account {
    
    /// @notice Owner of the SubManager is the main DAO contract
    address private _owner;
    
    modifier onlyOwner() {
        require(owner() == msg.sender, "Owned: caller is not the owner");
        _;
    }
    
    /// @notice Distributes funds to all members of the department that owns this contract
    function distribute(address[] memory members, uint total_amount) external onlyOwner {
        uint amount_to_each = total_amount/ members.length;
        for (uint i = 0; i < members.length; i++) {
            _transfer(amount_to_each, payable(members[i]));
        }
    }
    
    /// @notice Arbitrary transanctions for each department
    function transact(address[] memory targets, bytes[] memory data, uint[] memory values) external onlyOwner {
        for (uint i = 0; i < targets.length; i++) {
            _transact_with_value(targets[i], data[i], values[i]);
        }
    }
    
    /// @notice Get current owner
    function owner() public view returns (address) {
        return _owner;
    }
}