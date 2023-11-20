// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import './MegaToken.sol';

/**
 * @title Mega Merger
 * @dev This token is part of Mega Swapfield.
 */
contract MegaMerger is MegaToken {
    constructor(
        address[2] memory initAccounts,
        uint256[2] memory initBalances,
        address _PAIRED_TOKEN
    ) ERC20('Mega Merger', 'MMT') MegaToken(msg.sender, _PAIRED_TOKEN) {
        _mint(initAccounts[0], initBalances[0], false);
        _mint(initAccounts[1], initBalances[1], false);
    }
}
