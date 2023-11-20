// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

/**
 * @dev Interfaces for {MegaSwapFund}.
 */

interface IMegaSwapFund0 {
    /**
     * @dev
     * `SwapIn_0` is emitted when `amount` of token #0 is received and swapped
     * with corresponding amount of token #1 (swapped in) at `threadId` thread.
     *
     * `SwapIn_1` is emitted when `amount` of token #1 is received and swapped
     * with corresponding amount of token #0 (swapped in) at `threadId` thread.
     *
     * NOTE:
     * - Since the swap rate is a constant value and amount of paired token can
     *   be easily calculated without division remainder, logging swapped out
     *   amount of paired token is skipped as not necessary.
     */
    event SwapIn_0(uint256 indexed threadId, uint256 amount);
    event SwapIn_1(uint256 indexed threadId, uint256 amount);

    /**
     * @dev Emitted when swap-in counter of `tokenId` token is finalized in
     * `periodNumber` period of `threadId` thread.
     *
     * `totalSwapinCounter` is value of total swap-in counter of `tokenId` token
     * at `threadId` thread.
     *
     * `totalTokenSwapinCounter` is value of total swap-in counter of `tokenId` token.
     */
    event FinalizeSwapinCounter(
        uint256 indexed threadId,
        uint256 indexed tokenId,
        uint256 indexed periodNumber,
        uint256 totalSwapinCounter,
        uint256 totalTokenSwapinCounter
    );

    /// @dev For `threadId` thread, returns value of swap-in counter of `tokenId` token.
    function swapinCounter(uint256 threadId, uint256 tokenId) external view returns (uint256);

    /// @dev For `threadId` thread, returns value of swap-out counter of `tokenId` token.
    function swapoutCounter(uint256 threadId, uint256 tokenId) external view returns (uint256);

    /**
     * @dev For `threadId` thread, returns values of swap-in counter of
     * `tokenId` token and swap-out counter of its paired token.
     */
    function pairedSwapCounters(uint256 threadId, uint256 tokenId) external view returns (uint256, uint256);

    /// @dev Returns values of both swap-in counters of `threadId` thread.
    function crosspairedSwapinCounters(uint256 threadId) external view returns (uint256[2] memory);

    /// @dev Returns values of both swap-out counters of `threadId` thread.
    function crosspairedSwapoutCounters(uint256 threadId) external view returns (uint256[2] memory);

    /// @dev Returns finalization flag of swap-in counter of `tokenId` token at `threadId` thread.
    function isSwapinCounterFinalized(uint256 threadId, uint256 tokenId) external view returns (bool);

    /// @dev Returns finalization flags of both swap-in counters of `threadId` thread.
    function crosspairedSwapinCountersFinalized(uint256 threadId) external view returns (bool[2] memory);

    /**
     * @dev Returns `tokenId` token value available (not blocked in any way) on
     * Mega Swap Fund balance for swapping out at `threadId` thread.
     */
    function getSwappableOutBalance(uint256 threadId, uint256 tokenId) external view returns (uint256);

    /**
     * @dev If either `tokenId` token's swap-in counter or its paired token's swap-out
     * counter can be finalized at `threadId` thread, returns `tokenId` amount
     * required for finalization.
     * Otherwise returns 0.
     */
    function getPairFinalizationAmount(uint256 threadId, uint256 tokenId) external view returns (uint256);

    /**
     * @dev If either `tokenId` token's swap-in counter or its paired token's swap-out
     * counter can be finalized at `threadId` thread, swaps `tokenId` tokens of
     * message sender to perform it.
     * Otherwise reverts.
     *
     * Returns `tokenId` token amount used for finalization (which is always
     * more than 0).
     *
     * NOTE:
     * - Mega Swap Fund must have allowance for message sender's `tokenId` tokens
     *   of at least amount required for finalization.
     */
    function swapInPairFinalizationAmount(uint256 threadId, uint256 tokenId) external returns (uint256);
}

interface IMegaSwapFund1 {
    /// @dev Emitted when the next period started with `periodNumber` number at `threadId` thread.
    event StartPeriod(uint256 indexed threadId, uint256 indexed periodNumber);

    /// @dev Returns number of the current period of `threadId` thread.
    function periodNumber(uint256 threadId) external view returns (uint256);

    /**
     * @dev Returns the total `tokenId` token value swapped in at `threadId` thread
     * since the moment of Mega Swap Fund creation so far
     * (total swap-in counter of `tokenId` token at `threadId` thread).
     */
    function totalSwapinCounter(uint256 threadId, uint256 tokenId) external view returns (uint256);

    /// @dev Returns values of both total swap-in counters of `threadId` thread.
    function crosspairedTotalSwapinCounters(uint256 threadId) external view returns (uint256[2] memory);

    /**
     * @dev Returns the total `tokenId` token value swapped in at all threads
     * since the moment of Mega Swap Fund creation so far
     * (total swap-in counter of `tokenId` token).
     */
    function totalTokenSwapinCounter(uint256 tokenId) external view returns (uint256);

    /// @dev Returns numbers of the current periods of threads with IDs from `fromThreadId` to `toThreadId`.
    function periodNumbers(uint256 fromThreadId, uint256 toThreadId) external view returns (uint256[] memory);

    /**
     * @dev Returns the total `tokenId` token values swapped in at threads with IDs
     * from `fromThreadId` to `toThreadId`
     * since the moment of Mega Swap Fund creation so far
     * (total swap-in counters of `tokenId` token at threads
     * from `fromThreadId` to `toThreadId`).
     */
    function totalSwapinCounters(
        uint256 fromThreadId,
        uint256 toThreadId,
        uint256 tokenId
    ) external view returns (uint256[] memory);
}

interface IMegaSwapFund is IMegaSwapFund0, IMegaSwapFund1 {
    /// @dev Returns finalization flags (as bitfield) of all swap-in counters.
    function swapinCountersFinalized() external view returns (uint256);
}
