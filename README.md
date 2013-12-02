# Av Verify

Area and Prog verifiers for AVATAR Mud, implemented in Ruby.

The file `test-air.are` is a lightly modified version of `air.are` distributed with [Merc 2.2](http://www.mudbytes.net/index.php?a=files&cid=9).

## vArea : the area verifier

Usage: `ruby varea.rb filename.are [nowarning|cosmetic|nocolor]`

* `nowarning`: Suppresses warnings that won't prevent the area from functioning (typically these consist of loading vnums from outside the area file)
* `cosmetic`: Shows cosmetic warnings that are normally suppressed (mostly just tildes on the wrong line)
* `nocolor`: Disables ANSI color codes, so output can be cleanly piped into another program
* `notices`: Shows notices that are suppressed by default (notices consist of room exits leaving the area, and resets referencing a section that isn't in the file)

vArea relies on proper formatting to do its thing, or you will get unexpected errors. That means output from an area builder, etc. Also, while it is technically possible to have more than one of the same section in the same area file (multiple #OBJECTS in houses.are for example), vArea won't parse it.

### Main classes

#### Area

Includes `Parsable` and `AreaAttributes` modules. This is what can be thought of as the area file in object form. Its initializer accepts a file path string (relative) which it loads and promptly dissects into sections, detects their type, and instantiates them into the appropriate objects.

Sections are accessible in Area#main_sections.

`verify_all` simply runs an each loop on self.main_sections that calls the section's `parse` method, then add the section's resulting errors (if any) to the area's errors.

`correlate_all` runs a different set of checks that compares vnum references between sections, the obvious example being #RESETS. It is a shorthand method for separately running `correlate_rooms`, `_resets`, `_specials`, and `_shops`. See the section on the `Correlation` class below for more info.

#### Section
Includes `Parsable` module. Most sections that are a collection of smaller things (so anything except `AreaHeader` and `AreaData`) present a hash-like interface, in which they have `[]`, `each`, `length`, and `key?` methods. Keyed by VNUM where appropriate. These are not inherited, though they should be (a task for later improvement)

Subclasses of Section:
* `AreaHeader`
* `AreaData`
* `Helps`
* `VnumSection`
  * `Mobiles`
  * `Objects`
  * `Rooms`
* `Resets`
* `Shops`
* `Specials`

#### VnumSection

Since #Mobiles, #Objects, and #Rooms are all structured similarly, they share the parent class VnumSection. Each of the child sections supply the class name of the items they contain (Mobs, Objects, Rooms respectively) so that VnumSection can break apart the text and instantiate new `self.child_class` objects.

#### LineByLineItem
Includes `Parsable` and `TheTroubleWithTildes`. Its subclasses are all parsed the same way (line by line, if you couldn't guess)

Its subclasses are:
* `Mobile` includes `HasApplyFlag` and `HasQuotedKeywords`
* `Object` includes `HasApplyFlag` and `HasQuotedKeywords`
* `Room` includes `HasQuotedKeywords`
* `Shop` (is the bane of my existance)

#### HelpFile
Includes `Parsable`, `HasQuotedKeywords`, and `TheTroubleWithTildes` modules.

#### Reset

Includes `Parsable` module. A reset can be of type mob, inventory, equipment, object, container, door, or random. Its visible attributes are `Reset#vnum`, `Reset#target`, `Reset#slot`, and `Reset#limit`. Vnum is typically the identifier (references the room, object, or mob that it's placing), and target is typically another vnum (the one it's loading into or onto, etc). Limit and slot are not always used.

Resets have no knowledge of the rest of the area, so they can't tell whether or not the items they're referencing exist.

#### Special

Includes `Parsable` module.

### Helper classes

#### Bits
Inherits from `Array`, and has the following methods for dealing with bit fields:

* `Bits::pattern` & `Bits::insert` return regex patterns that match a pipe-separated bitfield in string format, and the same bitfield as a substring in a larger string.
* `Bits#initialize(bits)` accepts both a pipe-separated string or an array of numbers
* `Bits#bit?(i)` true if `i` is part of the bit field
* `Bits#error?` true if any of its bits was not a power of 2 to start with
* `Bits#sum`
* `Bits#to_a`

#### Error
An error contains the line number on which it occurred, a copy of that line of text, its type (`:error`, `:warning`, `:nb`, or `:ugly`), and a copy of its error message.

Has a `to_s` method which, if passed true, disables color output.

### Correlation
Accepts a hash of options (`area`, `mobiles`, `objects`, `rooms`, `resets`, `shops`, `specials`. The individual sections, if present, override the sections from the area).

`correlate_doors` detects doors whose destinations rooms aren't in the area.

`correlate_shops` and `correlate_specials` detects shops and specials whose vnums don't correspond to mobiles in the area.

`correlate_resets` is a macro for a bunch of checks specific to the type of reset, but basically consist of ensuring that mobs, objects, and rooms referenced as vnums actually exist in the area.

All errors raised here are warnings, and errors raised from doors not matching up with rooms are notices which means they're suppresed by default (since obviously an area will have detinations out of the area). Also, if a required section isn't passed to the correlation instance, it will only raise a single notice like

```
Line 2694: No MOBILES section in area, 46 mob references in RESETS skipped
```
where the line number is where `RESETS` section started.

### Modules

#### AreaAttributes
Gives Area its getter methods, namely:

* `name`, `author`, `level`, all strings, from AreaHeader
* `plane` and `zone`, both numbers, from AreaData
* `flags`, a Bits object, from AreaData
* `outlaw`, `seeker` (a.k.a kspawn), `modifiers`, `group_exp`, all hashes of their respective fields, from AreaData
* `helps`, an array of help files, from Helps
* `mobiles`, the actual Mobiles object, if any
* `objects`, the actual Objects object, if any
* `rooms`, the actual Rooms object, if any
* `resets`, the actual Resets object, if any
* `shops`, the actual Shops object, if any
* `specials`, the actual Specials object, if any

Each getter will return nil if the section that contains the data it's looking for isn't in the area. If the section is found, it will also cache its return value so it's only looked up once.

#### Parsable
Supplies the `Error` class and bestows the `err` method (and its ilk), and the `error_report` method that prints all of the object's errors.

Also supplies the `err_msg` method as a class method, which accepts a symbol and any number of optional arguments, and returns an error string corresponding to the symbol with the arguments interpolated into it.

#### HasApplyFlag
Bestows the `parse_apply_flag` method. Both objects and mobiles use this.

#### HasQuotedKeywords
Bestows the `parse_quoted_keywords` method which turns a string of keywords into an array of keywords, taking single quotes into account.

Also generates errors for mismatched quotes, and if supplied a boolean will generate a warning if there are any quotes in the keywords. (Since you probably don't want to be quoting an object keyword.)

#### TheTroubleWithTildes
It is what it sounds like.


## vProg : the prog verifier

Usage: `ruby vprog.rb filename.prg [nowarning|showdeprecated|showunknown|nocolor]`

* `nowarning`: As above, suppresses warnings that won't prevent the prog from running
* `showdeprecated`: Will whine about using the old style of insignia tracking
* `showunknown`: Will whine about unknown trigger types. (Since most prog files will intentionally have lots of these, it's more of an occasional guard against typos in case you notice something awry)
* `nocolor`: Drains color from your face and makes you look like a vampire. N.B. This option does _not_ give you fangs. You must manually use candy corns for that. (Just kidding, it disables ANSI color codes.)

Danger: here (in the code) be dragons. This will likely never receive the same refactoring treatment that vArea did, on account of there being less of a reason to give it a proper API. Also it just isn't worth the sorrow.

# To do

### Immediate

* Clean up the "connections" parsing, as it's too brittle
* Unify error messages so we don't have to chain a bunch of references like `self.class.err_msg(whatever)`, or traverse class hierarchies just to get to the right error message

### Long term

* Ability to pass a vnum range and have the program ignore external references to those vnums. I.e. "I know vnums i-j aren't in the file, don't throw me warnings about them."
* Add object/mob analysis. Give breakdown of mob levels and specs, object levels and their apply flags, etc.
* Mob flow analysis. Could be crazy difficult. Given room connections and terrain types, predict "bottleneck" rooms that could be hard to spot just from reading the area file text. It may be impractical to take random exits and non-Euclidean layouts into account. (Nah it won't, I just wanted an excuse to type "non-Euclidean".)
