# Some quick and easy ANSI color codes in AVATAR parlance
class String

  def CC!(color_code)
    case color_code
    when :K
      self.colorize!("30")
    when :BK
      self.colorize!("30;1")
    when :B
      self.colorize!("34")
    when :BB
      self.colorize!("34;1")
    when :C
      self.colorize!("36")
    when :BC
      self.colorize!("36;1")
    when :G
      self.colorize!("32")
    when :BG
      self.colorize!("32;1")
    when :R
      self.colorize!("31")
    when :BR
      self.colorize!("31;1")
    when :Y
      self.colorize!("33")
    when :BY
      self.colorize!("33;1")
    when :W
      self.colorize!("37")
    when :BW
      self.colorize!("37;1")
    when :P
      self.colorize!("35")
    when :BP
      self.colorize!("35;1")
    end
  end

  def K ; colorize "30" end

  def K! ; colorize! "30" end

  def BK ; colorize "30;1" end

  def BK! ; colorize! "30;1" end

  def B ; colorize "34" end

  def B! ; colorize! "34" end

  def BB ; colorize "34;1" end

  def BB! ; colorize! "34;1" end

  def C ; colorize "36" end

  def C! ; colorize! "36" end

  def BC ; colorize "36;1" end

  def BC! ; colorize! "36;1" end

  def G ; colorize "32" end

  def G! ; colorize! "32" end

  def BG ; colorize "32;1" end

  def BG! ; colorize! "32;1" end

  def R ; colorize "31" end

  def R! ; colorize! "31" end

  def BR ; colorize "31;1" end

  def BR! ; colorize! "31;1" end

  def Y ; colorize "33" end

  def Y! ; colorize! "33" end

  def BY ; colorize "33;1" end

  def BY! ; colorize! "33;1" end

  def W ; colorize "37" end
  
  def W! ; colorize! "37" end

  def BW ; colorize "37;1" end

  def BW! ; colorize! "37;1" end

  def P ; colorize "35" end

  def P! ; colorize! "35" end

  def BP ; colorize "35;1" end

  def BP! ; colorize! "35;1" end

  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def colorize!(color_code)
    self.insert(0, "\e[#{color_code}m")
    self << "\e[0m"
  end
end
