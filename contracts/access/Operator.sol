// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Operator {

    /* ================= STATE VARIABLES ================= */

    address private operator;

    /* ================= CONSTRUCTOR ================= */

    constructor() {
        operator = msg.sender;
    }

    /* ================= MODIFIER ================= */

    modifier onlyOperator() {
        require(msg.sender == operator, "msg.sender is not the operator");
        _;
    }

    /* ================= FUNCTIONS ================= */

    function getOperator() public view returns(address) {
        return operator;
    }

    function isOperator() public view returns(bool) {
        return msg.sender == operator;
    }

    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "zero address given for new operator");

        emit OperatorTransferred(operator, newOperator);

        operator = newOperator;
    }

    /* ================= EVENT ================= */

    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    
}