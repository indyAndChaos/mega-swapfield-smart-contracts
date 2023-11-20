// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import './IERC20MegaTokenReceiver.sol';
import './ERC1363.sol';

/**
 * @dev Basic implementation for Mega tokens.
 */
abstract contract MegaToken is ERC1363 {
    // Mega Swap Fund address.
    address public immutable SWAP_FUND;

    // The second Mega token address.
    address public immutable PAIRED_TOKEN;

    constructor(address _SWAP_FUND, address _PAIRED_TOKEN) {
        SWAP_FUND = _SWAP_FUND;
        PAIRED_TOKEN = _PAIRED_TOKEN;
    }

    /**
     * @dev Only prevents the certain human errors.
     */
    function _beforeERC20Transfer(address, address to, uint256) internal view override {
        require(to != address(this), 'MegaToken: transfer to self token address');
        require(to != PAIRED_TOKEN, 'MegaToken: transfer to paired token address');
    }

    function _afterERC20Transfer(address from, address to, uint256 amount) internal override {
        if (to == SWAP_FUND && msg.sender != SWAP_FUND) {
            IERC20MegaTokenReceiver(SWAP_FUND).onERC20MegaTokenTransferReceived(from, amount);
        }
    }
}
