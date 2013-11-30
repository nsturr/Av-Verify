require './spec/spec_helper'
require './lib/sections/resets'

data = File.read("./spec/test-resets.are")

describe Resets do

  let(:resets) { Resets.new(data) }

  it_should_behave_like Section do
    let(:section) { resets }
  end

  it "ignores whitespace and comments" do
    resets.parse

    expect(resets.errors).to be_empty
  end

  it "detects resets whose limit won't let them load" do
    i = resets.contents.rindex(/(?<=M 0 11409 )4/)
    resets.contents[i] = "3"

    expect_one_error(resets, Resets.err_msg(:reset_limit, 3, 3))
  end

  it "detects eqipment resets targeting a slot that's filled" do
    m = resets.contents.match(/^E 0 21.*\n/)
    resets.contents.insert(m.begin(0), m[0])

    expect_one_error(resets, Resets.err_msg(:wear_loc_filled))
  end

  it "detects equipment or inventory resets that don't follow a mob" do
    i = resets.contents.index("E 0 11400")
    resets.contents.insert(i, "O 0 11455 0 11406\n")

    expect_one_error(resets, Resets.err_msg(:reset_doesnt_follow_mob, "Equipment"))
  end

  it "detects a missing delimiter" do
    resets.contents.chop!

    expect_one_error(resets, resets.delimiter_errors(:no_delimiter))
  end

  it "detects invalid text after its delimiter" do
    resets.contents << "\nOh hi there!"

    expect_one_error(resets, resets.delimiter_errors(:continues_after_delimiter))
  end

end

describe Reset do

  it "detects invalid reset types" do
    invalid = Reset.new("This probably should have been a comment, right?")

    expect_one_error(invalid, Reset.err_msg(:invalid_reset))
  end

  it "ignores comments starting with *" do
    valid = Reset.new("M 0 11400 1 11406* Questmaster -> Northern Forge")
    valid.parse

    expect(valid.errors).to be_empty
  end

  context "when parsing a mob reset" do

    let(:reset) { Reset.new("M 0 11400 1 11406 * Questmaster -> Northern Forge") }
    let(:i_zero) { reset.line.index("0") }
    let(:i_mob) { reset.line.index("11400") }
    let(:i_limit) { reset.line.index(/\b1\b/) }
    let(:i_room) { reset.line.index("11406") }

    it "detects invalid placeholder zero" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_m_matches))
    end

    it "detects invalid mob vnum" do
      reset.line[i_mob] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "mob"))
    end

    it "detects invalid spawn limit" do
      reset.line[i_limit] = "a"

      expect_one_error(reset, Reset.err_msg(:invalid_limit, "mob"))
    end

    it "detects invalid room vnum" do
      reset.line[i_room] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "room"))
    end

    it "detects missing tokens on the line" do
      reset.line.replace("M 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "mob"))
    end

    it "parses the mob vnum, limit, and spawn room" do
      reset.parse

      expect(reset.vnum).to eq(11400)
      expect(reset.limit).to eq(1)
      expect(reset.target).to eq(11406)
      expect(reset.slot).to be_nil
    end

  end

  context "when parsing an inventory reset" do

    let(:reset) { Reset.new("G 0 11431 0          Red glowing dust, inventory") }
    let(:i_limit) { reset.line.index("0") }
    let(:i_vnum) { reset.line.index("11431") }
    let(:i_zero) { reset.line.rindex("0") }

    it "detects invalid spawn limit" do
      reset.line[i_limit] = "A"

      expect_one_error(reset, Reset.err_msg(:invalid_limit, "inventory"))
    end

    it "detects invalid object vnum" do
      reset.line[i_vnum] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "object"))
    end

    it "detects an invalid placeholder zero" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_g_matches))
    end

    it "detects an incomplete line" do
      reset.line.replace("G 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "inventory"))
    end

    it "parses the object vnum and spawn limit" do
      reset.parse

      expect(reset.vnum).to eq(11431)
      expect(reset.limit).to eq(0)
      expect(reset.target).to be_nil
      expect(reset.slot).to be_nil
    end

  end

  context "when parsing an equipment reset" do

    let(:reset) { Reset.new("E 0 11400 0 16       Hand axe, wield") }
    let(:i_limit) { reset.line.index("0") }
    let(:i_vnum) { reset.line.index("11400") }
    let(:i_zero) { reset.line.rindex("0") }
    let(:i_wear) { reset.line.rindex("16") }

    it "detects invalid spawn limit" do
      reset.line[i_limit] = "A"

      expect_one_error(reset, Reset.err_msg(:invalid_limit, "equipment"))
    end

    it "detects invalid object vnum" do
      reset.line[i_vnum] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "object"))
    end

    it "detects an invalid placeholder zero" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_e_matches))
    end

    it "detects an invalid wear location" do
      reset.line[i_wear] = "hi"

      expect_one_error(reset, Reset.err_msg(:invalid_field, "wear location"))
    end

    it "detects a wear location out of bounds" do
      reset.line[i_wear] = "55"

      expect_one_error(reset, Reset.err_msg(:wear_loc_out_of_bounds))
    end

    it "detects an incomplete line" do
      reset.line.replace("E 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "equipment"))
    end

    it "parses the object vnum and wear location" do
      reset.parse

      expect(reset.vnum).to eq(11400)
      expect(reset.limit).to eq(0)
      expect(reset.target).to be_nil
      expect(reset.slot).to eq(16)
    end

  end

  context "when parsing an object reset" do

    let(:reset) { Reset.new("O 0 11455 0 11406   Inscription to imms") }
    let(:i_zero) { reset.line.index("0") }
    let(:i_object) { reset.line.index("11455") }
    let(:i_room) { reset.line.index("11406") }

    it "detects invalid placeholder zeroes" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_o_matches))
    end

    it "detects invalid object vnum" do
      reset.line[i_object] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "object"))
    end

    it "detects invalid room vnum" do
      reset.line[i_room] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "room"))
    end

    it "detects missing tokens on the line" do
      reset.line.replace("O 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "object"))
    end

    it "parses the object vnum and spawn room" do
      reset.parse

      expect(reset.vnum).to eq(11455)
      expect(reset.limit).to be_nil
      expect(reset.target).to eq(11406)
      expect(reset.slot).to be_nil
    end

  end

  context "when parsing a container reset" do

    let(:reset) { Reset.new("P 0 11431 0 11444   You know how it is") }
    let(:i_zero) { reset.line.index("0") }
    let(:i_object) { reset.line.index("11431") }
    let(:i_container) { reset.line.index("11444") }

    it "detects invalid placeholder zeroes" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_p_matches))
    end

    it "detects invalid object vnum" do
      reset.line[i_object] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "object"))
    end

    it "detects invalid container vnum" do
      reset.line[i_container] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "container"))
    end

    it "detects missing tokens on the line" do
      reset.line.replace("P 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "container"))
    end

    it "parses the object vnum and container vnum" do
      reset.parse

      expect(reset.vnum).to eq(11431)
      expect(reset.limit).to be_nil
      expect(reset.target).to eq(11444)
      expect(reset.slot).to be_nil
    end

  end

  context "when parsing a door reset" do

    let(:reset) { Reset.new("D 0 11442 2 1        Gate south from crater rim to entrance (unlocked)") }
    let(:i_zero) { reset.line.index("0") }
    let(:i_vnum) { reset.line.index("11442") }
    let(:i_dir) { reset.line.rindex("2") }
    let(:i_state) { reset.line.rindex("1") }

    it "detects an invalid placeholder zero" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_d_matches))
    end

    it "detects invalid room vnum" do
      reset.line[i_vnum] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "room"))
    end

    it "detects invalid door direction" do
      reset.line[i_dir] = "a"

      expect_one_error(reset, Reset.err_msg(:bad_door_direction))
    end

    it "detects out of range door direction" do
      reset.line[i_dir] = "99"

      expect_one_error(reset, Reset.err_msg(:door_out_of_bounds))
    end

    it "detects invalid door state" do
      reset.line[i_state] = "a"

      expect_one_error(reset, Reset.err_msg(:bad_door_state))
    end

    it "detects and out of range door state" do
      reset.line[i_state] = "9"

      expect_one_error(reset, Reset.err_msg(:door_state_out_of_bounds))
    end

    it "detects an incomplete line" do
      reset.line.replace("D 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "door"))
    end

    it "parses the room vnum, door direction, and state" do
      reset.parse

      expect(reset.vnum).to eq(11442)
      expect(reset.target).to eq(2)
      expect(reset.slot).to eq(1)
    end

  end

  context "when parsing a random reset" do

    let(:reset) { Reset.new("R 0 11450 3       * Only randomize the first 3 exits (west remains untouched)") }
    let(:i_zero) { reset.line.index("0") }
    let(:i_vnum) { reset.line.index("11450") }
    let(:i_exits) { reset.line.index(/\b3\b/) }

    it "detects an invalid placeholder zero" do
      reset.line[i_zero] = "A"

      expect_one_error(reset, Reset.err_msg(:reset_r_matches))
    end

    it "detects invalid room vnum" do
      reset.line[i_vnum] = "howdy"

      expect_one_error(reset, Reset.err_msg(:invalid_vnum, "room"))
    end

    it "detects an invalid number of doors" do
      reset.line[i_exits] = "a"

      expect_one_error(reset, Reset.err_msg(:bad_number_of_exits))
    end

    it "detects an out of range number of doors" do
      reset.line[i_exits] = "9"

      expect_one_error(reset, Reset.err_msg(:number_of_exits))
    end

    it "detects an incomplete line" do
      reset.line.replace("R 0 ")

      expect_one_error(reset, Reset.err_msg(:not_enough_tokens, "random"))
    end
  end

end
