// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../libs/IERC20.sol";
import {SafeERC20} from "../libs/SafeERC20.sol";
import {StakingState} from "./StakingState.sol";
import {StakingSetters} from "./StakingSetters.sol";

contract Staking is StakingState, StakingSetters {

    /* ================= STATE VARIABLES ================= */

    using SafeERC20 for IERC20;

    IERC20 public basis;
    IERC20 public sbasis;

    /* ================= CONSTRUCTOR ================= */

    constructor(address basisAddress, address sbasisAddress) {
        basis = IERC20(basisAddress);
        sbasis = IERC20(sbasisAddress);
    }

    /* ================= FUNCTIONS ================ */

    function createProvider(string memory description, uint8 commission) public {
        require(bytes(description).length < 50, "basis.staking.Staking.createProvider(): description_ must be under 50 characters");
        require(commission <= 100, "basis.staking.Staking.createProvider(): commission_ must not exceed 100");
        require(providers[msg.sender].providerAddress == address(0), "basis.staking.Staking.createProvider(): provider already exists");

        providers[msg.sender] = Provider({
            providerAddress: msg.sender,
            description: description,
            commission: commission,
            power: 0
        });

        allProviders.push(msg.sender);

        emit ProviderCreated(msg.sender, description, commission);
    }

    function editProvider(string memory description, uint8 commission) public {
        require(bytes(description).length < 50, "basis.staking.Staking.editProvider(): description_ must be under 50 characters");
        require(commission <= 100, "basis.staking.Staking.editProvider(): commission_ must not exceed 100");
        require(msg.sender == providers[msg.sender].providerAddress, "basis.staking.Staking.editProvider(): provider not registered");

        Provider storage providerWrapper = providers[msg.sender];

        providerWrapper.description = description;
        providerWrapper.commission = commission;

        emit ProviderEdited(msg.sender, description, commission);
    }

    function delegate(address provider, uint256 amount) public {
        require(sbasis.allowance(msg.sender, address(this)) >= amount, "basis.staking.Staking.delegate(): approved amount is not sufficient");
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.delegate(): provider not registered");
        require(amount > 0, "basis.staking.Staking.delegate(): you cannot delegate zero");

        sbasis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power += amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount += amount;
        delegationWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedSbasis += amount;

        emit Delegated(msg.sender, provider, amount);
    }

    function undelegate(address provider, uint256 amount) public {
        require(delegations[msg.sender][provider].amount >= amount, "basis.staking.Staking.undelegate(): amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.delegate(): provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "basis.staking.Staking.undelegate(): you do not have an existing delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "basis.staking.Staking.undelegate(): your token is locked");

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power -= amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount -= amount;

        totalStakedSbasis -= amount;

        sbasis.safeTransfer(msg.sender, amount);

        emit Undelegated(msg.sender, provider, amount);
    }

    function stake(uint256 amount) public {
        require(basis.allowance(msg.sender, address(this)) >= amount, "basis.staking.Staking.stake(): approved amount is not sufficient");
        require(providers[msg.sender].providerAddress != address(0), "basis.staking.Staking.stake(): provider not registered");
        require(amount > 0, "basis.staking.Staking.stake(): you cannot stake zero");

        basis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage providerWrapper = providers[msg.sender];
        providerWrapper.power += amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount += amount;
        stakedWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedBasis += amount;

        emit ProviderStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(staked[msg.sender].amount >= amount, "basis.staking.Staking.unstake(): amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[msg.sender].providerAddress != address(0), "basis.staking.Staking.unstake(): provider not registered");
        require(staked[msg.sender].amount > 0, "basis.staking.Staking.unstake(): you do not have an existing delegation");
        require(block.timestamp >= staked[msg.sender].unlockTime, "basis.staking.Staking.unstake(): your token is locked");

        Provider storage providerWrapper = providers[msg.sender];
        providerWrapper.power -= amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount -= amount;

        totalStakedBasis -= amount;

        basis.safeTransfer(msg.sender, amount);

        emit ProviderUnstaked(msg.sender, amount);
    }

    function getTotalReward() public view returns(uint256) { 
        return basis.balanceOf(address(this)) - totalStakedBasis;
    }

    function calculateProviderReward(address provider) public view returns(uint256) {
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.calculateProviderReward(): provider not registered");

        uint256 totalPower;
        for (uint256 i = 0; i < allProviders.length; i++) {
        totalPower += providers[allProviders[i]].power;
        }
        if (totalPower == 0) return 0;

        uint256 providerTotalReward = (providers[provider].power * getTotalReward()) / totalPower;

        uint256 providerSelfStake = staked[provider].amount;

        uint256 providerSelfReward = (providerSelfStake * providerTotalReward) / providers[provider].power;

        uint256 commissionReward = ((providerTotalReward - providerSelfReward) * providers[provider].commission) / 100;

        return providerSelfReward + commissionReward;
    }

    function calculateDelegatorReward(address delegator, address provider) public view returns(uint256) {
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.calculateDelegatorReward(): provider not registered");

        Delegation memory delegationWrapper = delegations[delegator][provider];
        if (delegationWrapper.amount == 0) return 0;

        uint256 totalPower;
        for (uint256 i = 0; i < allProviders.length; i++) {
            totalPower += providers[allProviders[i]].power;
        }
        if (totalPower == 0) return 0;

        uint256 providerTotalReward = (providers[provider].power * getTotalReward()) / totalPower;

        uint256 providerSelfStake = staked[provider].amount;

        uint256 providerSelfReward = (providerSelfStake * providerTotalReward) / providers[provider].power;
        uint256 commissionReward = ((providerTotalReward - providerSelfReward) * providers[provider].commission) / 100;
        uint256 rewardAfterCommission = providerTotalReward - providerSelfReward - commissionReward;

        return (delegationWrapper.amount * rewardAfterCommission) / (providers[provider].power - providerSelfStake);
    }

    function withdrawProviderReward() public {
        require(providers[msg.sender].providerAddress != address(0), "basis.staking.Staking.withdrawProviderReward(): provider not registered");
        require(block.timestamp >= staked[msg.sender].unlockTime, "basis.staking.Staking.withdrawProviderReward(): your token is locked");

        uint256 totalRewardEarned = calculateProviderReward(msg.sender);
        uint256 rewardToClaim = totalRewardEarned - claimedProviderRewards[msg.sender];
        require(rewardToClaim > 0, "no reward");

        claimedProviderRewards[msg.sender] += rewardToClaim;
        basis.safeTransfer(msg.sender, rewardToClaim);

        emit WithdrawProviderReward(msg.sender, rewardToClaim);
    }

    function withdrawDelegatorReward(address provider) public {
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.withdrawProviderReward(): provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "no delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "basis.staking.Staking.wihdrawDelegatorReward(): your token is locked");

        uint256 totalRewardEarned = calculateDelegatorReward(msg.sender, provider);
        uint256 rewardToClaim = totalRewardEarned - claimedDelegatorRewards[msg.sender][provider];
        require(rewardToClaim > 0, "no reward");

        claimedDelegatorRewards[msg.sender][provider] += rewardToClaim;
        basis.safeTransfer(msg.sender, rewardToClaim);

        emit WithdrawDelegatorReward(msg.sender, rewardToClaim);
    }

    /* ================= EVENT ================= */

    event ProviderCreated(address indexed provider, string indexed description, uint8 indexed commission);

    event ProviderEdited(address indexed provider, string indexed description, uint8 indexed commission);

    event Delegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event Undelegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event ProviderStaked(address indexed provider, uint256 indexed amount);

    event ProviderUnstaked(address indexed provider, uint256 indexed amount);

    event WithdrawProviderReward(address indexed provider, uint256 indexed amount);

    event WithdrawDelegatorReward(address indexed delegator, uint256 indexed amount);
}