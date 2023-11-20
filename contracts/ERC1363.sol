// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import './IERC1363.sol';
import './IERC1363Receiver.sol';
import './IERC1363Spender.sol';
import './ERC20.sol';
import './ERC165.sol';
import './Address.sol';

/**
 * @dev Implementation of the {IERC1363} interface.
 */
abstract contract ERC1363 is ERC20, ERC165, IERC1363 {
    using Address for address;

    bytes4 private constant _INTERFACE_ID_ERC1363_TRANSFER = 0x4bbee2df;
    bytes4 private constant _INTERFACE_ID_ERC1363_APPROVE = 0xfb9ec8ce;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1363).interfaceId ||
            interfaceId == _INTERFACE_ID_ERC1363_TRANSFER ||
            interfaceId == _INTERFACE_ID_ERC1363_APPROVE ||
            super.supportsInterface(interfaceId);
    }

    function transferAndCall(address to, uint256 amount) public virtual returns (bool) {
        return transferAndCall(to, amount, '');
    }

    function transferAndCall(address to, uint256 amount, bytes memory data) public virtual returns (bool) {
        _transfer(to, amount);

        require(
            _checkOnTransferReceived(_msgSender(), to, amount, data),
            'ERC1363: transfer to non ERC1363Receiver implementer'
        );

        return true;
    }

    function transferFromAndCall(address from, address to, uint256 amount) public virtual returns (bool) {
        return transferFromAndCall(from, to, amount, '');
    }

    function transferFromAndCall(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) public virtual returns (bool) {
        _transferFrom(from, to, amount);

        require(
            _checkOnTransferReceived(from, to, amount, data),
            'ERC1363: transfer to non ERC1363Receiver implementer'
        );

        return true;
    }

    function approveAndCall(address spender, uint256 amount) public virtual returns (bool) {
        return approveAndCall(spender, amount, '');
    }

    function approveAndCall(address spender, uint256 amount, bytes memory data) public virtual returns (bool) {
        _approve(_msgSender(), spender, amount);

        require(_checkOnApprovalReceived(spender, amount, data), 'ERC1363: approve non ERC1363Spender implementer');

        return true;
    }

    /**
     * @dev Internal function to invoke {IERC1363Receiver-onTransferReceived} on a target address.
     *  The target address must be a contract.
     *
     * @param sender address The address from which tokens are transferred
     * @param recipient address The target contract to which tokens are transferred
     * @param amount uint256 The amount of tokens transferred
     * @param data bytes Optional data to send along with the call
     * @return bool Whether the call returned the expected magic value
     */
    function _checkOnTransferReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        require(recipient.isContract(), 'ERC1363: transfer to non contract address');

        try IERC1363Receiver(recipient).onTransferReceived(_msgSender(), sender, amount, data) returns (bytes4 retval) {
            return retval == IERC1363Receiver.onTransferReceived.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert('ERC1363: transfer to non ERC1363Receiver implementer');
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Internal function to invoke {IERC1363Receiver-onApprovalReceived} on a target address.
     *  The target address must be a contract.
     *
     * @param spender address The target contract which is token spender
     * @param amount uint256 The amount of tokens approved
     * @param data bytes Optional data to send along with the call
     * @return bool Whether the call returned the expected magic value
     */
    function _checkOnApprovalReceived(
        address spender,
        uint256 amount,
        bytes memory data
    ) internal virtual returns (bool) {
        require(spender.isContract(), 'ERC1363: approve non contract address');

        try IERC1363Spender(spender).onApprovalReceived(_msgSender(), amount, data) returns (bytes4 retval) {
            return retval == IERC1363Spender.onApprovalReceived.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert('ERC1363: approve non ERC1363Spender implementer');
            } else {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
}
