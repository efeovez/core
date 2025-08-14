// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../libs/IERC20.sol";
import {SafeERC20} from "../libs/SafeERC20.sol";
import {StakingState} from "./StakingState.sol";

contract Staking is StakingState {

    /* ================= STATE VARIABLES ================= */

    using SafeERC20 for IERC20;

    IERC20 public basis;

    /* ================= CONSTRUCTOR ================= */

    constructor(address basisAddress) {
        basis = IERC20(basisAddress);
    }

    /* ================= FUNCTIONS ================= */

    function createProvider(string memory description_, uint8 commission_) public {
        require(bytes(description_).length < 50, "basis.staking.Staking: description_ must be under 50 characters");
        require(commission_ <= 100, "basis.staking.Staking: commission_ must not exceed 100");
        require(providers[msg.sender].providerAddress == address(0), "basis.staking.Staking: provider already exists");

        providers[msg.sender] = Provider({
            providerAddress: msg.sender,
            description: description_,
            commission: commission_,
            power: 0
        });
    }

    function editProvider(string memory description_, uint8 commission_) public {
        require(bytes(description_).length < 50, "basis.staking.Staking: description_ must be under 50 characters");
        require(commission_ <= 100, "basis.staking.Staking: commission_ must not exceed 100");
        require(msg.sender == providers[msg.sender].providerAddress, "basis.staking.Staking: provider not registered");

        Provider storage currentProvider = providers[msg.sender];

        currentProvider.description = description_;
        currentProvider.commission = commission_;
    }

    function delegate(address provider, uint256 amount) public {
        require(basis.allowance(msg.sender, address(this)) >= amount, "basis.staking.Staking: approved amount is not sufficient");
        require(providers[provider].providerAddress != address(0), "basis.staking.Staking: provider not registered");

        basis.safeTransferFrom(msg.sender, address(this), amount);

        Provider storage currentProvider = providers[provider];
        currentProvider.power += amount;

        Delegation storage userDelegation = delegations[msg.sender][provider];
        userDelegation.amount += amount;
        userDelegation.unlockTime = block.timestamp + LOCK_PERIOD;
    }
}