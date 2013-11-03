# Av Verify

Area and Prog verifiers for AVATAR Mud, implemented in Ruby.

## vArea

Usage: <code>ruby varea.rb filename.are [nowarning|cosmetic|nocolor]</code>

* <code>nowarning</code>: Suppresses warnings that won't prevent the area from functioning (typically these consist of loading vnums from outside the area file)
* <code>cosmetic</code>: Shows cosmetic warnings that are normally suppressed (mostly just tildes on the wrong line)
* <code>nocolor</code>: Disables ANSI color codes, so output can be cleanly piped into another program

### Classes

* <code>Area</code> includes <code>Parsable</code> and <code>AreaAttributes</code>

* <code>Section</code> includes <code>Parsable</code>
  * <code>AreaHeader</code>
  * <code>AreaData</code>
  * <code>Helps</code>
  * <code>VnumSection</code>
    * <code>Mobiles</code>
    * <code>Objects</code>
    * <code>Rooms</code>
  * <code>Resets</code>
  * <code>Shops</code>
  * <code>Specials</code>

* <code>LineByLineItem</code> includes <code>Parsable</code> and <code>TheTroubleWithTildes</code>
  * <code>Mobile</code> includes <code>HasApplyFlag</code> and <code>HasQuotedKeywords</code>
  * <code>Object</code> includes <code>HasApplyFlag</code> and <code>HasQuotedKeywords</code>
  * <code>Room</code> includes <code>HasQuotedKeywords</code>
  * <code>Shop</code>

* <code>HelpFile</code> includes <code>Parsable</code>, <code>HasQuoteKeywords</code>, and <code>TheTroubleWithTildes</code>
* <code>Reset</code> includes <code>Parsable</code>
* <code>Special</code> includes <code>Parsable</code>
* <code>Bits</code>
* <code>Error</code>


## vProg

Usage: <code>ruby vprog.rb filename.prg [nowarning|showdeprecated|showunknown|nocolor]</code>

* <code>nowarning</code>: As above, suppresses warnings that won't prevent the prog from running
* <code>showdeprecated</code>: Will whine about using the old style of insignia tracking
* <code>showunknown</code>: Will whine about unknown trigger types. (Since most prog files will intentionally have lots of these, it's more of an occasional guard against typos in case you notice something awry)
* <code>nocolor</code>: Drains color from your face and makes you look like a vampire. N.B. This option does _not_ give you fangs. You must manually use candy corns for that. (Just kidding, it disables ANSI color codes.)

# To do

### Immediate

* Break the many Struct objects into proper classes of their own (this is in progress)
* Clean up the "connections" parsing, as it's too brittle

### Long term

* Add object/mob analysis. Give breakdown of mob levels and specs, object levels and their apply flags, etc.
* Mob flow analysis. Could be crazy difficult. Given room connections and terrain types, predict "bottleneck" rooms that could be hard to spot just from reading the area file text. It may be impractical to take random exits and non-Euclidean layouts into account. (Nah it won't, I just wanted an excuse to type "non-Euclidean".)
