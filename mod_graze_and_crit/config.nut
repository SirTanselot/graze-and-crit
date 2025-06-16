::GrazeAndCrit.Config <- {
	IsEnabled = true,	// TODO: Needs more work.

	HitChanceMultiplier = 1.0,
	HitChanceModifier = 0.0,

	KeepVanillaDiminishingDefense = false, // TODO
	EnableLogarithmicDefenseDecay = true,
	DefenseToHalveHitChance = 35.0,

	// Rolls are made with 0.01 precision.
	PrecisionMultiplier = 100.0,

	ShowVanillaHitChanceTooltip = false,
	ShowAdvantageTooltip = true,

	Multipliers = {
		graze = 0.5,
		hit = 1.0,
		crit = 1.5,
	},

	HitOutcomeColors = {
		// TODO: Config?
		miss  = "#4a4747",
		graze = "#135213",
		hit  = "#1e417d",
		crit  = "#8f1e1e",
	},
};

// Remove hit chance caps.
::Const.Combat.MV_HitChanceMin = -1000;
::Const.Combat.MV_HitChanceMax = 1000;
