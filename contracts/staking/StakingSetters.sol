// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingState} from "./StakingState.sol";
import {Governor} from "../access/Governor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingSetters is StakingState, Governor {

    using SafeERC20 for IERC20;

    /* ================= FUNCTIONS ================ */

    function setLockPeriod(uint256 newLockPeriod) public onlyGovernor {
        uint256 oldLockPeriod = lockPeriod;
        lockPeriod = newLockPeriod;

        emit LockPeriodSetted(oldLockPeriod, newLockPeriod);
    }

    function setMaxProviders(uint8 newMaxProviders) public onlyGovernor {
        uint256 oldMaxProviders = maxProviders;
        maxProviders = newMaxProviders;

        emit MaxProvidersSetted(oldMaxProviders, newMaxProviders);
    }

    function setBasis(IERC20 newBasis) public onlyGovernor {
        IERC20 oldBasis = basis;
        basis = newBasis;

        emit BasisSetted(oldBasis, newBasis);
    }

    function setSbasis(IERC20 newSbasis) public onlyGovernor {
        IERC20 oldSbasis = sbasis;
        sbasis = newSbasis;

        emit SBasisSetted(oldSbasis, newSbasis);
    }

    /* ================= EVENTS ================ */

    event LockPeriodSetted(uint256 indexed previousLockPeriod, uint256 indexed newLockPeriod);

    event MaxProvidersSetted(uint256 indexed previousMaxProviders, uint256 indexed newMaxProviders);

    event BasisSetted(IERC20 indexed previousBasis, IERC20 indexed newBasis);

    event SBasisSetted(IERC20 indexed previousSbasis, IERC20 indexed newSbasis);
}