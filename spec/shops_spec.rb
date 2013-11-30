require './spec/spec_helper'
require './lib/sections/shops'

data = File.read("./spec/test-shops.are")

describe Shops do

  let(:shops) { Shops.new(data) }

  it_should_behave_like Section do
    let(:section) { shops }
  end

  # Fix this for Shops specifically
  # it_should_behave_like VnumSection do
  #   let(:section) { shops }
  # end

  it "parses its section" do
    shops.parse

    expect(shops.errors).to be_empty
    expect(shops.children).to have(4).elements
  end

end

describe Shop do

  let(:shop) do
    shops = Shops.new(data)
    shops.split_children
    shops.children.first
  end

  # I really do hate Shops syntax. Oh so much.

  it "detects missing tokens on the object types line" do
    shop.contents[/^\d+ (?=\d+)/] = ""
    expect_one_error(shop, Shop.err_msg(:not_enough_tokens, "shop type"))
  end

  it "detects a bad object type" do
    shop.contents[/^\d+(?= \d+)/] = "HI"
    expect_one_error(shop, Shop.err_msg(:bad_object_type))
  end

  it "detects invalid negative margin" do
    shop.contents[/150/] = "-15"
    expect_one_error(shop, Shop.err_msg(:negative_profit_margin))
  end

  it "detects invalid profit margin" do
    shop.contents[/150/] = "ABC"
    expect_one_error(shop, Shop.err_msg(:invalid_profit_margin))
  end

  it "detects missing tokens on the profit line" do
    shop.contents[/150 /] = ""
    expect_one_error(shop, Shop.err_msg(:not_enough_tokens, "profit"))
  end

  it "detects invalid hours" do
    shop.contents[/0 23/] = "A 23"
    expect_one_error(shop, Shop.err_msg(:bad_hour))
  end

  it "detects hours out of bounds" do
    shop.contents[/0 23/] = "0 33"
    expect_one_error(shop, Shop.err_msg(:hours_out_of_bounds))
  end

  it "detects missing tokens on the hours line" do
    shop.contents[/0 23/] = "0"
    expect_one_error(shop, Shop.err_msg(:not_enough_tokens, "hours"))
  end

  it "detects missing lines in a shop" do
    shop.contents[/0 23/] = ""
    expect_one_error(shop, Shop.err_msg(:missing_line, "business hours"))
  end

end
