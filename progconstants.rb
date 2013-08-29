# The three main sections. Script will flip out if it finds an
# unidentified one in the file it's checking.
SECTIONS = %w{ PROGS_MOB PROGS_ROOM PROGS_FUN }

# The known trigger types. Script will not flip out if it finds
# an unknown one, but it will throw a minor error (that is
# suppressed by default)
TRIGGERS = %w{ ER LR DO GO TI GG FO DS BO ST TE EC KS CC FA FC }

# These conditions are numeric. (The script will throw an error
# if they aren't numeric.)
# qvar, wear_#, and wear_v#_# aren't included as they require
# special handling
C_NUM = %w{
	level sublevel race class sex align worship devotion
	hp_pct mana_pct move_pct size team act act2 act3 affect
	affect2 trust age coins questpoints
	obj objlevel objtype wear
	room sunlight sky mhour mday mmonth minute hour weekday day month
	count_pc count_all pct mob
	}

# These conditions are strings of text. They may or may not be
# more than one word. They may or may not be enclosed in quotes.
# (That's specific to the condition and trigger type being used.)
C_TEXT = %w{
	name text command command0 command1 command2 command3
	command4 command5 command6 command7 command8 command9
	command_0 command_1 command_2 command_3 command_4
	command_5 command_6 command_7 command_8 command_9
	}

# These conditions are used in fun progs. Script will flip out
# if they're used outside PROGS_FUN section.
C_FUN = %w{
	fun_name fun_arg0 fun_arg1 fun_arg2 fun_arg3 fun_arg4
	fun_arg5 fun_arg6 fun_arg7 fun_arg8 fun_arg9
	}

# These are The Olde Quest Tracking conditions
C_DEPRECATED = %w{ qstart qfinish qfail qstate }

# All of the conditions condensed together - for checking known conditions
C_ALL = C_NUM + C_TEXT # + C_FUN + C_DEPRECATED

# Valid operators. The solitary '!' used with QSTATE is not included.
OPERATORS = %w{ = != < > }

# Valid flags for actions
AFLAGS = "PQL" # Project: Quantum Leap! :D

# The max values for various conditions
SUNLIGHT_MAX = 3
SKY_MAX = 3
MDAY_MAX = 30
MMONTH_MAX = 13
EQSLOT_MAX = 19
