require './spec/spec_helper'
require './lib/sections/mobiles'

data = File.read("./spec/test-mobiles.are")

describe Mobiles do

  let(:mobiles) { Mobiles.new(data.dup) }

  it_should_behave_like Section do
    let(:section) { mobiles }
  end

  # it_should_behave_like Parsable do
  #   let(:item) { mobiles }
  # end

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

  # it_should_behave_like Parsable do
  #   let(:item) { mobile }
  # end

  # it_should_behave_like LineByLineObject do
  #   let(:item) { mobile }
  # end

  context "parsing a mobile" do

  end

end
