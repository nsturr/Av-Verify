# Just returns the regexp pattern to match a bitfield
def bpattern
	/^\d+(?:\|\d+)*$/
end

# Returns an array of individual bits
def bits(total)
	array = []

	until total <= 0
		bit = highest_power_of_two_below(total)
		array << bit
		total -= bit
	end

	# Return bits in lowest to highest order
	array.reverse
end

# Returns true if the sum of a bitfield contains query bit, false if not.
# Returns nil if query is not a power of 2
def bit?(total, query)
	# First make sure bit is a power of 2
	return nil unless power_of_two?(query)
	# Now check to see if it's in the bitfield
	until total <= 0
		bit = highest_power_of_two_below(query)
		return true if bit == query
		total -= bit
	end
	false
end

# Sums a bitfield in string form. Returns the sum if the string is valid
# i.e. all the numbers are powers of two and are separated by pipes.
# returns nil otherwise
# Passing an empty string will return nil too. Pass 0 instead.
def bparse(string)
	# Firstly, if the string is a single number (i.e. bits already summed)
	# just return it
	return string.to_i if string.match(/^\d+$/)
	# Secondly, if the string doesn't match #|#|# then return nil (for error)
	return nil unless string.match(bpattern)
	strings = string.split("|")
	bits = []
	strings.each {|s| bits << s.to_i}

	total = 0 # The value to be returned

	bits.each do |bit|
		# First make sure that each bit is a power of 2 by repeatedly dividing
		# by 2 until you get 1, and returning nil if there's any remainder.
		return nil unless power_of_two? bit
		total += bit
	end
	total
end

def power_of_two?(number)
	test = number
	until test <= 1 do
		return false if test % 2 != 0
		test /= 2
	end
	true
end

def highest_power_of_two_below(number)
	bit = 1
	until bit > number
		bit *= 2
	end
	bit / 2
end
