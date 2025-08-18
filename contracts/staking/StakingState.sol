// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../libs/IERC20.sol";
import {SafeERC20} from "../libs/SafeERC20.sol";

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

    struct Staked {
        uint256 amount;
        uint256 unlockTime;
    }

    /* ================= STATE VARIABLES ================= */

    mapping(address => Provider) public providers;

    mapping(address => mapping(address => Delegation)) public delegations;

    mapping(address => Staked) public staked;

    uint256 public lockPeriod = 7 days;

    uint256 public totalStakedSbasis;

    uint256 public totalStakedBasis;

    address[] public allProviders;

    mapping(address => uint256) public claimedProviderRewards;

    mapping(address => mapping(address => uint256)) public claimedDelegatorRewards;

    uint8 public maxProviders = 50;

    using SafeERC20 for IERC20;

    IERC20 public basis;
    IERC20 public sbasis;
}