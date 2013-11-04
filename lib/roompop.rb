# just a little script to print out mob resets, sorted by room
# handy to make sure you aren't clumping them up
#
# should probably incorporate this into varea at some point,
# but I use it so infrequently I don't think it's necessary

if (ARGV[0])

	data = File.read(ARGV[0])

	raw_resets = data[/#RESETS.*?^S$/m]

	resets = {}

	raw_resets.each_line do |line|
		if m = line.match(/^M 0 (\d+) \d+ (\d+) (.*?)$/)
			resets[m[2].to_i] ||= []
			resets[m[2].to_i] << "#{m[1]} #{m[3]}"
		end
	end

	if (ARGV[1] && ARGV[2].nil?)
		puts "Usage: roompop areafile.are [minvnum maxvnum]"
	elsif (ARGV[1] && ARGV[2])
		resets.keys.sort.each do |k|
			break if k > ARGV[2].to_i
			next if k < ARGV[1].to_i
			puts k
			resets[k].sort.each {|i| puts "  #{i}"}
		end
	else
		resets.keys.sort.each do |k|
			puts k
			resets[k].sort.each {|i| puts "  #{i}"}
		end
	end

else

	puts "Usage: roompop areafile.are [minvnum maxvnum]"

end
