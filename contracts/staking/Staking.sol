// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StakingState} from "./StakingState.sol";
import {StakingSetters} from "./StakingSetters.sol";

contract Staking is StakingState, StakingSetters, ReentrancyGuard {

    using SafeERC20 for IERC20;

    /* ================= CONSTRUCTOR ================= */

    constructor(address basisAddress, address sbasisAddress) {
        basis = IERC20(basisAddress);
        sbasis = IERC20(sbasisAddress);
        epochStartTime = block.timestamp;
        currentEpoch = 0;
    }

    /* ================= EPOCH MANAGEMENT ================= */

    modifier autoUpdateEpoch() {
        _updateEpochIfNeeded();
        _;
    }

    function _updateEpochIfNeeded() internal {
        uint256 epochsPassed = (block.timestamp - epochStartTime) / EPOCH_DURATION;
        
        if (epochsPassed > 0) {
            _finalizeEpoch(currentEpoch);
            
            currentEpoch += epochsPassed;
            epochStartTime += (epochsPassed * EPOCH_DURATION);
            
            emit EpochAdvanced(currentEpoch, epochStartTime);
        }
    }

    function _finalizeEpoch(uint256 epoch) internal {
        epochTotalReward[epoch] = getTotalReward();
        
        uint256 totalPower;
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            uint256 power = providers[provider].power;
            
            epochProviderPower[epoch][provider] = power;
            epochProviderStake[epoch][provider] = staked[provider].amount;
            totalPower += power;
        }
        
        epochTotalPower[epoch] = totalPower;
        
        emit EpochFinalized(epoch, totalPower, epochTotalReward[epoch]);
    }

    function manualUpdateEpoch() external {
        _updateEpochIfNeeded();
    }

    /* ================= PROVIDER FUNCTIONS ================ */

    function createProvider(string memory description, uint8 commission) public autoUpdateEpoch {
        require(bytes(description).length < 50, "basis.createProvider: description must be under 50 characters");
        require(commission <= 100, "basis.createProvider: commission must not exceed 100");
        require(providers[msg.sender].providerAddress == address(0), "basis.createProvider: provider already exists");
        require(allProviders.length < maxProviders, "basis.createProvider: max provider limit reached");

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
        require(bytes(description).length < 50, "basis.editProvider: description must be under 50 characters");
        require(commission <= 100, "basis.editProvider: commission must not exceed 100");
        require(msg.sender == providers[msg.sender].providerAddress, "basis.editProvider: provider not registered");

        Provider storage providerWrapper = providers[msg.sender];

        providerWrapper.description = description;
        providerWrapper.commission = commission;

        emit ProviderEdited(msg.sender, description, commission);
    }

    /* ================= DELEGATION FUNCTIONS ================ */

    function delegate(address provider, uint256 amount) public autoUpdateEpoch {
        require(sbasis.allowance(msg.sender, address(this)) >= amount, "basis.delegate: approved amount is not sufficient");
        require(providers[provider].providerAddress != address(0), "basis.delegate: provider not registered");
        require(amount > 0, "basis.delegate: you cannot delegate zero");

        sbasis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power += amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount += amount;
        delegationWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedSbasis += amount;

        emit Delegated(msg.sender, provider, amount);
    }

    function undelegate(address provider, uint256 amount) public nonReentrant autoUpdateEpoch {
        require(delegations[msg.sender][provider].amount >= amount, "basis.undelegate: amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[provider].providerAddress != address(0), "basis.delegate: provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "basis.undelegate: you do not have an existing delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "basis.undelegate: your token is locked");

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power -= amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount -= amount;

        totalStakedSbasis -= amount;

        sbasis.safeTransfer(msg.sender, amount);

        emit Undelegated(msg.sender, provider, amount);
    }

    /* ================= STAKING FUNCTIONS ================ */

    function stake(uint256 amount) public autoUpdateEpoch {
        require(basis.allowance(msg.sender, address(this)) >= amount, "basis.stake: approved amount is not sufficient");
        require(providers[msg.sender].providerAddress != address(0), "basis.stake: provider not registered");
        require(amount > 0, "basis.stake: you cannot stake zero");

        basis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage providerWrapper = providers[msg.sender];
        providerWrapper.power += amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount += amount;
        stakedWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedBasis += amount;

        emit ProviderStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) public nonReentrant autoUpdateEpoch {
        require(staked[msg.sender].amount >= amount, "basis.unstake: amount you wish to unstake must be less than or equal to the amount you have staked");
        require(providers[msg.sender].providerAddress != address(0), "basis.unstake: provider not registered");
        require(staked[msg.sender].amount > 0, "basis.unstake: you do not have an existing delegation");
        require(block.timestamp >= staked[msg.sender].unlockTime, "basis.unstake: your token is locked");

        Provider storage providerWrapper = providers[msg.sender];
        providerWrapper.power -= amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount -= amount;

        totalStakedBasis -= amount;

        basis.safeTransfer(msg.sender, amount);

        emit ProviderUnstaked(msg.sender, amount);
    }

    /* ================= REWARD CALCULATION ================ */

    function getTotalReward() public view returns(uint256) { 
        return basis.balanceOf(address(this)) - totalStakedBasis;
    }

    function calculateProviderRewardForEpoch(address provider, uint256 epoch) public view returns(uint256) {
        require(epoch < currentEpoch, "epoch not finalized");
        require(providers[provider].providerAddress != address(0), "provider not registered");

        uint256 totalPower = epochTotalPower[epoch];
        if (totalPower == 0) return 0;

        uint256 providerPower = epochProviderPower[epoch][provider];
        if (providerPower == 0) return 0;

        uint256 totalReward = epochTotalReward[epoch];
        uint256 providerTotalReward = (providerPower * totalReward) / totalPower;

        uint256 providerSelfStake = epochProviderStake[epoch][provider];
        uint256 providerSelfReward = (providerSelfStake * providerTotalReward) / providerPower;

        uint256 commission = providers[provider].commission;
        uint256 commissionReward = ((providerTotalReward - providerSelfReward) * commission) / 100;

        return providerSelfReward + commissionReward;
    }

    function calculateDelegatorRewardForEpoch(address delegator, address provider, uint256 epoch) public view returns(uint256) {
        require(epoch < currentEpoch, "epoch not finalized");
        require(providers[provider].providerAddress != address(0), "provider not registered");

        uint256 totalPower = epochTotalPower[epoch];
        if (totalPower == 0) return 0;

        uint256 providerPower = epochProviderPower[epoch][provider];
        if (providerPower == 0) return 0;

        uint256 delegatorAmount = delegations[delegator][provider].amount;
        if (delegatorAmount == 0) return 0;

        uint256 totalReward = epochTotalReward[epoch];
        uint256 providerTotalReward = (providerPower * totalReward) / totalPower;

        uint256 providerSelfStake = epochProviderStake[epoch][provider];
        uint256 providerSelfReward = (providerSelfStake * providerTotalReward) / providerPower;

        uint256 commission = providers[provider].commission;
        uint256 commissionReward = ((providerTotalReward - providerSelfReward) * commission) / 100;

        uint256 rewardAfterCommission = providerTotalReward - providerSelfReward - commissionReward;
        uint256 delegatedPower = providerPower - providerSelfStake;

        if (delegatedPower == 0) return 0;

        return (delegatorAmount * rewardAfterCommission) / delegatedPower;
    }

    function getPendingProviderRewards(address provider) public view returns(uint256) {
        uint256 totalReward;
        uint256 lastClaimed = lastClaimedProviderEpoch[provider];
        
        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            totalReward += calculateProviderRewardForEpoch(provider, epoch);
        }
        
        return totalReward;
    }

    function getPendingDelegatorRewards(address delegator, address provider) public view returns(uint256) {
        uint256 totalReward;
        uint256 lastClaimed = lastClaimedDelegatorEpoch[delegator][provider];
        
        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            totalReward += calculateDelegatorRewardForEpoch(delegator, provider, epoch);
        }
        
        return totalReward;
    }

    /* ================= REWARD WITHDRAWAL ================ */

    function withdrawProviderReward() public nonReentrant autoUpdateEpoch {
        address provider = msg.sender;
        require(providers[provider].providerAddress != address(0), "basis.withdrawProviderReward: provider not registered");

        uint256 totalReward;
        uint256 lastClaimed = lastClaimedProviderEpoch[provider];
        
        require(currentEpoch > lastClaimed, "no epochs to claim");

        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            totalReward += calculateProviderRewardForEpoch(provider, epoch);
        }

        require(totalReward > 0, "no reward");
        require(basis.balanceOf(address(this)) >= totalReward + totalStakedBasis, "insufficient contract balance");

        lastClaimedProviderEpoch[provider] = currentEpoch;

        basis.safeTransfer(provider, totalReward);

        emit WithdrawProviderReward(provider, totalReward, lastClaimed, currentEpoch - 1);
    }

    function withdrawDelegatorReward(address provider) public nonReentrant autoUpdateEpoch {
        address delegator = msg.sender;
        
        require(providers[provider].providerAddress != address(0), "basis.withdrawDelegatorReward: provider not registered");
        require(delegations[delegator][provider].amount > 0, "no delegation");

        uint256 totalReward;
        uint256 lastClaimed = lastClaimedDelegatorEpoch[delegator][provider];
        
        require(currentEpoch > lastClaimed, "no epochs to claim");

        for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
            totalReward += calculateDelegatorRewardForEpoch(delegator, provider, epoch);
        }

        require(totalReward > 0, "no reward");
        require(basis.balanceOf(address(this)) >= totalReward + totalStakedBasis, "insufficient contract balance");

        lastClaimedDelegatorEpoch[delegator][provider] = currentEpoch;

        basis.safeTransfer(delegator, totalReward);

        emit WithdrawDelegatorReward(delegator, provider, totalReward, lastClaimed, currentEpoch - 1);
    }

    /* ================= BATCH WITHDRAWAL ================= */

    function withdrawAllDelegatorRewards(address[] calldata providers) external nonReentrant autoUpdateEpoch {
        address delegator = msg.sender;
        uint256 totalReward;
        
        for (uint256 i = 0; i < providers.length; i++) {
            address provider = providers[i];
            
            if (delegations[delegator][provider].amount == 0) continue;
            
            uint256 lastClaimed = lastClaimedDelegatorEpoch[delegator][provider];
            if (currentEpoch <= lastClaimed) continue;

            uint256 providerReward;
            for (uint256 epoch = lastClaimed; epoch < currentEpoch; epoch++) {
                providerReward += calculateDelegatorRewardForEpoch(delegator, provider, epoch);
            }

            if (providerReward == 0) continue;

            lastClaimedDelegatorEpoch[delegator][provider] = currentEpoch;
            totalReward += providerReward;
            
            emit WithdrawDelegatorReward(delegator, provider, providerReward, lastClaimed, currentEpoch - 1);
        }
        
        require(totalReward > 0, "no rewards to claim");
        require(basis.balanceOf(address(this)) >= totalReward + totalStakedBasis, "insufficient contract balance");
        
        basis.safeTransfer(delegator, totalReward);
    }

    /* ================= VIEW FUNCTIONS ================= */

    function getCurrentEpochInfo() external view returns(
        uint256 epoch,
        uint256 startTime,
        uint256 endTime,
        uint256 timeRemaining
    ) {
        epoch = currentEpoch;
        startTime = epochStartTime;
        endTime = epochStartTime + EPOCH_DURATION;
        timeRemaining = block.timestamp < endTime ? endTime - block.timestamp : 0;
    }

    /* ================= EVENTS ================= */

    event EpochAdvanced(uint256 indexed epoch, uint256 timestamp);
    
    event EpochFinalized(uint256 indexed epoch, uint256 totalPower, uint256 totalReward);

    event ProviderCreated(address indexed provider, string description, uint8 indexed commission);

    event ProviderEdited(address indexed provider, string description, uint8 indexed commission);

    event Delegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event Undelegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event ProviderStaked(address indexed provider, uint256 indexed amount);

    event ProviderUnstaked(address indexed provider, uint256 indexed amount);

    event WithdrawProviderReward(address indexed provider, uint256 amount, uint256 fromEpoch, uint256 toEpoch);

    event WithdrawDelegatorReward(address indexed delegator, address indexed provider, uint256 amount, uint256 fromEpoch, uint256 toEpoch);
}