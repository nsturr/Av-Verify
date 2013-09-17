# Bits is an array with the following differences:
# Bits#initialize...
#   raises an exception if any element is not a Fixnum
#   sorts its elements in ascending order
#   sets self.error to true if any of the bits aren't powers of two
# Bits#bit? is equivalent to Array#include? but raises an error
#   if the argument is not a power of two
# Stores powers of two as it calculates them, not that it's taxing
#   to recalculate them every time power_of_two? is called anyway...

class Bits < Array

	@@powers_of_two = [1] # Stored in descending order

	def self.powers_of_two # Only every used to confirm that storing
		@@powers_of_two      # precalculated powers of 2 is working
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
