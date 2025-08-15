// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../libs/IERC20.sol";
import {SafeERC20} from "../libs/SafeERC20.sol";
import {StakingState} from "./StakingState.sol";

contract Staking is StakingState {

    /* ================= STATE VARIABLES ================= */

    using SafeERC20 for IERC20;

    IERC20 public basis;
    IERC20 public sbasis;

    /* ================= CONSTRUCTOR ================= */

    constructor(address basisAddress, address sbasisAddress) {
        basis = IERC20(basisAddress);
        sbasis = IERC20(sbasisAddress);
    }

    /* ================= FUNCTIONS ================= */

    function createProvider(string memory description_, uint8 commission_) public {
        require(bytes(description_).length < 50, "basis.staking.Staking.createProvider(): description_ must be under 50 characters");
        require(commission_ <= 100, "basis.staking.Staking.createProvider(): commission_ must not exceed 100");
        require(providers[msg.sender].providerAddress == address(0), "basis.staking.Staking.createProvider(): provider already exists");

        providers[msg.sender] = Provider({
            providerAddress: msg.sender,
            description: description_,
            commission: commission_,
            power: 0
        });
    }

    function editProvider(string memory description_, uint8 commission_) public {
        require(bytes(description_).length < 50, "basis.staking.Staking.editProvider(): description_ must be under 50 characters");
        require(commission_ <= 100, "basis.staking.Staking.editProvider(): commission_ must not exceed 100");
        require(msg.sender == providers[msg.sender].providerAddress, "basis.staking.Staking.editProvider(): provider not registered");

        Provider storage currentProvider = providers[msg.sender];

        currentProvider.description = description_;
        currentProvider.commission = commission_;
    }

    function delegate(address provider, uint256 amount) public {
        require(sbasis.allowance(msg.sender, address(this)) >= amount, "basis.staking.Staking.delegate(): approved amount is not sufficient");
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.delegate(): provider not registered");
        require(amount > 0, "basis.staking.Staking.delegate(): you cannot delegate zero");

        sbasis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage currentProvider = providers[provider];
        currentProvider.power += amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount += amount;
        delegationWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedSbasis += amount;
    }

    function undelegate(address provider, uint256 amount) public {
        require(delegations[msg.sender][provider].amount >= amount, "basis.staking.Staking.undelegate(): amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking.delegate(): provider not registered");
        require(delegations[msg.sender][provider].amount > 0, "basis.staking.Staking.undelegate(): you do not have an existing delegation");
        require(block.timestamp >= delegations[msg.sender][provider].unlockTime, "basis.staking.Staking.undelegate(): your token is locked");

        Provider storage currentProvider = providers[provider];
        currentProvider.power -= amount;

        Delegation storage delegationWrapper = delegations[msg.sender][provider];
        delegationWrapper.amount -= amount;

        totalStakedSbasis -= amount;

        sbasis.safeTransfer(msg.sender, amount);
    }

    function stake(uint256 amount) public {
        require(basis.allowance(msg.sender, address(this)) >= amount, "basis.staking.Staking.stake(): approved amount is not sufficient");
        require(providers[msg.sender].providerAddress != address(0), "basis.staking.Staking.stake(): provider not registered");
        require(amount > 0, "basis.staking.Staking.stake(): you cannot stake zero");

        basis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage currentProvider = providers[msg.sender];
        currentProvider.power += amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount += amount;
        stakedWrapper.unlockTime = block.timestamp + lockPeriod;

        totalStakedBasis += amount;
    }

    function unstake(uint256 amount) public {
        require(staked[msg.sender].amount >= amount, "basis.staking.Staking.unstake(): amount you wish to undelegate must be less than or equal to the amount you have delegated");
        require(providers[msg.sender].providerAddress != address(0), "basis.staking.Staking.unstake(): provider not registered");
        require(staked[msg.sender].amount > 0, "basis.staking.Staking.unstake(): you do not have an existing delegation");
        require(block.timestamp >= staked[msg.sender].unlockTime, "basis.staking.Staking.unstake(): your token is locked");

        Provider storage currentProvider = providers[msg.sender];
        currentProvider.power -= amount;

        Staked storage stakedWrapper = staked[msg.sender];
        stakedWrapper.amount -= amount;

        totalStakedBasis -= amount;

        basis.safeTransfer(msg.sender, amount);
    }
}