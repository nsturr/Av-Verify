require './spec/spec_helper'
require './lib/sections/mobiles'

data = File.read("./spec/test-mobiles.are")

describe Mobiles do

  let(:mobiles) { Mobiles.new(data.dup) }

  it_should_behave_like Section do
    let(:section) { mobiles }
  end

  it_should_behave_like VnumSection do
    let(:section) { mobiles }
  end

end

describe Mobile do

  # Test LineByLineObject separately

  let(:mobile) do
    mobiles_section = Mobiles.new(data.dup)
    mobiles_section.parse
    mobiles_section.mobiles.values.first
  end

  # it_should_behave_like LineByLineObject do
  #   let(:item) { mobile }
  # end

  context "parsing text fields" do

    it "detects a tab character"

    it "detects a short desc that spans more than one line"

    it "detects a long desc that spans more than one line"

    it "detects a missing tilde in the description field"

  end

  context "parsing act/aff/align line" do

    it "detects a missing 'S'"

    it "detects a missing ACT_NPC flag"

    it "detects a bad act bit"

    it "detects a non-numeric act field"

    it "detects a bad affect bit"

    it "detects a non-numeric affect field"

    it "detects an invalid align field"

    it "detects an out-of-range alignment"

    it "detects invalid line syntax"

  end

  context "parsing those boring middle lines" do

    it "detects an invalid mob level"

    it "detects wrong level line syntax"

    it "detects wrong '0d0+0' line syntax"

    it "detects invalid sex field"

    it "detects invalid sex line syntax"

  end

  context "parsing misc fields" do

    it "detects an out-of-range race"

    it "detects an invalid race"

    it "detects invalid text after the race field"

    it "detects a duplicated race field"

    it "detects an out-of-range class"

    it "detects an invalid class"

    it "detects invalid text after the class field"

    it "detects a duplicated class field"

    it "detects an out-of-range team"

    it "detects an invalid team"

    it "detects invalid text after the team field"

    it "detects a duplicated team field"

    it "detects an invalid misc field"

  end

  context "parsing a kspawn" do

    it "detects a duplicated kspawn field"

    it "detects invalid kspawn syntax"

    it "detects a bad kspawn condition"

    it "detects a bad kspawn type bit"

    it "detects a bad kspawn vnum"

    it "detects a bad kspawn location"

    it "detects a visible tab"

    it "detects a kspawn with a missing tilde"

  end

end
