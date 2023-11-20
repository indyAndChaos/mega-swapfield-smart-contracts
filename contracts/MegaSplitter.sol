// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import './MegaToken.sol';

/**
 * @title Mega Splitter
 * @dev This token is part of Mega Swapfield.
 */
contract MegaSplitter is MegaToken {
    constructor(
        address[2] memory initAccounts,
        uint256[2] memory initBalances,
        address _PAIRED_TOKEN,
        uint256 _SWAP_RATE_1
    ) ERC20('Mega Splitter', 'MST') MegaToken(msg.sender, _PAIRED_TOKEN) {
        _mint(initAccounts[0], initBalances[0] * _SWAP_RATE_1, false);
        _mint(initAccounts[1], initBalances[1] * _SWAP_RATE_1, false);
    }
}
