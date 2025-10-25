// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    struct EpochSnapshot {
        uint256 epochNumber;
        uint256 totalRewardPool;
        uint256 totalPower;
        mapping(address => uint256) providerPowerSnapshot;
        mapping(address => mapping(address => uint256)) delegationSnapshot;
        mapping(address => uint256) stakedSnapshot;
        bool calculated;
    }

    /* ================= STATE VARIABLES ================= */

    uint256 public startTime = block.timestamp;

    mapping(uint256 => EpochSnapshot) public epochSnapshots;

    mapping(uint256 => mapping(address => uint256)) public epochProviderRewards;

    mapping(uint256 => mapping(address => mapping(address => uint256))) public epochDelegatorRewards;

    mapping(uint256 => mapping(address => bool)) public providerRewardsClaimed;

    mapping(uint256 => mapping(address => mapping(address => bool))) public delegatorRewardsClaimed;

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

    uint256 public cachedTotalPower;
    uint256 public lastTotalPowerUpdate;

    //

    uint256 public currentEpoch;
    uint256 public epochStartTime;
    
    // Epoch snapshot data
    mapping(uint256 => uint256) public epochTotalPower;
    mapping(uint256 => uint256) public epochTotalReward;
    mapping(uint256 => mapping(address => uint256)) public epochProviderPower;
    mapping(uint256 => mapping(address => uint256)) public epochProviderStake;
    mapping(uint256 => mapping(address => mapping(address => uint256))) public epochDelegatorAmount;
    
    // Last claimed epoch per user
    mapping(address => uint256) public lastClaimedProviderEpoch;
    mapping(address => mapping(address => uint256)) public lastClaimedDelegatorEpoch;

    uint256 public constant EPOCH_DURATION = 3 minutes; // for test

    uint256 public totalPower;

    mapping(address => uint256) public providerWithdrawnRewards;
    mapping(address => mapping(address => uint256)) public delegatorWithdrawnRewards;
}