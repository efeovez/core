// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingState} from "./StakingState.sol";
import {Governor} from "../access/Governor.sol";
import {IERC20} from "../libs/IERC20.sol";
import {SafeERC20} from "../libs/SafeERC20.sol";

contract StakingSetters is StakingState, Governor {

    using SafeERC20 for IERC20;

    /* ================= FUNCTIONS ================ */

    function setLockPeriod(uint256 newLockPeriod) public onlyGovernor {
        emit LockPeriodSetted(lockPeriod, newLockPeriod);

        lockPeriod = newLockPeriod;
    }

    function setMaxProviders(uint256 newMaxProviders) public onlyGovernor {
        emit MaxProvidersSetted(maxProviders, newMaxProviders);

        maxProviders = newMaxProviders;
    }

    function setBasis(IERC20 newBasis) public onlyGovernor {
        emit BasisSetted(basis, newBasis);

        basis = newBasis;
    }

    function setSbasis(IERC20 newSbasis) public onlyGovernor {
        emit SBasisSetted(sbasis, newSbasis);

        sbasis = newSbasis;
    }

    /* ================= EVENTS ================ */

    event LockPeriodSetted(uint256 indexed previousLockPeriod, uint256 indexed newLockPeriod);

    event MaxProvidersSetted(uint256 indexed previousMaxProviders, uint256 indexed newMaxProviders);

    event BasisSetted(IERC20 indexed previousBasis, IERC20 indexed newBasis);

    event SBasisSetted(IERC20 indexed previousSbasis, IERC20 indexed newSbasis);
}