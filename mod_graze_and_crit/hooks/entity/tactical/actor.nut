::GrazeAndCrit.MH.hook("scripts/entity/tactical/actor", function(q) {
	// Overwrite vanilla function to optionally disable defense over 50 getting diminished by half.
	q.getDefense = @(__original) function( _attackingEntity, _skill, _properties ) {
		local malus = 0;
		local d = 0;

		if (!this.m.CurrentProperties.IsImmuneToSurrounding)
		{
			malus = _attackingEntity != null ? this.Math.max(0, _attackingEntity.getCurrentProperties().SurroundedBonus * _attackingEntity.getCurrentProperties().SurroundedBonusMult - this.getCurrentProperties().SurroundedDefense) * this.getSurroundedCount() : this.Math.max(0, 5 - this.getCurrentProperties().SurroundedDefense) * this.getSurroundedCount();
		}

		if (_skill.isRanged())
		{
			d = _properties.getRangedDefense();
		}
		else
		{
			d = _properties.getMeleeDefense();
		}

		// Graze and Crit: Only diminish def above 50 if allowed by config.
    local diminishDefense = !::GrazeAndCrit.Config.IsEnabled || ::GrazeAndCrit.Config.KeepVanillaDiminishingDefense;
		if (diminishDefense && d > 50)
		{
			local e = d - 50;
			d = 50 + e * 0.5;
		}

		if (!_skill.isRanged())
		{
			d = d - malus;
		}

		return d;
	}

	// Change tooltip to rename vanilla hit chance to "Advantage" and to display the breakdown of crit/hit/graze/miss chances.
	q.getTooltip = @(__original) function( _targetedWithSkill = null ) {
		local ret = __original(_targetedWithSkill);
		if (::GrazeAndCrit.Config.IsEnabled == false) {
			return ret;
		}

		if (!this.isPlacedOnMap() || !this.isAlive() || this.isDying()) return ret;
		if (this.isDiscovered() == false) return ret;
		if (this.isHiddenToPlayer()) return ret;

		foreach (entry in ret)
		{
			if (entry.id == 3)
			{
				if (_targetedWithSkill != null && this.isKindOf(_targetedWithSkill, "skill") && _targetedWithSkill.isUsingHitchance())
				{
					local tile = this.getTile();

					if (tile.IsVisibleForEntity && _targetedWithSkill.isUsableOn(tile))
					{
						local hitchance = _targetedWithSkill.getHitchance(this);
						local advantage = ::GrazeAndCrit.Core.computeAdvantage(hitchance);
						// May be buggy display if hit is always hit or always miss.
						local chances = ::GrazeAndCrit.Core.getHitOutcomeChances(hitchance);
						local colors = ::GrazeAndCrit.Config.HitOutcomeColors;

						local possible_outcomes = [];
						if (chances.crit > 0.0) {
							possible_outcomes.append(this.Const.UI.getColorized(chances.crit + "% crit", colors.crit));
						} 
						if (chances.hit > 0.0) {
							possible_outcomes.append(this.Const.UI.getColorized(chances.hit + "% hit", colors.hit));
						} 
						if (chances.graze > 0.0) {
							possible_outcomes.append(this.Const.UI.getColorized(chances.graze + "% graze", colors.graze));
						} 
						if (chances.miss > 0.0) {
							possible_outcomes.append(this.Const.UI.getColorized(chances.miss + "% miss", colors.miss));
						} 

						local text = "";
						if (::GrazeAndCrit.Config.ShowVanillaHitChanceTooltip) {
							local color = hitchance > 0 ? this.Const.UI.Color.PositiveValue : this.Const.UI.Color.NegativeValue;
							text = text + "Base hit chance: " + this.Const.UI.getColorized(hitchance, color) + "%\n";
							// text = "[color=" + this.Const.UI.Color.PositiveValue + "]" + hitchance + "%[/color] chance to hit"
						}

						if (::GrazeAndCrit.Config.ShowAdvantageTooltip) {
							local color = advantage > 0 ? this.Const.UI.Color.PositiveValue : this.Const.UI.Color.NegativeValue;
							text = text + "Advantage: " + this.Const.UI.getColorized(advantage, color) + "\n";
						}

						assert(possible_outcomes.len() > 0);
						text = text + possible_outcomes[0];
						for (local i = 1; i < possible_outcomes.len(); i++) {
							text = text + ", " + possible_outcomes[i];
						}
						text = text
						entry.text = text;
					}
				} // if (entry.id == 3)
				break;
			}
		}

		return ret;
	}
});
