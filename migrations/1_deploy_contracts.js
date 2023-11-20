const MegaSwapFundArtifact = artifacts.require('MegaSwapFund');
const MegaMergerArtifact = artifacts.require('MegaMerger');
const MegaSplitterArtifact = artifacts.require('MegaSplitter');

module.exports = (deployer) => {
	const maxSwappableInAmountsCoeff = 20;
	const holdersSupplyCoeff = 4;

	const _INIT_SWAPOUT_COUNTERS_0 = [];
	const THREAD_COUNT = 20;
	const swapFundSupply = 1e8;

	let s0;
	let unscaledSum = 0;

	// `_INIT_SWAPOUT_COUNTERS_0` values are best visualized on graph
	// when referred to as both points and volumes.
	// Therefore they should be values of an integral over the interval [i-1; i].
	//
	// But we use y=e^x here, so, in our case, integral is the same (F(e^x)=e^x).
	// If you use another function, your integral would be different.
	//
	// NOTE: The integrand and the x interval we use here are just our random choice,
	// they also can be many others.
	for (let i = 0; i <= THREAD_COUNT; ++i) {
		const x = (Math.E / THREAD_COUNT) * i;

		if (i > 0) {
			const unscaled = Math.exp(x) - s0;

			_INIT_SWAPOUT_COUNTERS_0.push(unscaled);
			unscaledSum += unscaled;
		}

		s0 = Math.exp(x);
	}

	const scaler_div100 = swapFundSupply / unscaledSum / 100;
	let approxSum = 0;

	for (let i = 0; i < THREAD_COUNT; ++i) {
		// Scale value to `swapFundSupply`.
		// Also, excessively round it to make even more "human friendly".
		const scaled = Math.round(_INIT_SWAPOUT_COUNTERS_0[i] * scaler_div100) * 100;

		_INIT_SWAPOUT_COUNTERS_0[i] = scaled;
		approxSum += scaled;
	}

	// Make total sum equal to `swapFundSupply` (if it is not).
	_INIT_SWAPOUT_COUNTERS_0[THREAD_COUNT - 1] += swapFundSupply - approxSum;

	const decNumerator = BigInt(1e18);

	for (let i = 0; i < THREAD_COUNT; ++i) {
		_INIT_SWAPOUT_COUNTERS_0[i] = BigInt(_INIT_SWAPOUT_COUNTERS_0[i]) * decNumerator;
	}

	// Deploy
	deployer.deploy(MegaSwapFundArtifact, _INIT_SWAPOUT_COUNTERS_0, maxSwappableInAmountsCoeff, holdersSupplyCoeff);
};
