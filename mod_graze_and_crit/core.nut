::GrazeAndCrit.Core <- {
	function computeAdvantage( _baseToHit ) {
		return (_baseToHit + ::GrazeAndCrit.Config.HitChanceModifier) * ::GrazeAndCrit.Config.HitChanceMultiplier;
	}

	function roundToPrecision ( _val ) {
		local precisionMultiplier = ::GrazeAndCrit.Config.PrecisionMultiplier;
		return this.Math.round( _val * precisionMultiplier) / precisionMultiplier;
	}
  
  function logisticsCurve ( _x, _growth, _mid ) {
    local val = (_x - _mid) / 100.0;
    return 100.0 / (1.0 + exp(-_growth * val));
  }

  // Follows the computation here: https://www.desmos.com/calculator/z0au984k3r
  function computePiecewiseLinearHitOutcomeChances ( _advantage ) {
		// Expressed as percentages. Should sum up to 100.0.
		local chances = {
			miss  = 0.0,
			graze = 0.0,
			hit  = 0.0,
			crit  = 0.0
		};
    
    local computeChanceByDistanceFromPeak = function(_peak) {
			// Computes roundToPrecision(this.Math.max(0.0, 50.0 - 0.5 * this.Math.abs(peak - advantage))) but works for floats.
			local diff = _peak - _advantage;
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

		if (::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay && _advantage < 0.0) {	
			// Below 0: All hits are grazes. 0 is 25% chance for a grazing hit. Every DefenseToHalveHitChance halves this chance.
			local exponent = (0 - _advantage) / ::GrazeAndCrit.Config.DefenseToHalveHitChance;
			local graze = 25.0 * this.Math.pow(0.5, exponent);
			// Only use the first two decimal places.
			chances.graze = roundToPrecision(graze);
		}

		local remainder = 100.0 - (chances.graze + chances.hit + chances.crit);
		if (_advantage >= 100) {
			chances.crit = chances.crit + remainder;
		}
		else {
			chances.miss = chances.miss + remainder;
		}
		return chances;
  }

  // Follows the computation here: https://www.desmos.com/calculator/u7jbnzpvwa
  function computeLogisticsCurveHitOutcomeChances ( _advantage ) {
    // NOTE 1: These parameters are selected to track vanilla expected damage 
    // almost exactly from 50-100 attack.
    // NOTE 2: There is no need to expose these parameters to config since the 
    // already exposed multiplicative and additive modifiers for Advantage
    // calculations are equivalent to `growth_rate` and `mid`, respectively.
    local growth_rate = 2.75;
    local mid = 75.0

    // s = success_chance, f = fail_chance.
    local s = logisticsCurve(_advantage, growth_rate, mid)/100.0;
    local f = 1.0-s;

    // Use the 3-headed flail model of damage, where 0 successes result in a 
    // miss and 3 successes result in a critical hit.
		local chances = {
			miss  = roundToPrecision(100 * f * f * f), 
			graze = roundToPrecision(300 * f * f * s),
			hit   = roundToPrecision(300 * f * s * s),
			crit  = roundToPrecision(100 * s * s * s),
		};

    // Fix possible rounding errors.
    local newMissChance = 100.0 - chances.graze - chances.hit - chances.crit;
    assert(abs(chances.miss - newMissChance) < 0.01);
    chances.miss = newMissChance;

		return chances;
  }

	function getHitOutcomeChances( _baseToHit ) {
		local advantage = computeAdvantage(_baseToHit);
    
		local isShowingValue = false;
		switch (::GrazeAndCrit.Mod.ModSettings.getSetting("GC_Model").getValue())
		{
			case "Piecewise Linear":
        return computePiecewiseLinearHitOutcomeChances(advantage);
			case "Logistics Curve":
        return computeLogisticsCurveHitOutcomeChances(advantage);
		}
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

  function computeOutcome ( _roll, _thresholds ) {
    local outcome = {
      doDamage = true,
      applyEffects = true,
      damageMultiplier = 1.0,
      message = "",
    };

		local colors = ::GrazeAndCrit.Config.HitOutcomeColors;

		if (_roll <= _thresholds.crit) {
			outcome.message = this.Const.UI.getColorized("critically hits", colors.crit);
			outcome.damageMultiplier = ::GrazeAndCrit.Config.Multipliers.crit;
		}
		else if (_roll <= _thresholds.hit) {
			outcome.message = this.Const.UI.getColorized("hits", colors.hit);
			outcome.damageMultiplier = ::GrazeAndCrit.Config.Multipliers.hit;
		}
		else if (_roll <= _thresholds.graze) {
			outcome.message = this.Const.UI.getColorized("grazes", colors.graze);
      outcome.damageMultiplier = ::GrazeAndCrit.Config.Multipliers.graze;

      // Determine whether this is a graze that can apply status effects or not.
      // Instead of a new roll, divide the range [threshold.hit, threshold.graze]
      // and use the existing roll (smaller is better = applies status effect).
      local status_chance = 1.0 - ::GrazeAndCrit.Config.graze_count_as_miss_percentage/100.0;
      local status_threshold = _thresholds.graze * status_chance 
                               + _thresholds.hit * (1.0 - status_chance);
      outcome.applyEffects = _roll <= status_threshold;      
		}
		else {
			assert(_roll <= _thresholds.miss + 0.01);
			outcome.message = this.Const.UI.getColorized("misses", colors.miss);
      outcome.doDamage = false;
      outcome.applyEffects = false;
		}
    
    return outcome;
  }
}
