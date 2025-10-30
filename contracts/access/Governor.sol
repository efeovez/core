// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Governor {

    /* ================= STATE VARIABLES ================= */

    address private governor;

    /* ================= CONSTRUCTOR ================= */

    constructor() {
        governor = msg.sender;
    }

    /* ================= MODIFIER ================= */

    modifier onlyGovernor() {
        require(msg.sender == governor, "msg.sender is not the governor");
        _;
    }

    /* ================= FUNCTIONS ================= */

    function getGovernor() public view returns(address) {
        return governor;
    }

    function isGovernor() public view returns(bool) {
        return msg.sender == governor;
    }

    function transferGovernor(address newGovernor) public onlyGovernor {
        require(newGovernor != address(0), "zero address given for new governor");

        emit GovernorTransferred(governor, newGovernor);

        governor = newGovernor;
    }

    /* ================= EVENT ================= */

    event GovernorTransferred(address indexed previousGovernor, address indexed newGovernor);
    
}