# Av Verify

Area and Prog verifiers for AVATAR Mud, implemented in Ruby.

## vArea

Usage: <code>ruby varea.rb filename.are [nowarning|cosmetic|nocolor]</code>

* <code>nowarning</code>: Suppresses warnings that won't prevent the area from functioning (typically these consist of loading vnums from outside the area file)
* <code>cosmetic</code>: Shows cosmetic warnings that are normally suppressed (mostly just tildes on the wrong line)
* <code>nocolor</code>: Disables ANSI color codes, so output can be cleanly piped into another program

## vProg

Usage: <code>ruby vprog.rb filename.prg [nowarning|showdeprecated|showunknown|nocolor]</code>

* <code>nowarning</code>: As above, suppresses warnings that won't prevent the prog from running
* <code>showdeprecated</code>: Will whine about using the old style of insignia tracking
* <code>showunknown</code>: Will whine about unknown trigger types. (Since most prog files will intentionally have lots of these, it's more of an occasional guard against typos in case you notice something awry)
* <code>nocolor</code>: Drains color from your face and makes you look like a vampire. N.B. This option does _not_ give you fangs. You must manually use candy corns for that. (Just kidding, it disables ANSI color codes.)

# To do

### Immediate

* Break the many Struct objects into proper classes of their own
* Clean up the "connections" parsing

### Long term

* Add object/mob analysis. Give breakdown of mob levels and specs, object levels and their apply flags, etc.
* Mob flow analysis. Could be crazy difficult. Given room connections and terrain types, predict "bottleneck" rooms that could be hard to spot just from reading the area file text. It may be impractical to take random exits and non-Euclidean layouts into account. (Nah it won't, I just wanted an excuse to type "non-Euclidean".)
