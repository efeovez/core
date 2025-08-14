// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "../libs/ERC20.sol";
import {ERC20Burnable} from "../libs/ERC20Burnable.sol";
import {Governor} from "../access/Governor.sol";

contract Basis is ERC20, ERC20Burnable, Governor {

    /* ================= CONSTRUCTOR ================= */

    constructor() ERC20("Basis", "BASIS") {}

    /* ================= FUNCTIONS ================= */

    function mint(address account, uint256 amount) public onlyGovernor returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyGovernor {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyGovernor {
        super.burnFrom(account, amount);
    }

}