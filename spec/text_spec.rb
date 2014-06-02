require 'minitest/autorun'

require_relative '../lib/droxi/text'

describe Text do
  before do
    @columns = Text::DEFAULT_WIDTH
    @paragraph = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, \
                  sed do eiusmod tempor incididunt ut labore et dolore \
                  magna aliqua. Ut enim ad minim veniam, quis nostrud \
                  exercitation ullamco laboris nisi ut aliquip ex ea \
                  commodo consequat. Duis aute irure dolor in reprehenderit \
                  in voluptate velit esse cillum dolore eu fugiat nulla \
                  pariatur. Excepteur sint occaecat cupidatat non proident, \
                  sunt in culpa qui officia deserunt mollit anim id est \
                  laborum.".squeeze(' ')
    @big_word = "Lopadotemachoselachogaleokranioleipsanodrimhypotrimmatosilphi\
                 oparaomelitokatakechymenokichlepikossyphophattoperisteralektr\
                 yonoptekephalliokigklopeleiolagoiosiraiobaphetraganopterygon".
                   gsub(' ', '')
  end

  describe "when wrapping text" do
    it "won't return any line larger than the screen width if unnecessary" do
      Text.wrap(@paragraph).all? do |line|
        line.length <= @columns
      end.must_equal true
    end

    it "won't split a word larger than the screen width" do
      Text.wrap(@big_word).length.must_equal 1
    end
  end

  describe "when tabulating text" do
    it "must space items equally" do
      lines = Text.table(@paragraph.split)
      lines = lines[0, lines.length - 1]

      space_positions = [0]
      while lines.first.index(/  \S/, space_positions.last + 3)
        space_positions << lines.first.index(/  \S/, space_positions.last + 3)
      end

      space_positions.drop(1).all? do |position|
        lines.all? { |line| /  \S/.match(line[position, 3]) }
      end.must_equal true
    end

    it "won't return any line larger than the screen width if unnecessary" do
      Text.table(@paragraph.split).all? do |line|
        line.length <= @columns
      end.must_equal true
    end

    it "won't split a word larger than the screen width" do
      Text.table([@big_word]).length.must_equal 1
    end
  end
end
