# Bits is essentially an array with a few helper methods
# Bits::pattern returns the regex for detecting a bitfield
# Bits#initialize...
#   raises an exception if any element is not a Fixnum
#   sorts its element in ascending order
#   sets self.error to true if any of the bits aren't powers of two
# Bits#error? returns self.error
# Bits#bit? equivalent to include? but raises exception if argument
#   is not a power of two
#
# TODO: incorporate bparse

class Bits < Array

	@@powers_of_two = [1] # Stored in descending order

	def self.powers_of_two
		@@powers_of_two
	end

	def self.pattern
		/^#{self.insert}$/
	end

	def self.insert
		/\d+(?:\|\d+)*/
	end

	def initialize(bits)
		# Because to_i returns 0 if element is NaN, you still have to check for
		# non-number inputs before calling this method
		if bits.is_a? String
			bits = bits.split("|")
			bits.map!(&:to_i)
		end

		bits.each do |bit|
			self << bit
			@error ||= true unless bit == 0 || Bits.power_of_two?(bit)
		end
		@error ||= false
		self.sort!
	end

	def error?
		@error
	end

	def bit?(n)
		raise ArgumentError.new("not a power of two (#{n})") unless Bits.power_of_two?(n)
		self.include?(n)
	end

	def to_a
		Array.new(self)
	end

	def sum
		self.inject(&:+)
	end

	private

		def self.power_of_two?(number)
			return true if @@powers_of_two.include? number

			until @@powers_of_two.first >= number
				@@powers_of_two.unshift(@@powers_of_two.first * 2)
			end
			number == @@powers_of_two.first
		end

		def self.highest_power_of_two_below(number)
			if (number / 2) > @@powers_of_two.first
				while (number / 2) > @@powers_of_two.first
					@@powers_of_two.unshift(@@powers_of_two.first * 2)
				end
				@@powers_of_two.first
			else
				@@powers_of_two.find { |el| el < number }
			end
		end

end

# Sums a bitfield in string form. Returns the sum if the string is valid
# i.e. all the numbers are powers of two and are separated by pipes.
# returns nil otherwise
# Passing an empty string will return nil too. Pass 0 instead.
# def bparse(string)
# 	# Firstly, if the string is a single number (i.e. bits already summed)
# 	# just return it
# 	return string.to_i if string.match(/^\d+$/)
# 	# Secondly, if the string doesn't match #|#|# then return nil (for error)
# 	return nil unless string.match(Bits.pattern)
# 	strings = string.split("|")
# 	bits = []
# 	strings.each {|s| bits << s.to_i}

# 	total = 0 # The value to be returned

# 	bits.each do |bit|
# 		# First make sure that each bit is a power of 2 by repeatedly dividing
# 		# by 2 until you get 1, and returning nil if there's any remainder.
# 		return nil unless power_of_two? bit
# 		total += bit
# 	end
# 	total
# end

# def power_of_two?(number)
# 	test = number
# 	until test <= 1 do
# 		return false if test % 2 != 0
# 		test /= 2
# 	end
# 	true
# end

# def highest_power_of_two_below(number)
# 	bit = 1
# 	until bit > number
# 		bit *= 2
# 	end
# 	bit / 2
# end
