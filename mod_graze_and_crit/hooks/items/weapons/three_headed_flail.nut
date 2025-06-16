if (!::Hooks.hasMod("mod_reforged")) {
	return;
}

::GrazeAndCrit.MH.hook("scripts/items/weapons/three_headed_flail", function(q) {
	// 	q.create = @(__original) { function create()
	// 	{
	// 		__original();
	// 		this.m.RegularDamage = 15;
	// 	}}.create;
	// 


	q.onEquip = @() { function onEquip()
	{
		this.weapon.onEquip();

		this.addSkill(::Reforged.new("scripts/skills/actives/flail_skill", function(o) {
			o.m.FatigueCost += 2;
		}));

		this.addSkill(::Reforged.new("scripts/skills/actives/lash_skill", function(o) {
			o.m.FatigueCost += 5;
		}));
	}}.onEquip;
});
