// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StakingState} from "./StakingState.sol";
import {Operator} from "../access/Operator.sol";
import {StakingGovernor} from "./StakingGovernor.sol";

contract Staking is StakingState, StakingGovernor, ReentrancyGuard, Operator {

    using SafeERC20 for IERC20;

    /* ================= CONSTRUCTOR ================= */

    constructor(address lpBasisAddr) {
        lpBasis = IERC20(lpBasisAddr);
    }

    function createProvider(string memory description, uint8 commission) public {
        require(bytes(description).length < 50, "description must be under 50 characters");
        require(commission <= 100, "commission must not exceed 100");
        require(providers[msg.sender].providerAddr == address(0), "provider already exists");
        require(allProviders.length < maxProviders, "max provider limit reached");

        providers[msg.sender] = Provider({
            providerAddr: msg.sender,
            description: description,
            commission: commission,
            power: 0,
            rewardPerLpBasisStored: 0,
            rewardRate: 0,
            commissionRewards: 0,
            periodFinish: 0,
            lastUpdateTime: 0
        });

        allProviders.push(msg.sender);

        emit ProviderCreated(msg.sender, description, commission);
    }

    function editProvider(string memory description, uint8 commission) public {
        require(bytes(description).length < 50, "description must be under 50 characters");
        require(commission <= 100, "commission must not exceed 100");
        require(providers[msg.sender].providerAddr != address(0), "provider not registered");

        Provider storage providerWrapper = providers[msg.sender];

        providerWrapper.description = description;
        providerWrapper.commission = commission;

        emit ProviderEdited(msg.sender, description, commission);
    }

    /* ================= DELEGATION FUNCTIONS ================ */

    function delegate(address provider, uint256 amount) public updateReward(msg.sender, provider) nonReentrant {
        require(lpBasis.allowance(msg.sender, address(this)) >= amount, "approved amount is not sufficient");
        require(providers[provider].providerAddr != address(0), "provider not registered");
        require(amount > 0, "you cannot delegate zero");

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power += amount;

        delegations[msg.sender][provider].unlockTime = block.timestamp + lockPeriod;
        delegations[msg.sender][provider].provider = provider;
        delegations[msg.sender][provider].share += amount;

        totalShare += amount;

        lpBasis.safeTransferFrom(msg.sender, address(this), amount);

        emit Delegated(msg.sender, provider, amount);
    }

    function undelegate(address provider) public updateReward(msg.sender, provider) nonReentrant {
        require(providers[provider].providerAddr != address(0), "provider not registered");
        require(delegations[msg.sender][provider].share > 0, "you do not have an existing delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "your token is locked");

        uint256 amount = delegations[msg.sender][provider].share;

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power -= amount;

        delete delegations[msg.sender][provider];

        totalShare -= amount;

        lpBasis.safeTransfer(msg.sender, amount);

        emit Undelegated(msg.sender, provider, amount);
    }

    /* ================= REWARD WITHDRAWAL ================ */

    function lastTimeRewardApplicable(address provider) public view returns (uint256) {
        return block.timestamp < providers[provider].periodFinish ? block.timestamp : providers[provider].periodFinish;
    }

    function rewardPerLpBasis(address provider) public view returns (uint256) {
        Provider storage providerWrapper = providers[provider];

        if (providerWrapper.power == 0) {
            return providerWrapper.rewardPerLpBasisStored;
        }
        uint256 delta = lastTimeRewardApplicable(provider) - providerWrapper.lastUpdateTime;
        return providerWrapper.rewardPerLpBasisStored + (delta * providerWrapper.rewardRate * 1e18) / providerWrapper.power;
    }

    function earned(address delegator, address provider) public view returns (uint256) {
        Delegation storage delegationWrapper = delegations[delegator][provider];
        uint256 rewardPerLpBasis_ = rewardPerLpBasis(provider);

        return ((delegationWrapper.share * (rewardPerLpBasis_ - delegationWrapper.userRewardPerLpBasisPaid)) / 1e18 + delegationWrapper.rewards);
    }

    function getRewardForDuration(address provider) external view returns (uint256) {
        return providers[provider].rewardRate * (lockPeriod);
    }

    function withdrawDelegatorReward(address provider) public updateReward(msg.sender, provider) nonReentrant {
        require(providers[provider].providerAddr != address(0), "provider not registered");
        require(delegations[msg.sender][provider].share > 0, "no delegation");

        uint256 grossReward = delegations[msg.sender][provider].rewards;
        uint256 providerCommission = (grossReward * providers[provider].commission) / 100;
        uint256 netReward = grossReward - providerCommission;

        delegations[msg.sender][provider].rewards = 0;

        if (providerCommission > 0) {
            providers[provider].commissionRewards += providerCommission;
        }

        if (netReward > 0) {
            lpBasis.safeTransfer(msg.sender, netReward);
        }

        emit WithdrawDelegatorReward(msg.sender, provider, netReward);
    }

    function notifyRewardAmount(uint256 reward, address provider) external onlyOperator updateReward(address(0), provider) {
        require(providers[provider].power > 0, "provider power must be greater than 0");
        if (block.timestamp >= providers[provider].periodFinish) {
            providers[provider].rewardRate = reward / (lockPeriod);
        } else {
            uint256 remaining = providers[provider].periodFinish - block.timestamp;
            uint256 leftover = remaining * providers[provider].rewardRate;
            providers[provider].rewardRate = (reward + leftover) / (lockPeriod);
        }

        uint256 balance = (lpBasis.balanceOf(address(this)) - totalShare);
        require(providers[provider].rewardRate <= balance / (lockPeriod), "provided reward too high");

        providers[provider].lastUpdateTime = block.timestamp;
        providers[provider].periodFinish = block.timestamp + (lockPeriod);
        emit RewardAdded(provider, reward);
    }

    function withdrawProviderCommission() public nonReentrant {
        require(providers[msg.sender].providerAddr != address(0), "provider not registered");
        require(providers[msg.sender].commissionRewards > 0, "no commission to withdraw");

        uint256 commissionReward = providers[msg.sender].commissionRewards;
        providers[msg.sender].commissionRewards = 0;

        lpBasis.safeTransfer(msg.sender, commissionReward);

        emit WithdrawProviderCommission(msg.sender, commissionReward);
    }

    function getProvider(address provider) public view returns(address providerAddress) {
        return providers[provider].providerAddr;
    }

    /* ================= MODIFIER ================ */

    modifier updateReward(address delegator, address provider) {
        providers[provider].rewardPerLpBasisStored = rewardPerLpBasis(provider);
        providers[provider].lastUpdateTime = lastTimeRewardApplicable(provider);
        if (delegator != address(0)) {
            delegations[delegator][provider].rewards = earned(delegator, provider);
            delegations[delegator][provider].userRewardPerLpBasisPaid = providers[provider].rewardPerLpBasisStored;
        }
        _;
    }

    /* ================= EVENTS ================= */

    event ProviderCreated(address indexed provider, string description, uint8 commission);

    event ProviderEdited(address indexed provider, string description, uint8 commission);

    event Delegated(address indexed delegator, address indexed provider, uint256 amount);

    event Undelegated(address indexed delegator, address indexed provider, uint256 amount);

    event WithdrawDelegatorReward(address indexed delegator, address indexed provider, uint256 amount);

    event RewardAdded(address indexed provider, uint256 reward);

    event WithdrawProviderCommission(address indexed provider, uint256 amount);
}