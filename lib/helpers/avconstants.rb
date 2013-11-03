# Please DO change these constants as new features are added to AVATAR

SECTIONS = %w{area areadata helps mobiles objects rooms resets shops specials $}

SPECIALS = %w{
	spec_adaptive spec_animate_dead spec_archer spec_archerall spec_assassin 
	spec_battle_cleric spec_battle_mage spec_battle_sor spec_bci_lite 
	spec_berserker spec_bodyguard spec_breath_acid spec_breath_any 
	spec_breath_fire spec_breath_frost spec_breath_gas spec_breath_lightning 
	spec_breath_super spec_buddha spec_buttkicker spec_cast_adept 
	spec_cast_cleric spec_cast_kinetic spec_cast_mage spec_cast_psion 
	spec_cast_stormlord spec_cast_undead spec_cast_wizard spec_demon 
	spec_doppleganger spec_druid spec_essence spec_fido spec_fusilier 
	spec_guard spec_guard_white spec_guild_guard spec_illusionist 
	spec_janitor spec_kinetic_lite spec_kungfu_poison spec_kzin 
	spec_mindbender spec_monk spec_plague spec_poison spec_priest 
	spec_priest_lite spec_puff spec_puff_orig spec_rogue spec_rogue_lite 
	spec_sniper spec_sorceror spec_stomp_em spec_teacher spec_thief 
	spec_warlord spec_warrior spec_cast_judge
	spec_executioner spec_jailer spec_townguard
	}

SPEC_DEPRECATED = %w{
	spec_captain spec_mayor spec_soul_stealer spec_frog_ager
	spec_frog_devourer spec_plague_frogs
	}

PLANE_MIN = -5 # N.B. 0 Is not a valid plane
PLANE_MAX = 17 # Legend and titan planes will throw an error, but I'm sure
							 # Legend/titan builders know what they're doing
ZONE_MAX = 1 # Currently just Eragora

CLASS_MAX = 23
RACE_MAX = 81
SEX_MAX = 2
TEAM_MAX = 4 #This doesn't count the quest teams
WEAR_MAX = 19 #Equipment reset slot
SECTOR_MAX = 13 #Room sector
LOCK_MAX = 8 #Door lock/state

# These constants only apply to object summary output, which isn't coded yet.
APPLY = {
	1=>"Strength", 2=>"Dexterity", 3=>"Intelligence", 4=>"Wisdom", 5=>"Constitution",
	6=>"Sex", 7=>"Class", 8=>"Level", 9=>"Age", 10=>"Height", 11=>"Weight",
	12=>"Mana", 13=>"Hit Points", 14=>"Move Points", 15=>"Gold", 16=>"Experience",
	17=>"Armor Class", 18=>"Hit Roll", 19=>"Dam Roll",
	20=>"Save vs Lightning", 21=>"Save vs Fire", 22=>"Save vs Ice", 23=>"Save vs Magic", 24=>"Save vs Spell",
	25=>"Sanctuary", 26=>"Flying", 27=>"Blind", 28=>"Invisibility",
	29=>"Detect Evil", 30=>"Detect Invis", 31=>"Detect Magic", 32=>"Detect Hidden",
	33=>"Faerie Fire", 34=>"Infravision", 35=>"Curse", 36=>"Poison", 37=>"Protection Evil",
	38=>"Sneak", 39=>"Hide", 40=>"Pass Door", 41=>"Plague", 42=>"Endurance", 43=>"Detect Alignment", 44=>"Protection Good",
	45=>"XP_GAIN", 46=>"HP_REGEN", 47=>"MANA_REGEN", 48=>"MOVE_REGEN", 49=>"SECRET", 50=>"IMMUNITY",
	51=>"Kinetic Damroll",
	52=>"MOD_XP_GAIN", 53=>"MOD_MOD_HP_REGEN", 54=>"MOD_MANA_REGEN", 55=>"MOD_MOVE_REGEN",
	63=>"cold resist", 64=>"stasis resist", 65=>"biological resist", 66=>"sonic resist",
	67=>"pressure resist", 68=>"radiant resist", 69=>"electric resist", 70=>"leeching resist",
	71=>"poison resist", 72=>"chemical resist", 73=>"mental resist", 74=>"arcane resist",
	75=>"divine resist", 76=>"falling resist", 77=>"travel resist", 78=>"cursed resist",
	79=>"fire resist", 80=>"mind control resist", 81=>"polymorph resist", 82=>"antimagic resist",
	83=>"nature resist", 84=>"air resist", 85=>"earth resist", 86=>"water resist",
	87=>"piercing resist", 88=> "slicing resist", 89=>"chopping resist", 90=>"blunt resist",
	91=>"whipping resist", 92=>"blasting resist", 93=>"damage type", 94=>"unarmed damage type",
	95=>"stealth",
	100=>"SPELL_BOOST_ALL_COST", 101=>"SPELL_BOOST_ALL_LEVEL", 102=>"SPELL_BOOST_ALL_FAIL", 103=>"SPELL_BOOST_ALL_TIME",
	110=>"SPELL_BOOST_ARC_COST", 111=>"SPELL_BOOST_ARC_LEVEL", 112=>"SPELL_BOOST_ARC_FAIL", 113=>"SPELL_BOOST_ARC_TIME",
	120=>"SPELL_BOOST_DIV_COST", 121=>"SPELL_BOOST_DIV_LEVEL", 122=>"SPELL_BOOST_DIV_FAIL", 123=>"SPELL_BOOST_DIV_TIME",
	130=>"SPELL_BOOST_PSI_COST", 131=>"SPELL_BOOST_PSI_LEVEL", 132=>"SPELL_BOOST_PSI_FAIL", 133=>"SPELL_BOOST_PSI_TIME" 
	}

IMMUNITY = {
	1=>"area spells", 2=>"poisons", 4=>"diseases", 8=>"falling", 16=>"arrows", 32=>"blunt weapons",
	64=>"sharp weapons", 128=>"unarmed attacks", 256=>"sneak attacks", 512=>"blindness"
	}

DAMTYPES = %w{ nil
	cold stasis biological sonic pressure radiant electric leeching poison chemical
	mental arcane divine falling travel cursed fire mind_control polymorph antimagic
	nature air earth water
	}

OPEN_DAM = %w{piercing slicing chopping blunt whipping blasting}

# The resets section throws a warning if the area loads a mob or object that
# isn't in the areafile. This determines whether or not an object vnum is
# one of a few common items.
def known_vnum (vnum)
	return true if vnum.between?(21,25)
	return true if vnum.between?(28, 37) # food
	return true if vnum.between?(100, 123) # vials, air gear
	return true if vnum.between?(130, 133) # Arrows, bolts, fletch kits
	return true if vnum.between?(137, 164) # Lockboxes, gems
	return true if vnum.between?(774,775) # ashes
	false
end
