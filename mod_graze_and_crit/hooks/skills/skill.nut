::GrazeAndCrit.MH.hook("scripts/skills/skill", function(q) {
	q.MV_printAttackToLog = @(__original) function( _attackInfo )
	{
		if (::GrazeAndCrit.Config.IsEnabled == false) {
			__original(_attackInfo);
			return;
		}

		// Graze and Crit: Display all outcome thresholds.
		// TODO(Graze and Crit): outcome_chances is experimental and not used atm. Maybe remove?
		local possible_outcomes = [];
		local outcome_chances = [];
		local needed_rolls = [];

		local chances = _attackInfo.GC_OutcomeChances;
		local thresholds = _attackInfo.GC_OutcomeThresholds;
		local colors = ::GrazeAndCrit.Config.HitOutcomeColors;
		if (chances.crit > 0.0) {
			possible_outcomes.append(this.Const.UI.getColorized("crit", colors.crit));
			outcome_chances.append(this.Const.UI.getColorized(chances.crit, colors.crit));
			needed_rolls.append(this.Const.UI.getColorized(thresholds.crit, colors.crit));
		} 
		if (chances.hit > 0.0) {
			possible_outcomes.append(this.Const.UI.getColorized("hit", colors.hit));
			outcome_chances.append(this.Const.UI.getColorized(chances.hit, colors.hit));
			needed_rolls.append(this.Const.UI.getColorized(thresholds.hit, colors.hit));
		} 
		if (chances.graze > 0.0) {
			possible_outcomes.append(this.Const.UI.getColorized("graze", colors.graze));
			outcome_chances.append(this.Const.UI.getColorized(chances.graze, colors.graze));
			needed_rolls.append(this.Const.UI.getColorized(thresholds.graze, colors.graze));
		} 
		if (chances.miss > 0.0) {
			possible_outcomes.append(this.Const.UI.getColorized("miss", colors.miss));
			outcome_chances.append(this.Const.UI.getColorized(chances.miss, colors.miss));
			// Miss threshold is always 100. No need to print it unless all other hit chances are 0.
      if (needed_rolls.len() == 0) {
			  needed_rolls.append(this.Const.UI.getColorized(thresholds.miss, colors.miss));
      }
		} 

		local possible_outcomes_str = possible_outcomes[0];
		local outcome_chances_str = outcome_chances[0];

		for (local i = 1; i < possible_outcomes.len(); i++) {
			possible_outcomes_str = possible_outcomes_str + "/" + possible_outcomes[i];
			outcome_chances_str = outcome_chances_str + "/" + outcome_chances[i];
		}

		local needed_rolls_str = needed_rolls[0];
		for (local i = 1; i < needed_rolls.len(); i++) {
			needed_rolls_str = needed_rolls_str + "/" + needed_rolls[i];
		}

		local roll = _attackInfo.Roll;
		local outcome = "[b]" + _attackInfo.GC_OutcomeMessage + "[/b]";
		local advantage = ::GrazeAndCrit.Core.computeAdvantage(_attackInfo.ChanceToHit);

		this.Tactical.EventLog.log_newline();
		if (_attackInfo.IsAstray)
		{
			if (this.isUsingHitchance())
			{
				this.Tactical.EventLog.logEx(this.Const.UI.getColorizedEntityName(_attackInfo.User) + " uses " + this.getName() + " and the shot goes astray and " + outcome + " " + this.Const.UI.getColorizedEntityName(_attackInfo.Target) + "\n" + "(Advantage: " + advantage + ", Thresholds: " + needed_rolls_str + ", Rolled: " + roll + ")");
			}
			else
			{
				this.Tactical.EventLog.logEx(this.Const.UI.getColorizedEntityName(_attackInfo.User) + " uses " + this.getName() + " and the shot goes astray and hits " + this.Const.UI.getColorizedEntityName(_attackInfo.Target));
			}
		}
		else if (this.isUsingHitchance())
		{
			this.Tactical.EventLog.logEx(this.Const.UI.getColorizedEntityName(_attackInfo.User) + " uses " + this.getName() + " and " + outcome + " " + this.Const.UI.getColorizedEntityName(_attackInfo.Target) + "\n" + "(Advantage: " + advantage + ", Thresholds: " + needed_rolls_str + ", Rolled: " + roll + ")");
		}
		else
		{
			this.Tactical.EventLog.logEx(this.Const.UI.getColorizedEntityName(_attackInfo.User) + " uses " + this.getName() + " and hits " + this.Const.UI.getColorizedEntityName(_attackInfo.Target));
		}
	};


	// Override the mod_modular_vanilla version completely. Changes: see comments marked with "Graze and crit change:"
	q.attackEntity = @(__original) function( _user, _targetEntity, _allowDiversion = true )
	{
		if (::GrazeAndCrit.Config.IsEnabled == false) {
			__original(_user, _targetEntity, _allowDiversion);
			return;
		}

		if (_targetEntity != null && !_targetEntity.isAlive())
		{
			return false;
		}

		local attackInfo = clone ::Const.Tactical.MV_AttackInfo;
		::Const.Tactical.MV_CurrentAttackInfo = attackInfo.weakref();
		attackInfo.User = _user;
		attackInfo.Target = _targetEntity;
		attackInfo.AllowDiversion = _allowDiversion;

		local properties = this.m.Container.buildPropertiesForUse(this, _targetEntity);
		attackInfo.PropertiesForUse = properties;

		local userTile = _user.getTile();
		local astray = false;
		if (_allowDiversion && this.isRanged() && userTile.getDistanceTo(_targetEntity.getTile()) > 1)
		{
			local astrayTarget = this.MV_getDiversionTarget(_user, _targetEntity, properties);
			if (astrayTarget != null)
			{
				_allowDiversion = false;
				astray = true;
				_targetEntity = astrayTarget;

				attackInfo.AllowDiversion = false;
				attackInfo.IsAstray = true;
				attackInfo.Target = _targetEntity;
			}
		}

		if (!_targetEntity.isAttackable())
		{
			if (this.m.IsShowingProjectile && this.m.ProjectileType != 0)
			{
				local flip = !this.m.IsProjectileRotated && _targetEntity.getPos().X > _user.getPos().X;

				if (_user.getTile().getDistanceTo(_targetEntity.getTile()) >= this.Const.Combat.SpawnProjectileMinDist)
				{
					this.Tactical.spawnProjectileEffect(this.Const.ProjectileSprite[this.m.ProjectileType], _user.getTile(), _targetEntity.getTile(), 1.0, this.m.ProjectileTimeScale, this.m.IsProjectileRotated, flip);
				}
			}

			return false;
		}

		local defenderProperties = _targetEntity.getSkills().buildPropertiesForDefense(_user, this);
		attackInfo.PropertiesForDefense = defenderProperties;

		local defense = _targetEntity.getDefense(_user, this, defenderProperties);
		local levelDifference = _targetEntity.getTile().Level - _user.getTile().Level;
		local distanceToTarget = _user.getTile().getDistanceTo(_targetEntity.getTile());

		// Graze and crit change: compute outcome chances and thresholds.
		if (!this.isUsingHitchance())
		{
			attackInfo.ChanceToHit = 100;
			attackInfo.GC_OutcomeChances = ::GrazeAndCrit.Core.getAlwaysHitOutcomeChances();
		}
		else if (!_targetEntity.isAbleToDie() && _targetEntity.getHitpoints() == 1)
		{
			attackInfo.ChanceToHit = 0;
			attackInfo.GC_OutcomeChances = ::GrazeAndCrit.Core.getAlwaysMissOutcomeChances();
		}
		else
		{
			local toHit = this.MV_getHitchance(_targetEntity, false, properties, defenderProperties);

			if (this.m.IsRanged && !_allowDiversion && this.m.IsShowingProjectile)
			{
				toHit = this.Math.max(::Const.Combat.MV_HitChanceMin, this.Math.min(::Const.Combat.MV_HitChanceMax, toHit + ::Const.Combat.MV_DiversionHitChanceAdd));
				properties.DamageTotalMult *= ::Const.Combat.MV_DiversionDamageMult;
			}

			// if (defense > -100 && skill > -100)
			// {
			// 	toHit = this.Math.max(5, this.Math.min(95, toHit));
			// }

			attackInfo.ChanceToHit = toHit;
			attackInfo.GC_OutcomeChances = ::GrazeAndCrit.Core.getHitOutcomeChances(toHit);
		}
		attackInfo.GC_OutcomeThresholds = ::GrazeAndCrit.Core.getHitOutcomeThresholds(attackInfo.GC_OutcomeChances);

		// Graze and crit change:
		// 1) Die has 100x more sides for more precision. 
		// 2) Lucky defender is factored in advance, by rolling twice and taking the min.
		// TODO(Graze and Crit): Expose precision to config?
		local roll = 0;
		{
			local precisionMultiplier = ::GrazeAndCrit.Config.PrecisionMultiplier;
			roll = 1.0 * this.Math.rand(1.0, 100.0*precisionMultiplier) / precisionMultiplier;
			// Check for lucky.
			if (this.Math.rand(1, 100) <= _targetEntity.getCurrentProperties().RerollDefenseChance)
			{
				local second_roll = 1.0 * this.Math.rand(1.0, 100.0*precisionMultiplier) / precisionMultiplier;
				roll = roll < second_roll ? roll : second_roll;
			}
		}

		attackInfo.Roll = roll;

		this.MV_onAttackRolled(attackInfo);

		this.MV_doAttackShake(attackInfo);

		_targetEntity.onAttacked(_user);

		// Graze and crit change: Compute outcome and update damage.
    local outcome = ::GrazeAndCrit.Core.computeOutcome(
      attackInfo.Roll = roll, attackInfo.GC_OutcomeThresholds);

    if (outcome.doDamage) {
      properties.DamageTotalMult *= outcome.damageMultiplier;
	  	properties.FatigueDealtPerHitMult *= outcome.damageMultiplier;
    }
		attackInfo.GC_OutcomeMessage = outcome.message;

		if (!_user.isHiddenToPlayer() && !_targetEntity.isHiddenToPlayer())
		{
			this.MV_printAttackToLog(attackInfo);
		}

    if (outcome.doDamage) {
      if (!outcome.applyEffects) {
        ::logInfo("Graze applying damage without status effects.")
      }
      this.MV_onAttackEntityHit(attackInfo);
    }
    else {
 			this.MV_onAttackEntityMissed(attackInfo);
    }
    // HACKY SHOT IN THE DARK: skills seem to use this return value to decide 
    // whether to apply effects or not.
    return outcome.applyEffects;
	};
});
