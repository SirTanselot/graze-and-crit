::GrazeAndCrit <- {
	ID = "mod_graze_and_crit",
	Name = "Graze and Crit",
	Version = "1.0.3"
}

::GrazeAndCrit.MH <- ::Hooks.register(::GrazeAndCrit.ID, ::GrazeAndCrit.Version, ::GrazeAndCrit.Name);
::GrazeAndCrit.MH.require("mod_modular_vanilla >= 0.5.1");

::GrazeAndCrit.MH.queue(">mod_modular_vanilla", function () {

	foreach (file in ::IO.enumerateFiles("mod_graze_and_crit"))
	{
		::include(file);
	}

	::GrazeAndCrit.Mod <- ::MSU.Class.Mod(::GrazeAndCrit.ID, ::GrazeAndCrit.Version, ::GrazeAndCrit.Name);
	
	local generalSettings = ::GrazeAndCrit.Mod.ModSettings.addPage("General");
	generalSettings.addBooleanSetting(
		"GC_Enable", 
		true, 
		"Enable Graze and Crit")
	.addBeforeChangeCallback(function( _newValue) { 
    ::GrazeAndCrit.Config.IsEnabled = _newValue; 
    if (_newValue == true) {
      ::Const.Combat.MV_HitChanceMin = -1000;
      ::Const.Combat.MV_HitChanceMax = 1000;
    }
    else {
      ::Const.Combat.MV_HitChanceMin = 5;
      ::Const.Combat.MV_HitChanceMax = 95;
    }
  });

 	generalSettings.addEnumSetting(
    "GC_Model", 
    "Piecewise Linear", 
    ["Piecewise Linear", 
     "Logistics Curve",
     "Logistics Curve with Guarantees"
    ], 
    "Hit chance model", 
    "\'Piecewise Linear\': Graze and hit chances first linearly increase then linearly decrease with Advantage, forming two triangles that peak at 50 and 100, respectively. It is a simple model and guarantees 0% miss, graze, hit or crit chances at certain breakpoints. It optionally allows for a logarithmic decay of graze chance to ensure that there is always some chance for a hit. \n\n\'Logistics Curve\': Uses more complicated math behind the scenes to ensure that expected damage and outcome chances scale smoothly with Advantage. It allows all outcomes to happen at any Advantage, possibly at a significantly reduced rate. (For instance, crit chance is 0.4%, 0.1% and 0% at 15, 0 and -15 Advantage, respectively.) \n\n\'Logistics Curve with Guarantees: Disables crits below 50 and hits below 0 advantage (grazes and misses can always happen).\'");

	generalSettings.addBooleanSetting(
		"GC_KeepVanillaDiminishingDefense", 
		::GrazeAndCrit.Config.KeepVanillaDiminishingDefense, 
		"Apply vanilla defense halving", 
		"Vanilla mechanic that halves the effect of any defense over 50. If used alongside logarithmic decay, vanilla diminishing of defense is applied first. [Default: Disabled.]")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.KeepVanillaDiminishingDefense = _newValue; });

	// generalSettings.addTitle("grazeMissChance", "Percentage of grazes that fail to apply effects", "With this setting, some grazes are registered as misses for various effects (disarm, stun, etc) but they still apply their damage.");
	generalSettings.addRangeSetting(
		"GC_GrazeMissChance",
		::GrazeAndCrit.Config.graze_count_as_miss_percentage, 
		0.0, 100.0, 5.0,
		"Percentage of grazes that fail to apply effects",
		"Experimental feature that makes some portion of grazes to not register as hits for the purposes of applying certain effects. [Default: 50 percent. Set to 0 to disable.]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.graze_count_as_miss_percentage = _newValue; });

 	generalSettings.addRangeSetting(
    "GC_Precision", 2, 0, 6, 1, "Roll precision", "Number of decimal places to add to dice rolls and tooltips. 0 precision means using integer dice rolls from 0-100 and may make outcome chances less responsive to Advantage changes.")
	.addBeforeChangeCallback(function( _newValue ) { 
    ::GrazeAndCrit.Config.PrecisionMultiplier = pow(10.0, _newValue); 
  });

  // ADVANTAGE
  // TODO: New page?
	generalSettings.addTitle("hitChanceTitle", "Advantage", "Advantage is the uncapped vanilla hit chance and is used by this mod to determine the chances that an attack crits, hits, grazes or misses. The settings below allow changing the computation of advantage as (uncapped_vanilla_hitchance + additive) * multiplicative.");

	generalSettings.addRangeSetting(
		"GC_HitChanceModifier", 
		::GrazeAndCrit.Config.HitChanceModifier, 
		-100.0, 100.0, 2.5, 
		"Additive modifier",
		"Adjusts vanilla hit chances by adding or subtracting this amount when computing advantage. [Default: 0]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.HitChanceModifier = _newValue; });

	generalSettings.addRangeSetting(
		"GC_HitChanceMultiplier", 
		::GrazeAndCrit.Config.HitChanceMultiplier, 
		0.05, 4.0, 0.05, 
		"Multiplicative modifier",
		"Adjusts vanilla hit chances by multiplying it by this amount when computing advantage. Applied after the additive modifier. Higher values make attack and defense more important. [Default: 1]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.HitChanceMultiplier = _newValue; });

	generalSettings.addBooleanSetting(
		"GC_ShowVanillaHitChanceTooltip", 
		::GrazeAndCrit.Config.ShowVanillaHitChanceTooltip, 
		"Show vanilla hitchance in tooltip")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.ShowVanillaHitChanceTooltip = _newValue; });

	generalSettings.addBooleanSetting(
		"GC_ShowAdvantageTooltip", 
		::GrazeAndCrit.Config.ShowAdvantageTooltip, 
		"Show advantage in tooltip")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.ShowAdvantageTooltip = _newValue; });

	generalSettings.addTitle("triangularModelSettings", "Piecewise Linear Model Settings");

	generalSettings.addBooleanSetting(
		"GC_EnableLogarithmicDefenseDecay", 
		::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay, 
		"Apply logarithmic decay", 
		"Makes defense less effective by making graze chances below 25% to decrease logarithmically instead of linearly. Intended as a more granular and consistent alternative to vanilla's defense halving. (Vanilla's halving depends only on the defender's defense. Logarithmic decay also accounts for the attacker's skill.) [Default: Enabled.]")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay = _newValue; });

	generalSettings.addRangeSetting(
		"GC_DefenseToHalveHitChance", 
		::GrazeAndCrit.Config.DefenseToHalveHitChance, 
		5.0, 50.0, 0.5,
		"Defense to halve hit chance",
		"Increasing defense by this amount halves the hit chance when logarithmic decay is enabled. Applies cumulatively and considers fractional values. [Default: 35 (results in a seamless transition from linear to logarithmic)]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.DefenseToHalveHitChance = _newValue; });

	local damageSettings = ::GrazeAndCrit.Mod.ModSettings.addPage("Damage");
  damageSettings.addTitle("damageModifiersTitle", "Damage Multipliers");

	damageSettings.addRangeSetting(
		"GC_CritDamage",
		::GrazeAndCrit.Config.Multipliers.crit, 
		0.0, 3.0, 0.05,
		"Crit",
		"[Default: 1.5]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.crit = _newValue; });

	damageSettings.addRangeSetting(
		"GC_HitDamage",
		::GrazeAndCrit.Config.Multipliers.hit, 
		0.0, 3.0, 0.05,
		"Hit",
		"[Default: 1.0]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.hit = _newValue; });

	damageSettings.addRangeSetting(
		"GC_GrazeDamage",
		::GrazeAndCrit.Config.Multipliers.graze, 
		0.0, 3.0, 0.05,
		"Graze",
		"[Default: 0.5]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.graze = _newValue; });

});
