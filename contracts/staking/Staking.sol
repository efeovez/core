// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StakingState} from "./StakingState.sol";

contract Staking is StakingState {

    /* ================= FUNCTIONS ================= */

    function createProvider(string memory description_,
                            uint8 commission_
    ) public {
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
}