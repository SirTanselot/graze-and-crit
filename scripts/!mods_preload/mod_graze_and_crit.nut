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
	local damageSettings = ::GrazeAndCrit.Mod.ModSettings.addPage("Damage");

	// Disabled for now until I figure out how to cap/uncap hit chance based on this setting.
	// page.addBooleanSetting(
	// 	"GC_Enable", 
	// 	true, 
	// 	"Enable Graze and Crit", 
	// 	"Enables hits to graze for half damage or crit for 1.5x damage, based on roll. (Disabling this still keeps hit/miss chances uncapped.)")
	// .addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.IsEnabled = _newValue; });

	damageSettings.addTitle("damageModifiersTitle", "Damage Multipliers");

	damageSettings.addRangeSetting(
		"GC_CritDamage",
		::GrazeAndCrit.Config.Multipliers.crit, 
		0.0, 4.0, 0.05,
		"Crit",
		"[Default: 1.5]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.crit = _newValue; });

	damageSettings.addRangeSetting(
		"GC_HitDamage",
		::GrazeAndCrit.Config.Multipliers.hit, 
		0.0, 4.0, 0.05,
		"Hit",
		"[Default: 1.0]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.hit = _newValue; });

	damageSettings.addRangeSetting(
		"GC_GrazeDamage",
		::GrazeAndCrit.Config.Multipliers.graze, 
		0.0, 4.0, 0.05,
		"Graze",
		"[Default: 0.5]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.Multipliers.graze = _newValue; });

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

	generalSettings.addTitle("diminishingDefenseTitle", "Defense", "Various mechanics to diminish the effectiveness of high defense.");

	generalSettings.addBooleanSetting(
		"GC_EnableLogarithmicDefenseDecay", 
		::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay, 
		"Apply logarithmic decay", 
		"Makes defense less effective by making graze chances below 25% to decrease logarithmically instead of linearly. Intended as a more granular and consistent alternative to vanilla's defense halving. (Vanilla's halving depends only on the defender's defense. Logarithmic decay also accounts for the attacker's skill.) [Default: Enabled.]")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.EnableLogarithmicDefenseDecay = _newValue; });

	generalSettings.addBooleanSetting(
		"GC_KeepVanillaDiminishingDefense", 
		::GrazeAndCrit.Config.KeepVanillaDiminishingDefense, 
		"Apply vanilla halving", 
		"Vanilla mechanic that halves the effect of any defense over 50. If used alongside logarithmic decay, vanilla diminishing of defense is applied first. [Default: Disabled.]")
	.addBeforeChangeCallback(function( _newValue) { ::GrazeAndCrit.Config.KeepVanillaDiminishingDefense = _newValue; });

	generalSettings.addRangeSetting(
		"GC_DefenseToHalveHitChance", 
		::GrazeAndCrit.Config.DefenseToHalveHitChance, 
		5.0, 50.0, 0.5,
		"Defense to halve hit chance",
		"Increasing defense by this amount halves the hit chance when logarithmic decay is enabled. Applies cumulatively and considers fractional values. [Default: 35 (results in a seamless transition from linear to logarithmic)]")
	.addBeforeChangeCallback(function( _newValue ) { ::GrazeAndCrit.Config.DefenseToHalveHitChance = _newValue; });
});
