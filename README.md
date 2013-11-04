# Av Verify

Area and Prog verifiers for AVATAR Mud, implemented in Ruby.

## vArea : the area verifier

Usage: <code>ruby varea.rb filename.are [nowarning|cosmetic|nocolor]</code>

* <code>nowarning</code>: Suppresses warnings that won't prevent the area from functioning (typically these consist of loading vnums from outside the area file)
* <code>cosmetic</code>: Shows cosmetic warnings that are normally suppressed (mostly just tildes on the wrong line)
* <code>nocolor</code>: Disables ANSI color codes, so output can be cleanly piped into another program
* <code>notices</code>: Shows notices that are suppressed by default (notices consist of room exits leaving the area, and resets referencing a section that isn't in the file)

vArea relies on proper formatting to do its thing, or you will get unexpected errors. That means output from an area builder, etc. Also, while it is technically possible to have more than one of the same section in the same area file (multiple #OBJECTS in houses.are for example), vArea won't parse it.

### Main classes

#### Area

Includes <code>Parsable</code> and <code>AreaAttributes</code> modules. This is what can be thought of as the area file in object form. Its initializer accepts a file path string (relative) which it loads and promptly dissects into sections, detects their type, and instantiates them into the appropriate objects.

Sections are accessible in Area#main_sections.

<code>verify_all</code> simply runs an each loop on self.main_sections that calls the section's <code>parse</code> method, then add the section's resulting errors (if any) to the area's errors.

<code>correlate_all</code> runs a different set of checks that compares vnum references between sections, the obvious example being #RESETS. It is a shorthand method for separately running <code>correlate_rooms</code>, <code>_resets</code>, <code>_specials</code>, and <code>_shops</code>.

#### Section
Includes <code>Parsable</code> module. Most sections that are a collection of smaller things (so anything except <code>AreaHeader</code> and <code>AreaData</code>) present a hash-like interface, in which they have <code>[]</code>, <code>each</code>, <code>length</code>, and <code>key?</code> methods. Keyed by VNUM where appropriate. These are not inherited, though they should be (a task for later improvement)

Subclasses of Section:
* <code>**AreaHeader**</code>
* <code>**AreaData**</code>
* <code>**Helps**</code>
* <code>**VnumSection**</code>
  * <code>**Mobiles**</code>
  * <code>**Objects**</code>
  * <code>**Rooms**</code>
* <code>**Resets**</code>
* <code>**Shops**</code>
* <code>**Specials**</code>

#### VnumSection

Since #Mobiles, #Objects, and #Rooms are all structured similarly, they share the parent class VnumSection. Each of the child sections supply the class name of the items they contain (Mobs, Objects, Rooms respectively) so that VnumSection can break apart the text and instantiate new <code>self.child_class</code> objects.

#### LineByLineItem
Includes <code>Parsable</code> and <code>TheTroubleWithTildes</code>. Its subclasses are all parsed the same way (line by line, if you couldn't guess)

Its subclasses are:
* <code>**Mobile**</code> includes <code>HasApplyFlag</code> and <code>HasQuotedKeywords</code>
* <code>**Object**</code> includes <code>HasApplyFlag</code> and <code>HasQuotedKeywords</code>
* <code>**Room**</code> includes <code>HasQuotedKeywords</code>
* <code>**Shop**</code> (is the bane of my existance)

#### HelpFile
Includes <code>Parsable</code>, <code>HasQuotedKeywords</code>, and <code>TheTroubleWithTildes</code> modules.

#### Reset

Includes <code>Parsable</code> module. A reset can be of type mob, inventory, equipment, object, container, door, or random. Its visible attributes are <code>Reset#vnum</code>, <code>Reset#target</code>, <code>Reset#slot</code>, and <code>Reset#limit</code>. Vnum is typically the identifier (references the room, object, or mob that it's placing), and target is typically another vnum (the one it's loading into or onto, etc). Limit and slot are not always used.

Resets have no knowledge of the rest of the area, so they can't tell whether or not the items they're referencing exist. That's what Area#correlate_resets is for.

#### Special

Includes <code>Parsable</code> module.

### Helper classes

#### Bits
Inherits from <code>Array</code>, and has the following methods for dealing with bit fields:

* <code>Bits::pattern</code> & <code>Bits::insert</code> return regex patterns that match a pipe-separated bitfield in string format, and the same bitfield as a substring in a larger string.
* <code>Bits#initialize(bits)</code> accepts both a pipe-separated string or an array of numbers
* <code>Bits#bit?(i)</code> true if <code>i</code> is part of the bit field
* <code>Bits#error?</code> true if any of its bits was not a power of 2 to start with
* <code>Bits#sum</code>
* <code>Bits#to_a</code>

#### Error
An error contains the line number on which it occurred, a copy of that line of text, its type (<code>:error</code>, <code>:warning</code>, <code>:nb</code>, or <code>:ugly</code>), and a copy of its error message.

Has a <code>to_s</code> method which, if passed true, disables color output.

### Modules

#### AreaAttributes
Gives Area its getter methods, namely:

* <code>name</code>, <code>author</code>, <code>level</code>, all strings, from AreaHeader
* <code>plane</code> and <code>zone</code>, both numbers, from AreaData
* <code>flags</code>, a Bits object, from AreaData
* <code>outlaw</code>, <code>seeker</code> (a.k.a kspawn), <code>modifiers</code>, <code>group_exp</code>, all hashes of their respective fields, from AreaData
* <code>helps</code>, an array of help files, from Helps
* <code>mobiles</code>, the actual Mobiles object, if any
* <code>objects</code>, the actual Objects object, if any
* <code>rooms</code>, the actual Rooms object, if any
* <code>resets</code>, the actual Resets object, if any
* <code>shops</code>, the actual Shops object, if any
* <code>specials</code>, the actual Specials object, if any

Each getter will return nil if the section that contains the data it's looking for isn't in the area. If the section is found, it will also cache its return value so it's only looked up once.

#### Parsable
Supplies the <code>Error</code> class and bestows the <code>err</code> method (and its ilk), and the <code>error_report</code> method that prints all of the object's errors.

#### HasApplyFlag
Bestows the <code>parse_apply_flag</code> method.

#### HasQuotedKeywords
Bestows the <code>parse_quoted_keywords</code> method which turns a string of keywords into an array of keywords, taking single quotes into account.

Also generates errors for mismatched quotes, and if supplied a boolean will generate a warning if there are any quotes in the keywords. (Since you probably don't want to be quoting an object keyword.)

#### TheTroubleWithTildes
It is what it sounds like.


## vProg : the prog verifier

Usage: <code>ruby vprog.rb filename.prg [nowarning|showdeprecated|showunknown|nocolor]</code>

* <code>nowarning</code>: As above, suppresses warnings that won't prevent the prog from running
* <code>showdeprecated</code>: Will whine about using the old style of insignia tracking
* <code>showunknown</code>: Will whine about unknown trigger types. (Since most prog files will intentionally have lots of these, it's more of an occasional guard against typos in case you notice something awry)
* <code>nocolor</code>: Drains color from your face and makes you look like a vampire. N.B. This option does _not_ give you fangs. You must manually use candy corns for that. (Just kidding, it disables ANSI color codes.)

Danger: here (in the code) be dragons. This will likely never receive the same refactoring treatment that vArea did, on account of there being less of a reason to give it a proper API. Also it just isn't worth the sorrow.

# To do

### Immediate

* Clean up the "connections" parsing, as it's too brittle
* Tilde related methods can be cleaned up a bit

### Long term

* Ability to pass a vnum range and have the program ignore external references to those vnums. I.e. "I know vnums i-j aren't in the file, don't throw me warnings about them."
* Add object/mob analysis. Give breakdown of mob levels and specs, object levels and their apply flags, etc.
* Mob flow analysis. Could be crazy difficult. Given room connections and terrain types, predict "bottleneck" rooms that could be hard to spot just from reading the area file text. It may be impractical to take random exits and non-Euclidean layouts into account. (Nah it won't, I just wanted an excuse to type "non-Euclidean".)
