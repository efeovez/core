// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {StakingState} from "./StakingState.sol";
import {Governor} from "../access/Governor.sol";

contract StakingGovernor is StakingState, Governor {

    using SafeERC20 for IERC20;

    function setLpBasis(IERC20 newLpBasis) public onlyGovernor {
        IERC20 oldLpBasis = lpBasis;

        lpBasis = newLpBasis;

        emit LpBasisUpdated(oldLpBasis, lpBasis);
    }

    function setMaxProviders(uint8 newMaxProviders) public onlyGovernor {
        uint8 oldMaxProviders = maxProviders;

        maxProviders = newMaxProviders;

        emit MaxProvidersUpdated(oldMaxProviders, maxProviders);
    }

    function setLockPeriod(uint256 newLockPeriod) public onlyGovernor {
        uint256 oldLockPeriod = lockPeriod;

        lockPeriod = newLockPeriod;

        emit LockPeriodUpdated(oldLockPeriod, lockPeriod);
    }

    function setCommissionUpdateLock(uint256 newCommissionUpdateLock) public onlyGovernor {
        uint256 oldCommissionUpdateLock = commissionUpdateLock;

        commissionUpdateLock = newCommissionUpdateLock;

        emit CommissionUpdateLockUpdated(oldCommissionUpdateLock, commissionUpdateLock);
    }

    event LpBasisUpdated(IERC20 indexed oldLpBasis, IERC20 indexed newLpBasis);

    event MaxProvidersUpdated(uint8 oldMaxProviders, uint8 newMaxProviders);

    event LockPeriodUpdated(uint256 oldLockPeriod, uint256 newLockPeriod);

    event CommissionUpdateLockUpdated(uint256 oldCommissionUpdateLock, uint256 commissionUpdateLock);
}