// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingState {

    /* ================= STRUCT ================= */

    struct Provider {
        address providerAddress;
        string description;
        uint8 commission;
        uint256 power;
    }

    /* ================= STATE VARIABLES ================= */

    mapping(address => Provider) public providers;

    uint256 public totalStaked;
}