// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Operator} from "../access/Operator.sol";

contract lpBasis is ERC20, ERC20Burnable, Operator {

    /* ================= CONSTRUCTOR ================= */

    constructor() ERC20("lpBASIS", "lpBASIS") {}

    /* ================= FUNCTIONS ================= */

    function mint(address account, uint256 amount) public onlyOperator returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

}