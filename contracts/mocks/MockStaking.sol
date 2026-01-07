// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockStaking {
    mapping(address => address) public providers;

    function setProvider(address _operator, address _provider) external {
        providers[_operator] = _provider;
    }

    function getProvider(address _operator) external view returns (address) {
        return providers[_operator];
    }
}