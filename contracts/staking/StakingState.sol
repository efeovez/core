// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingState {

    using SafeERC20 for IERC20;

    /* ================= STATE VARIABLES ================= */

    IERC20 public lpBasis;

    struct Provider {
        address providerAddr;
        string description;
        uint8 commission;
        uint256 power;
        uint256 rewardPerLpBasisStored;
        uint256 rewardRate;
        uint256 commissionRewards;
        uint256 periodFinish;
        uint256 lastUpdateTime;
        uint8 oldCommission;
        uint256 newCommissionUpdateTime;
        uint256 commissionUpdateLock;
    }

    address[] public allProviders;

    uint8 public maxProviders = 50;

    mapping(address => Provider) public providers;

    struct Delegation {
        uint256 share;
        uint256 unlockTime;
        address provider;
        uint256 rewards;
        uint256 userRewardPerLpBasisPaid;
        uint256 delegationTime;
    }

    mapping(address => mapping(address => Delegation)) public delegations;

    uint256 public lockPeriod = 21 days;

    uint256 public totalShare;

    uint256 public commissionUpdateLock = 63 days;
}