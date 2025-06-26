::GrazeAndCrit.Core <- {
	function computeAdvantage( _baseToHit ) {
		return (_baseToHit + ::GrazeAndCrit.Config.HitChanceModifier) * ::GrazeAndCrit.Config.HitChanceMultiplier;
	}

	function roundToPrecision ( _val ) {
		local precisionMultiplier = ::GrazeAndCrit.Config.PrecisionMultiplier;
		return this.Math.round( _val * precisionMultiplier) / precisionMultiplier;
	}
  
  function roundAndVerify ( _chances ) {
    local chances = {
      miss = roundToPrecision(_chances.miss),
      graze = roundToPrecision(_chances.graze),
      hit = roundToPrecision(_chances.hit),
      crit = roundToPrecision(_chances.crit),
    };
    
    // Fix possible rounding errors.
    local newMissChance = 100.0 - chances.graze - chances.hit - chances.crit;
    assert(abs(chances.miss - newMissChance) < 0.01);
    chances.miss = newMissChance;
    
    assert(chances.miss >= 0);
    assert(chances.graze >= 0);
    assert(chances.hit >= 0);
    assert(chances.crit >= 0);
		return chances;
  }

  function logisticsCurve100 ( _x, _growth, _mid ) {
    local val = (_x - _mid) / 100.0;
    return 100.0 / (1.0 + exp(-_growth * val));
  }
  
  // A piecewise quadratic function. As _x increases from 0 to 1, f(x) also
  // also increases from 0 to 1. It's slope begins and ends at 0 and is 
  // continuous, giving the function a smooth look even in [-inf, inf] range.
  function quadraticS (_x) {
    if (_x < 0.0) {
      return 0.0;
    }
    if (_x < 0.5) {
      return _x*_x/0.5;
    }
    if (_x < 1.0) {
      return 1 - (x-1)*(x-1)/0.5;
    }
    return 1.0;
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

    // TODO: Switch to use roundAndVerify.
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
    local s = logisticsCurve100(_advantage, growth_rate, mid)/100.0;
    local f = 1.0-s;

    // TODO: Switch to use roundAndVerify.
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

  // TODO: Graph
  // Similar to computeLogisticsCurveHitOutcomeChances, but guarantees no crits 
  // below 50 and no full hits below 0 advantage.
  function computeLogisticsCurveWithGuaranteesHitOutcomeChances ( _advantage ) {
    local x = _advantage;
    local chances = computeLogisticsCurveHitOutcomeChances(x);

    // Ensure that normal hits don't happen below 0 advantage.
    local hitReduction = 0;
    if (x < 0) {
      hitReduction = chances.hit;
    }
    else {
      // We want to reduce hit above 0 as well so that the transition is 
      // smooth. To ensure that both the transition and the slope of the 
      // transition is smooth and continuous, we do the following:
      // 1) Below 0, we know the original hit function hit(x) is smooth.
      // 2) Above 0, we reflect the below-0 part around (x, hit(x)). This has
      //    the unintended side effect that we are now trying to remove more
      //    hit above 0 than below 0.
      // 3) We gradually decay the above 0 part down to 0.
      local hitAtZero = computeLogisticsCurveHitOutcomeChances(0).hit;
      local hitAtMinusX = computeLogisticsCurveHitOutcomeChances(-x).hit;
      hitReduction = 2*hitAtZero - hitAtMinusX; // Reflect.
      hitReduction = hitReduction * (1.0 - quadraticS(x/150)); // Decay.      
    }

    // Ensure that crits don't happen below 50 advantage.
    local critReduction = 0;
    if (x < 50) {
      critReduction = chances.crit;
    }
    else {
      // Same logic as hits, except we reflect around (50, crit(50))
      local critAt50 = computeLogisticsCurveHitOutcomeChances(50).crit;
      local critAt100MinusX = computeLogisticsCurveHitOutcomeChances(100.0 - x).crit;
      critReduction = 2*critAt50 - critAt100MinusX; // Reflect.
      critReduction = critReduction * (1.0 - quadraticS((x - 50)/150)); // Decay.      
    }

    // Shuffle around chances while ensuring that expected damage is the same.
    chances.hit -= hitReduction;
    chances.graze += 2*hitReduction;
    chances.miss -= hitReduction;

    chances.crit -= critReduction;
    chances.hit += 2*critReduction;
    chances.graze -= critReduction;

    return roundAndVerify(chances)
  }

	function getHitOutcomeChances( _baseToHit ) {
		local advantage = computeAdvantage(_baseToHit);
    
		local isShowingValue = false;
		switch (::GrazeAndCrit.Mod.ModSettings.getSetting("GC_Model").getValue())
		{
			case "Piecewise Linear":
        return computePiecewiseLinearHitOutcomeChances(advantage);
			case "Smooth":
        return computeLogisticsCurveHitOutcomeChances(advantage);
      case "Smooth with Guarantees":
        return computeLogisticsCurveWithGuaranteesHitOutcomeChances(advantage);
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
