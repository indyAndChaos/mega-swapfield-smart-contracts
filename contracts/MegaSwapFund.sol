// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

import './IERC1363Receiver.sol';
import './IERC1363Spender.sol';
import './MegaSwapFundInterfaces.sol';
import './MegaMerger.sol';
import './MegaSplitter.sol';
import './Context.sol';
import './UnsafeBits.sol';

/**
 * @title Mega Swap Fund
 * @dev This contract is part of Mega Swapfield.
 */
contract MegaSwapFund is Context, ERC165, IERC1363Receiver, IERC1363Spender, IMegaSwapFund {
    using UnsafeBits for uint256;

    // ===========================================================================
    // -------- CONSTANTS SECTION ------------------------------------------------
    // ===========================================================================

    // Mega Merger (token #0) address.
    address public immutable TOKEN_0;

    // Mega Splitter (token #1) address.
    address public immutable TOKEN_1;

    // Total quantity of threads.
    uint256 public constant THREAD_COUNT = 20;

    // Value of 1 token #0 expressed in token #1 tokens.
    uint256 public constant SWAP_RATE_1 = 100;

    // Minimum token #0 amount that can be received and swapped at thread #0.
    uint256 public constant MIN_SWAPPABLE_IN_AMOUNT_0 = 1e9;

    // Minimum token #1 amount that can be received and swapped at thread #0.
    uint256 public constant MIN_SWAPPABLE_IN_AMOUNT_1 = MIN_SWAPPABLE_IN_AMOUNT_0 * SWAP_RATE_1;

    // The next arrays in this section are immutable.
    // Their values are set only once.

    // Maximum token amounts that can be received and swapped at threads.
    uint256[THREAD_COUNT][2] public MAX_SWAPPABLE_IN_AMOUNTS;

    // Initial values of swap-out counters of threads when their new periods start.
    uint256[THREAD_COUNT][2] public INIT_SWAPOUT_COUNTERS;

    // Maximum values of swap-in counters of threads.
    uint256[THREAD_COUNT][2] public MAX_SWAPIN_COUNTERS;

    // ===========================================================================
    // -------- VARIABLES SECTION ------------------------------------------------
    // ===========================================================================

    // Bitfield of finalization flags of reciprocal swap-in counters.
    // Includes all threads.
    //
    // As each thread has 2 reciprocal swap-in counters, only the first
    // `THREAD_COUNT * 2` bits are used.
    //
    // Flag for `threadId` thread and `tokenId` token is bit with index:
    // `threadId` * 2 + `tokenId`.
    uint256 private _swapinsFinalized;

    // Swap counters.

    // Reciprocal swap counters of a given thread.
    //
    // `swapins` is array of 2 swap-in counters, 1 per each Mega token:
    // the first array element is for token #0, and the second one is for token #1.
    // Value of array element is total amount of corresponding token received
    // from external addresses and swapped (swapped in) at the thread in its
    // current period.
    //
    // `swapouts` is array of 2 swap-out counters, 1 per each Mega token:
    // the first array element is for token #0, and the second one is for token #1.
    // Value of array element is total amount of corresponding token that can
    // be swapped with received amount of paired token and sent to external
    // addresses (swapped out) at the thread in its current period.
    struct ReciprocalSwapCounters {
        uint256[2] swapins;
        uint256[2] swapouts;
    }

    ReciprocalSwapCounters[THREAD_COUNT] private _reciprocalSwaps;

    // Total swap-in counters of threads.
    uint256[THREAD_COUNT][2] private _totalSwapins;

    // Total swap-in counters of tokens.
    uint256[2] private _totalTokenSwapins;

    // Period counters.

    // The current period numbers of threads.
    uint256[THREAD_COUNT] private _periodNumbers;

    /**
     * @dev Performs Mega Swapfield initialization.
     */
    constructor(
        uint256[THREAD_COUNT] memory _INIT_SWAPOUT_COUNTERS_0,
        uint256 maxSwappableInAmountsCoeff,
        uint256 holdersSupplyCoeff
    ) {
        address[2] memory initAccounts_0 = [msg.sender, address(this)];
        uint256[2] memory initBalances_0;

        uint256 initSwapoutCounter_0;
        uint256 initSwapoutCounter_1;

        for (uint256 i; i < THREAD_COUNT; ++i) {
            initSwapoutCounter_0 = _INIT_SWAPOUT_COUNTERS_0[i];
            initSwapoutCounter_1 = initSwapoutCounter_0 * SWAP_RATE_1;

            INIT_SWAPOUT_COUNTERS[0][i] = _reciprocalSwaps[i].swapouts[0] = initSwapoutCounter_0;
            INIT_SWAPOUT_COUNTERS[1][i] = _reciprocalSwaps[i].swapouts[1] = initSwapoutCounter_1;

            MAX_SWAPIN_COUNTERS[0][i] = initSwapoutCounter_0 * 4;
            MAX_SWAPIN_COUNTERS[1][i] = initSwapoutCounter_1 * 4;

            MAX_SWAPPABLE_IN_AMOUNTS[0][i] = initSwapoutCounter_0 / maxSwappableInAmountsCoeff;
            MAX_SWAPPABLE_IN_AMOUNTS[1][i] = MAX_SWAPPABLE_IN_AMOUNTS[0][i] * SWAP_RATE_1;

            initBalances_0[1] += initSwapoutCounter_0;

            emit StartPeriod(i, 0);
        }

        initBalances_0[0] = initBalances_0[1] * holdersSupplyCoeff;

        TOKEN_0 = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), bytes1(0x01)))))
        );
        TOKEN_1 = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), address(this), bytes1(0x02)))))
        );

        new MegaMerger(initAccounts_0, initBalances_0, TOKEN_1);

        new MegaSplitter(initAccounts_0, initBalances_0, TOKEN_0, SWAP_RATE_1);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC1363Receiver).interfaceId ||
            interfaceId == type(IERC1363Spender).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function swapinCounter(uint256 threadId, uint256 tokenId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return _reciprocalSwaps[threadId].swapins[tokenId];
    }

    function swapoutCounter(uint256 threadId, uint256 tokenId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return _reciprocalSwaps[threadId].swapouts[tokenId];
    }

    function pairedSwapCounters(uint256 threadId, uint256 tokenId) public view returns (uint256, uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return (_reciprocalSwaps[threadId].swapins[tokenId], _reciprocalSwaps[threadId].swapouts[1 - tokenId]);
    }

    function crosspairedSwapinCounters(uint256 threadId) public view returns (uint256[2] memory) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        return _reciprocalSwaps[threadId].swapins;
    }

    function crosspairedSwapoutCounters(uint256 threadId) public view returns (uint256[2] memory) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        return _reciprocalSwaps[threadId].swapouts;
    }

    function isSwapinCounterFinalized(uint256 threadId, uint256 tokenId) public view returns (bool) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        uint256 index = (threadId << 1) + tokenId;

        return _swapinsFinalized.bitSet(index);
    }

    function crosspairedSwapinCountersFinalized(uint256 threadId) public view returns (bool[2] memory) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        uint256 index_0 = threadId << 1;

        return [_swapinsFinalized.bitSet(index_0), _swapinsFinalized.bitSet(index_0 + 1)];
    }

    function swapinCountersFinalized() public view returns (uint256) {
        return _swapinsFinalized;
    }

    function periodNumber(uint256 threadId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        return _periodNumbers[threadId];
    }

    function periodNumbers(uint256 fromThreadId, uint256 toThreadId) public view returns (uint256[] memory) {
        require(fromThreadId < toThreadId && toThreadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID(s)');

        uint256 mlength;
        unchecked {
            mlength = toThreadId - fromThreadId + 1;
        }

        uint256[] memory result = new uint256[](mlength);

        unchecked {
            for (uint256 i; i < mlength; ++i) {
                result[i] = _periodNumbers[fromThreadId + i];
            }
        }

        return result;
    }

    function totalSwapinCounter(uint256 threadId, uint256 tokenId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return _totalSwapins[tokenId][threadId];
    }

    function crosspairedTotalSwapinCounters(uint256 threadId) public view returns (uint256[2] memory) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        return [_totalSwapins[0][threadId], _totalSwapins[1][threadId]];
    }

    function totalSwapinCounters(
        uint256 fromThreadId,
        uint256 toThreadId,
        uint256 tokenId
    ) public view returns (uint256[] memory) {
        require(fromThreadId < toThreadId && toThreadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID(s)');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        uint256 mlength;
        unchecked {
            mlength = toThreadId - fromThreadId + 1;
        }

        uint256[] memory result = new uint256[](mlength);

        unchecked {
            for (uint256 i; i < mlength; ++i) {
                result[i] = _totalSwapins[tokenId][fromThreadId + i];
            }
        }

        return result;
    }

    function totalTokenSwapinCounter(uint256 tokenId) public view returns (uint256) {
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return _totalTokenSwapins[tokenId];
    }

    function getSwappableOutBalance(uint256 threadId, uint256 tokenId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        uint256 _amount = _reciprocalSwaps[threadId].swapouts[tokenId];
        if (_amount == 0) return 0;

        uint256 pairedTokenId;
        if (tokenId == 0) pairedTokenId = 1;

        uint256 _pairedAmount = MAX_SWAPIN_COUNTERS[pairedTokenId][threadId] -
            _reciprocalSwaps[threadId].swapins[pairedTokenId];
        if (_pairedAmount == 0) return 0;

        _pairedAmount = tokenId == 0 ? _pairedAmount / SWAP_RATE_1 : _pairedAmount * SWAP_RATE_1;

        return (_amount < _pairedAmount ? _amount : _pairedAmount);
    }

    function getPairFinalizationAmount(uint256 threadId, uint256 tokenId) public view returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        return _getPairFinalizationAmount(threadId, tokenId, 1 - tokenId);
    }

    /**
     * @dev See also {IERC1363Receiver-onTransferReceived}.
     *
     * If `data` is not provided, performs just token swap, otherwise performs
     * finalization of a swap counter selected by `_getPairFinalizationAmount`.
     */
    function onTransferReceived(
        address,
        address sender,
        uint256 amount,
        bytes calldata data
    ) public override returns (bytes4) {
        uint256 tokenId;
        uint256 pairedTokenId;

        // Check `msg.sender` and get token IDs based on its address.
        (tokenId, pairedTokenId) = _checkOnReceived();

        // Initiate token swap.
        if (data.length == 0) {
            _onReceivedWithoutData(sender, tokenId, pairedTokenId, amount);
        }
        // Initiate finalization.
        else {
            // Get thread ID from `data`.
            uint256 threadId = _decodeReceivedData(data);
            require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

            // Get amount required for finalization.
            uint256 finalAmount = _getPairFinalizationAmount(threadId, tokenId, pairedTokenId);
            require(finalAmount != 0, 'MegaSwapFund: out of finalization range');

            // Check that received amount is sufficient for finalization.
            require(amount >= finalAmount, 'MegaSwapFund: amount insufficient for finalization');

            // Calculate return amount. If it is more than 0, transfer it back to `sender`.
            if (amount > finalAmount) {
                uint256 returnAmount;
                unchecked {
                    returnAmount = amount - finalAmount;
                }

                IERC20(tokenId == 0 ? TOKEN_0 : TOKEN_1).transfer(sender, returnAmount);
            }

            // Calculate paired token amount.
            uint256 pairedFinalAmount = tokenId == 0 ? finalAmount * SWAP_RATE_1 : finalAmount / SWAP_RATE_1;

            _swapReceivedAmount(sender, threadId, tokenId, pairedTokenId, finalAmount, pairedFinalAmount);
        }

        return IERC1363Receiver.onTransferReceived.selector;
    }

    /**
     * @dev Performs token swap the same as `onTransferReceived` without `data` provided.
     */
    function onERC20MegaTokenTransferReceived(address sender, uint256 amount) public returns (bool) {
        uint256 tokenId;
        uint256 pairedTokenId;

        // Check `msg.sender` and get token IDs based on its address.
        (tokenId, pairedTokenId) = _checkOnReceived();

        _onReceivedWithoutData(sender, tokenId, pairedTokenId, amount);

        return true;
    }

    /**
     * @dev See also {IERC1363Spender-onApprovalReceived}.
     *
     * Performs finalization of a swap counter selected by `_getPairFinalizationAmount`.
     * Used for finalization only.
     *
     * NOTE:
     * - Mega Swap Fund must have allowance for `tokenId` tokens of `sender` of
     *   at least `finalAmount` to perform finalization.
     */
    function onApprovalReceived(address sender, uint256, bytes calldata data) public override returns (bytes4) {
        uint256 tokenId;
        uint256 pairedTokenId;

        // Check `msg.sender` and get token IDs based on its address.
        (tokenId, pairedTokenId) = _checkOnReceived();

        // Get thread ID from `data`.
        uint256 threadId = _decodeReceivedData(data);
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');

        // Get amount required for finalization.
        uint256 finalAmount = _getPairFinalizationAmount(threadId, tokenId, pairedTokenId);
        require(finalAmount != 0, 'MegaSwapFund: out of finalization range');

        // Transfer finalization amount from `sender`.
        IERC20(tokenId == 0 ? TOKEN_0 : TOKEN_1).transferFrom(sender, address(this), finalAmount);

        // Calculate paired token amount.
        uint256 pairedFinalAmount = tokenId == 0 ? finalAmount * SWAP_RATE_1 : finalAmount / SWAP_RATE_1;

        _swapReceivedAmount(sender, threadId, tokenId, pairedTokenId, finalAmount, pairedFinalAmount);

        return IERC1363Spender.onApprovalReceived.selector;
    }

    function swapInPairFinalizationAmount(uint256 threadId, uint256 tokenId) public returns (uint256) {
        require(threadId < THREAD_COUNT, 'MegaSwapFund: wrong thread ID');
        require(tokenId < 2, 'MegaSwapFund: wrong token ID');

        uint256 pairedTokenId;
        if (tokenId == 0) pairedTokenId = 1;

        // Get amount required for finalization.
        uint256 finalAmount = _getPairFinalizationAmount(threadId, tokenId, pairedTokenId);
        require(finalAmount != 0, 'MegaSwapFund: out of finalization range');

        address sender = _msgSender();

        // Transfer finalization amount from `sender`.
        IERC20(tokenId == 0 ? TOKEN_0 : TOKEN_1).transferFrom(sender, address(this), finalAmount);

        // Calculate paired token amount.
        uint256 pairedFinalAmount = tokenId == 0 ? finalAmount * SWAP_RATE_1 : finalAmount / SWAP_RATE_1;

        _swapReceivedAmount(sender, threadId, tokenId, pairedTokenId, finalAmount, pairedFinalAmount);

        return finalAmount;
    }

    /**
     * @dev If `msg.sender` is an acceptable token, returns token IDs based
     * on its address, otherwise reverts.
     */
    function _checkOnReceived() private view returns (uint256 tokenId, uint256 pairedTokenId) {
        if (msg.sender == TOKEN_0) pairedTokenId = 1;
        else if (msg.sender == TOKEN_1) tokenId = 1;
        else revert('MegaSwapFund: message sender is not acceptable token');
    }

    /**
     * @dev Converts `bs[0]` to uint256.
     *
     * Requirements:
     * - `bs` length must be 1.
     * - `bs[0]` is implicitly converted to uint8.
     */
    function _decodeReceivedData(bytes calldata bs) private pure returns (uint256) {
        require(bs.length == 1, 'MegaSwapFund: incorrect parameter length');

        return uint256(uint8(bs[0]));
    }

    function _getPairFinalizationAmount(
        uint256 threadId,
        uint256 tokenId,
        uint256 pairedTokenId
    ) private view returns (uint256) {
        uint256 _pairedFinalAmount = _reciprocalSwaps[threadId].swapouts[pairedTokenId];
        if (_pairedFinalAmount == 0) return 0;

        uint256 _finalAmount = MAX_SWAPIN_COUNTERS[tokenId][threadId] - _reciprocalSwaps[threadId].swapins[tokenId];
        if (_finalAmount == 0) return 0;

        if (_pairedFinalAmount <= MAX_SWAPPABLE_IN_AMOUNTS[pairedTokenId][threadId]) {
            _pairedFinalAmount = pairedTokenId == 0
                ? _pairedFinalAmount * SWAP_RATE_1
                : _pairedFinalAmount / SWAP_RATE_1;

            if (_pairedFinalAmount <= _finalAmount) return _pairedFinalAmount;
        }

        if (_finalAmount <= MAX_SWAPPABLE_IN_AMOUNTS[tokenId][threadId]) return _finalAmount;

        return 0;
    }

    /**
     * @dev Performs token swap initiated without providing thread ID.
     */
    function _onReceivedWithoutData(address sender, uint256 tokenId, uint256 pairedTokenId, uint256 amount) private {
        // Check that:
        // - Token #1 amount is a multiple of the swap rate.
        // - `amount` is not less than the minimum acceptable for `tokenId` token.
        // - After the used token decimals, all digits of swap amounts are zeroes.
        require(amount != 0, 'MegaSwapFund: amount is 0');

        if (tokenId == 0) {
            require(amount % MIN_SWAPPABLE_IN_AMOUNT_0 == 0, 'MegaSwapFund: out of max used decimal precision');
        } else {
            require(amount % MIN_SWAPPABLE_IN_AMOUNT_1 == 0, 'MegaSwapFund: out of max used decimal precision');
        }

        uint256 threadId;

        // Select thread based on `amount`.
        unchecked {
            while (threadId < THREAD_COUNT && amount > MAX_SWAPPABLE_IN_AMOUNTS[tokenId][threadId]) ++threadId;
        }

        // Check that `amount` of `tokenId` token is not larger than the maximum acceptable.
        require(threadId < THREAD_COUNT, 'MegaSwapFund: amount too large');

        ReciprocalSwapCounters storage reciprocalSwaps = _reciprocalSwaps[threadId];

        // Check that swap-out counter of `pairedTokenId` token is not finalized.
        require(reciprocalSwaps.swapouts[pairedTokenId] != 0, 'MegaSwapFund: paired swap-out counter is 0');

        // Check that swap-in counter of `tokenId` token is not finalized.
        uint256 index = (threadId << 1) + tokenId;
        require(_swapinsFinalized.getBit(index) == 0, 'MegaSwapFund: swap-in counter is already finalized');

        // Calculate paired token amount.
        uint256 pairedAmount = tokenId == 0 ? amount * SWAP_RATE_1 : amount / SWAP_RATE_1;

        uint256 _pairedReturnAmount;

        // Calculate return amount if paired token amount would underflow its swap-out counter.
        if (pairedAmount > reciprocalSwaps.swapouts[pairedTokenId]) {
            unchecked {
                _pairedReturnAmount = pairedAmount - reciprocalSwaps.swapouts[pairedTokenId];

                _pairedReturnAmount = pairedTokenId == 0
                    ? _pairedReturnAmount * SWAP_RATE_1
                    : _pairedReturnAmount / SWAP_RATE_1;
            }
        }

        uint256 _returnAmount;
        uint256 _swapin = reciprocalSwaps.swapins[tokenId] + amount;

        // Calculate return amount if swap-in counter would overflow its maximum.
        if (_swapin > MAX_SWAPIN_COUNTERS[tokenId][threadId]) {
            unchecked {
                _returnAmount = _swapin - MAX_SWAPIN_COUNTERS[tokenId][threadId];
            }
        }

        // If there is any return amount, transfer it back to `sender` and recalculate swap amounts.
        if (_pairedReturnAmount != 0 || _returnAmount != 0) {
            if (_returnAmount < _pairedReturnAmount) _returnAmount = _pairedReturnAmount;

            unchecked {
                amount -= _returnAmount;

                pairedAmount = tokenId == 0 ? amount * SWAP_RATE_1 : amount / SWAP_RATE_1;
            }

            IERC20(tokenId == 0 ? TOKEN_0 : TOKEN_1).transfer(sender, _returnAmount);
        }

        _swapReceivedAmount(sender, threadId, tokenId, pairedTokenId, amount, pairedAmount);
    }

    /**
     * @dev Updates values of swap counters and transfers `pairedAmount`
     * of `pairedToken` to `sender`.
     */
    function _swapReceivedAmount(
        address sender,
        uint256 threadId,
        uint256 tokenId,
        uint256 pairedTokenId,
        uint256 amount,
        uint256 pairedAmount
    ) private {
        unchecked {
            _totalSwapins[tokenId][threadId] += amount;
            _totalTokenSwapins[tokenId] += amount;
        }

        ReciprocalSwapCounters storage reciprocalSwaps = _reciprocalSwaps[threadId];

        reciprocalSwaps.swapouts[pairedTokenId] -= pairedAmount;
        reciprocalSwaps.swapouts[tokenId] += amount;
        reciprocalSwaps.swapins[tokenId] += amount;

        IERC20(pairedTokenId == 0 ? TOKEN_0 : TOKEN_1).transfer(sender, pairedAmount);

        if (tokenId == 0) emit SwapIn_0(threadId, amount);
        else emit SwapIn_1(threadId, amount);

        // Check if `tokenId` swap-in counter is to be finalized.
        if (MAX_SWAPIN_COUNTERS[tokenId][threadId] - reciprocalSwaps.swapins[tokenId] == 0) {
            _finalizeSwapinCounterAndAttestPeriod(threadId, tokenId);
        }
    }

    /**
     * @dev Sets finalization flag of `tokenId` swap-in counter.
     * If paired swap-in counter is also finalized then increments period counter
     * and starts the next period at `threadId` thread.
     */
    function _finalizeSwapinCounterAndAttestPeriod(uint256 threadId, uint256 tokenId) private {
        emit FinalizeSwapinCounter(
            threadId,
            tokenId,
            _periodNumbers[threadId],
            _totalSwapins[tokenId][threadId],
            _totalTokenSwapins[tokenId]
        );

        uint256 pairedIndex = (threadId << 1) + 1 - tokenId;

        // Paired swap-in counter is also finalized, start the next period at `threadId` thread.
        if (_swapinsFinalized.getBit(pairedIndex) == 1) {
            // Reset reciprocal swap counters.
            _resetReciprocalSwapCounters(threadId);

            // Clear finalization flags of both swap-in counters.
            uint256 index_0 = threadId << 1;
            uint256 mask = 3 << index_0;

            _swapinsFinalized &= ~mask;

            // Increment period number and emit `StartPeriod`.
            unchecked {
                emit StartPeriod(threadId, ++_periodNumbers[threadId]);
            }
        }
        // Paired swap-in counter is not finalized, only finalize `tokenId` swap-in counter.
        else {
            // Set finalization flag of `tokenId` swap-in counter.
            uint256 index = (threadId << 1) + tokenId;
            _swapinsFinalized = _swapinsFinalized.setBit(index);
        }
    }

    /**
     * @dev Resets reciprocal swap counters to their initial values for a new
     * period of `threadId` thread.
     */
    function _resetReciprocalSwapCounters(uint256 threadId) private {
        _reciprocalSwaps[threadId].swapins[0] = _reciprocalSwaps[threadId].swapins[1] = 0;
        _reciprocalSwaps[threadId].swapouts[0] = INIT_SWAPOUT_COUNTERS[0][threadId];
        _reciprocalSwaps[threadId].swapouts[1] = INIT_SWAPOUT_COUNTERS[1][threadId];
    }
}
