// Compatibility for Reforged: Treat 3hf as just another flail.
// TODO: 3-attack version with logging.
// if (::Hooks.hasMod("mod_reforged")) {
// 	::GrazeAndCrit.MH.hook("scripts/skills/actives/hail_skill", function(q) {

// 		// Graze and Crit: Copied from chop to simplify for now.
// 		q.onUse = @() { function onUse( _user, _targetTile )
// 		{
// 			this.spawnAttackEffect(_targetTile, this.Const.Tactical.AttackEffectChop);
// 			return this.attackEntity(_user, _targetTile.getEntity());
// 		}}.onUse;

// 		q.onBeforeTargetHit = @() { function onBeforeTargetHit( _skill, _targetEntity, _hitInfo )
// 		{
// 			// this.m.IsUsingHitchance = true;
// 		}}.onBeforeTargetHit;

// 		q.onAnySkillUsed = @() { function onAnySkillUsed( _skill, _targetEntity, _properties )
// 		{
// 			if (_skill == this) {
// 				_properties.HitChance[this.Const.BodyPart.Head] += 100.0;
// 			}
// 			// if (_skill == this && this.m.IsAttacking)
// 			// {
// 			// 	_properties.DamageTotalMult *= this.m.RerollDamageMult;
// 			// }
// 		}}.onAnySkillUsed;
// 	});
// }