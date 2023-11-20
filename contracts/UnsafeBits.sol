// SPDX-License-Identifier: MIT
// Modified version of Bits.sol of https://github.com/ethereum/solidity-examples

pragma solidity ^0.8.0;

/**
 * NOTE:
 * - 'index' bit is accessed in an "unsafe" way:
 *   checking that it does not exceed the highest bit of uint256
 *   or a particular bitfield is skipped.
 */
library UnsafeBits {
    // Sets the bit at the given 'index' in 'self' to '1'.
    // Returns the modified value.
    function setBit(uint256 self, uint256 index) internal pure returns (uint256) {
        return self | (1 << index);
    }

    // Sets the bit at the given 'index' in 'self' to '0'.
    // Returns the modified value.
    function clearBit(uint256 self, uint256 index) internal pure returns (uint256) {
        return self & ~(1 << index);
    }

    // Get the value of the bit at the given 'index' in 'self'.
    function getBit(uint256 self, uint256 index) internal pure returns (uint256) {
        return (self >> index) & 1;
    }

    // Check if the bit at the given 'index' in 'self' is set.
    // Returns:
    //  'true' - if the value of the bit is '1'
    //  'false' - if the value of the bit is '0'
    function bitSet(uint256 self, uint256 index) internal pure returns (bool) {
        return (self >> index) & 1 == 1;
    }
}
