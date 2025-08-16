// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingState} from "./StakingState.sol";
import {Governor} from "../access/Governor.sol";

contract StakingSetters is StakingState, Governor {

    /* ================= FUNCTIONS ================ */

    function setLockPeriod(uint256 newLockPeriod) public onlyGovernor {
        emit LockPeriodSetted(lockPeriod, newLockPeriod);

        lockPeriod = newLockPeriod;
    }

    function setMaxProviders(uint256 newMaxProviders) public onlyGovernor {
        emit MaxProvidersSetted(maxProviders, newMaxProviders);

        maxProviders = newMaxProviders;
    }

    /* ================= EVENTS ================ */

    event LockPeriodSetted(uint256 indexed previousLockPeriod, uint256 indexed newLockPeriod);

    event MaxProvidersSetted(uint256 indexed previousMaxProviders, uint256 indexed newMaxProviders);
}