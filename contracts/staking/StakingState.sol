// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingState {

    /* ================= STRUCTS ================= */

    struct Provider {
        address providerAddress;
        string description;
        uint8 commission;
        uint256 power;
    }

    struct Delegation {
    uint256 amount;
    uint256 unlockTime;
    }

    /* ================= STATE VARIABLES ================= */

    mapping(address => Provider) public providers;

    mapping(address => mapping(address => Delegation)) public delegations;

    uint256 public constant LOCK_PERIOD = 21 days;

    uint256 public totalStakedSbasis;

    uint256 public totalStakedBasis;
}