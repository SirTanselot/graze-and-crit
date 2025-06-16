::GrazeAndCrit.Core <- {
	function computeAdvantage( _baseToHit ) {
		return (_baseToHit + ::GrazeAndCrit.Config.HitChanceModifier) * ::GrazeAndCrit.Config.HitChanceMultiplier;
	}

	function roundToPrecision ( _val ) {
		local precisionMultiplier = ::GrazeAndCrit.Config.PrecisionMultiplier;
		return this.Math.round( _val * precisionMultiplier) / precisionMultiplier;
	}

	function getHitOutcomeChances( _baseToHit ) {
		// Expressed as percentages. Should sum up to 100.0.
		local chances = {
			miss  = 0.0,
			graze = 0.0,
			hit  = 0.0,
			crit  = 0.0
		};

		local advantage = computeAdvantage(_baseToHit);

		local computeChanceByDistanceFromPeak = function(_peak) {
			// Computes roundToPrecision(this.Math.max(0.0, 50.0 - 0.5 * this.Math.abs(peak - advantage))) but works for floats.
			local diff = _peak - advantage;
			diff = diff < 0 ? -diff : diff;	// this.Math.abs but for floats.
			local chance = 50.0 - 0.5 * diff;
			chance = chance < 0 ? 0 : chance; // this.Math.max(0, chance) but for floats.
			return roundToPrecision(chance);
		};

		// {-50 ->  50 -> 150} advantage = {  0 ->  50 ->  0}% chance to graze for half damage.
		chances.graze = computeChanceByDistanceFromPeak( 50.0);
		// {  0 -> 100 -> 200} advantage = {  0 ->  50 ->  0}% chance for a regular hit.
		chances.hit   = computeChanceByDistanceFromPeak(100.0);
		// { 50 -> 150 -> 250} advantage = {  0 ->  50 ->  0}% chance to crit for 1.5x damage.
		chances.crit  = computeChanceByDistanceFromPeak(150.0);

		if (::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay && advantage < 0.0) {	
			// Below 0: All hits are grazes. 0 is 25% chance for a grazing hit. Every DefenseToHalveHitChance halves this chance.
			local exponent = (0 - advantage) / ::GrazeAndCrit.Config.DefenseToHalveHitChance;
			local graze = 25.0 * this.Math.pow(0.5, exponent);
			// Only use the first two decimal places.
			chances.graze = roundToPrecision(graze);
		}

		local remainder = 100.0 - (chances.graze + chances.hit + chances.crit);
		if (advantage >= 100) {
			chances.crit = chances.crit + remainder;
		}
		else {
			chances.miss = chances.miss + remainder;
		}
		return chances;
	}

	function getAlwaysHitOutcomeChances() {
		return {
			miss  = 0.0,
			graze = 0.0,
			hit  = 100.0,
			crit  = 0.0
		};
	}

	function getAlwaysMissOutcomeChances() {
		return {
			miss  = 100.0,
			graze = 0.0,
			hit  = 0.0,
			crit  = 0.0
		};
	}

	function getHitOutcomeThresholds( _chances ) {
		// Expressed in percentages. Built in reverse (since low rolls are better in vanilla). 
		// Each entry is the cumulative chance of the attack resulting in the corresponding or a more damaging outcome.
		local thresholds = {
			miss  = 0.0,
			graze = 0.0,
			hit  = 0.0,
			crit  = 0.0
		};
		thresholds.crit  = _chances.crit;
		thresholds.hit  = thresholds.crit + _chances.hit;
		thresholds.graze = thresholds.hit  + _chances.graze;
		thresholds.miss  = thresholds.graze + _chances.miss;
		assert(abs(thresholds.miss - 100.0) < 0.01);

		return thresholds;
	}
}
