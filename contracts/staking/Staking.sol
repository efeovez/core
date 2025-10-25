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

    /* ================= PROVIDER FUNCTIONS ================ */

    function createProvider(string memory description, uint8 commission) public {
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

    function delegate(address provider, uint256 amount) public {
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
        totalPower += amount;

        emit Delegated(msg.sender, provider, amount);
    }

    function undelegate(address provider, uint256 amount) public nonReentrant {
        require(delegations[msg.sender][provider].amount >= amount, "basis.undelegate: amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[provider].providerAddress != address(0), "basis.delegate: provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "basis.undelegate: you do not have an existing delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "basis.undelegate: your token is locked");

        Provider storage providerWrapper = providers[provider];
        providerWrapper.power -= amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount -= amount;

        totalStakedSbasis -= amount;
        totalPower -= amount;

        sbasis.safeTransfer(msg.sender, amount);

        emit Undelegated(msg.sender, provider, amount);
    }

    /* ================= STAKING FUNCTIONS ================ */

    function stake(uint256 amount) public {
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
        totalPower += amount;

        emit ProviderStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) public nonReentrant {
        require(staked[msg.sender].amount >= amount, "basis.unstake: amount you wish to unstake must be less than or equal to the amount you have staked");
        require(providers[msg.sender].providerAddress != address(0), "basis.unstake: provider not registered");
        require(staked[msg.sender].amount > 0, "basis.unstake: you do not have an existing delegation");
        require(block.timestamp >= staked[msg.sender].unlockTime, "basis.unstake: your token is locked");

        Provider storage providerWrapper = providers[msg.sender];
        providerWrapper.power -= amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount -= amount;

        totalStakedBasis -= amount;
        totalPower -= amount;

        basis.safeTransfer(msg.sender, amount);

        emit ProviderUnstaked(msg.sender, amount);
    }

    /* ================= REWARD CALCULATION ================ */

    function getTotalReward() public view returns(uint256) { 
        return basis.balanceOf(address(this)) - totalStakedBasis;
    }

    function calculateProviderReward(address provider) public view returns(uint256) {
        require(providers[provider].providerAddress != address(0), "provider not registered");
        require(staked[provider].amount > 0, "no self stake");

        if (totalPower == 0) return 0;

        uint256 providerPower = providers[provider].power;
        if (providerPower == 0) return 0;

        uint256 providerTotalReward = (providerPower * getTotalReward()) / totalPower;
    
        uint256 providerSelfStake = staked[provider].amount;
        uint256 providerSelfReward = (providerTotalReward * providerSelfStake) / providerPower;

        uint256 delegationReward = providerTotalReward - providerSelfReward;
        uint256 commissionReward = (delegationReward * providers[provider].commission) / 100;

        return providerSelfReward + commissionReward;
    }

    function calculateDelegatorReward(address delegator, address provider) public view returns(uint256) {
        require(providers[provider].providerAddress != address(0), "provider not registered");
        require(staked[provider].amount > 0, "no self stake");
    
        if (totalPower == 0) return 0;

        uint256 delegatorAmount = delegations[delegator][provider].amount;
        if (delegatorAmount == 0) return 0;

        uint256 providerPower = providers[provider].power;
        uint256 providerTotalReward = (providerPower * getTotalReward()) / totalPower;
    
        uint256 providerSelfStake = staked[provider].amount;
        uint256 providerSelfReward = (providerTotalReward * providerSelfStake) / providerPower;
    
        uint256 delegationReward = providerTotalReward - providerSelfReward;
        uint256 commissionReward = (delegationReward * providers[provider].commission) / 100;
    
        uint256 netDelegationReward = delegationReward - commissionReward;
    
        uint256 totalDelegated = providerPower - providerSelfStake;
        if (totalDelegated == 0) return 0;

        return (delegatorAmount * netDelegationReward) / totalDelegated;
    }

    /* ================= REWARD WITHDRAWAL ================ */

    function withdrawProviderReward() public nonReentrant {
        require(providers[msg.sender].providerAddress != address(0), "basis.withdrawProviderReward: provider not registered");

        uint256 availableReward = calculateProviderReward(msg.sender) - providerWithdrawnRewards[msg.sender];
        require(availableReward > 0, "no rewards available");
        providerWithdrawnRewards[msg.sender] += availableReward;

        basis.safeTransfer(msg.sender, availableReward);

        emit WithdrawProviderReward(msg.sender, availableReward );
    }

    function withdrawDelegatorReward(address provider) public nonReentrant {
        require(providers[provider].providerAddress != address(0), "basis.withdrawDelegatorReward: provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "no delegation");

        uint256 availableReward = calculateDelegatorReward(msg.sender, provider) - delegatorWithdrawnRewards[msg.sender][provider];
        require(availableReward > 0, "no rewards available");
        delegatorWithdrawnRewards[msg.sender][provider] += availableReward;

        basis.safeTransfer(msg.sender, availableReward);

        emit WithdrawDelegatorReward(msg.sender, provider, availableReward);
    }

    /* ================= EVENTS ================= */

    event ProviderCreated(address indexed provider, string description, uint8 indexed commission);

    event ProviderEdited(address indexed provider, string description, uint8 indexed commission);

    event Delegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event Undelegated(address indexed delegator, address indexed provider, uint256 indexed amount);

    event ProviderStaked(address indexed provider, uint256 indexed amount);

    event ProviderUnstaked(address indexed provider, uint256 indexed amount);

    event WithdrawProviderReward(address indexed provider, uint256 amount);

    event WithdrawDelegatorReward(address indexed delegator, address indexed provider, uint256 amount);
}