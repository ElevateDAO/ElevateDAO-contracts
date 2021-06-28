// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title Account for ETH Management
/// @author ElevateDAO: Research and Development
/// @notice This is a base contract, for managing ether sent to the contract, an hold ERC1155.
/// @dev All variables and functions are marked as internal
contract Account is ERC1155Holder {
    
    event EthDeposited(address indexed from, uint value);
    event EthTransfered(address indexed to, uint value);
    
    modifier Enough_Ether(uint value) {
        require(value <= address(this).balance);
        _;
    }
    
    /// @notice Tranfer ETH from contract to other addresses.
    /// @dev Uses openzeppelin's Address library for moving ETH.
    /// @param value The amount to be transferred
    /// @param to The adddress to transfer ETH to
    function _transfer(uint value, address payable to) internal Enough_Ether(value) {
        emit EthTransfered(to, value);
        Address.sendValue(to, value);
    }
    
    
    /// @notice Generate an arbitrary transaction.
    /// @dev Uses openzeppelin's Address library for calls.
    function _transact(address target, bytes memory data) internal {
        Address.functionCall(target, data);
    }
    
     /// @notice Generate an arbitrary transaction with value.
    /// @dev Uses openzeppelin's Address library for calls.
    function _transact_with_value(address target, bytes memory data, uint value) internal {
        Address.functionCallWithValue(target, data, value);
        emit EthTransfered(target, value);
    }
    
    /// @notice Get contract balance.
    function check_balance() view external returns (uint) {
        return address(this).balance;
    }
    
    /// @notice Function to deposit ETH into the contract
    function deposit() external payable {
        emit EthDeposited(msg.sender, msg.value);
    }
    
    receive() external payable {
        emit EthDeposited(msg.sender, msg.value);
    }
}