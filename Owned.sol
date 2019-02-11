pragma solidity ^0.4.24;

/// ----------------------------------------------------------------------------
// Owner contract. Copied from ethereum.org, edited by Pertti Martikainen
// Copyright logistor.
// MIT Licenced.
// ----------------------------------------------------------------------------

contract Owned {
    
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == owner);
        owner = newOwner;
    }
}
