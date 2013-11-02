require "./lib/sections/area_data"

describe AreaData do

  it "detects invalid text after its terminating S"

  it "detects a missing terminating S"

  it "detects invalid line types"

  it "calls the correct parse method for each line type"

  it "detects lines types that are repeated"

  context "when parsing a plane line" do

    it "detects invalid trailing text"

    it "detects out-of-range planes"

    it "detects non-numeric planes"

    it "detects out-of-range sectors"

    it "detects non-numeric sectors"

  end

  context "when parsing an area flags line" do

    it "detects invalid trailing text"

    it "detects invalid bitfields"

    it "detects bit flags that aren't a power of two"

  end

  context "when parsing an outlaw line" do

    it "detects invalid trailing text"

    it "detects invalid non-numeric elements"

  end

  context "when parsing a kspawn" do

    it "detects invalid non-numeric elements"

    it "can parse a kspawn spanning multiple lines"

    it "detects a kspawn with a missing tilde"

    it "detects an extra tilde"

  end

  context "when parsing an area modifier line" do

    it "detects invalid trailing text"

    it "detects invalid non-numeric elements"

  end

  context "when parsing a group exp modifier line" do

    it "detects invalid trailing text"

    it "detects invalid non-numeric elements"

  end

end
