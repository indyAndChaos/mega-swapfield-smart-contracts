// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @dev An additional way to execute callback on Mega token transfer to Mega Swap Fund address.
 */
interface IERC20MegaTokenReceiver {
    function onERC20MegaTokenTransferReceived(address sender, uint256 amount) external returns (bool);
}
