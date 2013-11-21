require './spec/spec_helper'
require './lib/sections/mobiles'

data = File.read("./spec/test-mobiles.are")

describe Mobiles do

  let(:mobiles) { Mobiles.new(data) }

  it_should_behave_like Section do
    let(:section) { mobiles }
  end

  it_should_behave_like Parsable do
    let(:item) { mobiles }
  end

end

describe Mobile do

end
