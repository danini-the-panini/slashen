require 'gosu'

MOVEMENT_SPEED = 0.3
NASTY_SPEED = 0.2
SHWING = 0.01
NASTY_TIME = 1000

UP, DOWN, LEFT, RIGHT = 0, 1, 2, 3

def abs x
  if x < 0
    -x
  else
    x
  end
end

def dot x1, y1, x2, y2
  x1*x2 + y1*y2
end

class Slashen < Gosu::Window
  def initialize width = 640, height = 480, fullscreen = false
    super

    @dude = Gosu::Image.new self, "dude.png"
    @shwing_sprite = Gosu::Image.load_tiles self, "shwing.png", 72, 72, false
    @debug = Gosu::Image.new self, "debug.png"
    @nasty = Gosu::Image.new self, "nasty.png"
    @message = Gosu::Image.from_text self, "Press Space to Kill Things", "monospace", 30
    @time = Gosu::milliseconds
    start_game
    @playing = false
    @best_score = 0
    @best_image = Gosu::Image.from_text self, "Best #{@best_score} kills", "monospace", 30
  end

  def button_up id
    return unless @playing
    case id
    when Gosu::KbUp
      @inputs[UP] = false
    when Gosu::KbDown
      @inputs[DOWN] = false
    when Gosu::KbLeft
      @inputs[LEFT] = false
    when Gosu::KbRight
      @inputs[RIGHT] = false
    end
  end

  def start_game
    @playing = true
    @nasties = []
    @x, @y = 320, 240
    @vx, @vy = 0, 0
    @dir_x, @dir_y = 1, 0
    @last_nasty = 0
    @shwing = 0.0
    @inputs = Array.new(4, false)
    @me_a = 0.0
    @me_d = 1.0
    @score = 0
    @score_message = Gosu::Image.from_text self, "#{@score} kills", "monospace", 30
  end

  def button_down id
    if !@playing && id == Gosu::KbSpace
      start_game
      return
    end
    case id
    when Gosu::KbUp
      @inputs[UP] = true
    when Gosu::KbDown
      @inputs[DOWN] = true
    when Gosu::KbLeft
      @inputs[LEFT] = true
    when Gosu::KbRight
      @inputs[RIGHT] = true
    when Gosu::KbSpace
      @shwing = 1.0
    end
  end

  def update
    newtime = Gosu::milliseconds
    @delta = newtime - @time
    @time = newtime

    if @playing
      vx = 0
      vx += 1 if @inputs[RIGHT]
      vx -= 1 if @inputs[LEFT]
      vy = 0
      vy += 1 if @inputs[DOWN]
      vy -= 1 if @inputs[UP]
      @x += vx * @delta * MOVEMENT_SPEED
      @y += vy * @delta * MOVEMENT_SPEED

      if @inputs.any?
        @dir_x = vx
        @dir_y = vy
        @me_a = Math::atan2(vy, vx)
        @me_d = Math::sqrt(vx*vx + vy*vy)
      end

      if @shwing > 0.0
        @shwing -= SHWING * @delta
      end

      if @time - @last_nasty > NASTY_TIME
        @last_nasty = @time
        a = Gosu::random(0,Math::PI*2)
        @nasties << { x: 1000*Math::cos(a), y: 1000*Math::sin(a) }
      end


      @nasties.delete_if do |nasty|
        dx = @x - nasty[:x]
        dy = @y - nasty[:y]

        d = Math::sqrt(dx*dx + dy*dy)
        nasty_dot = dot(@dir_x/@me_d,@dir_y/@me_d,-dx/d,-dy/d)
        kill = false
        if d < (36+16) && nasty_dot > 0 && @shwing > 0.0
          kill = true
          @score += 1
          @score_message = Gosu::Image.from_text self, "#{@score} kills", "monospace", 30
        elsif d < 24+16
          @playing = false
          @you_got = Gosu::Image.from_text self, "You got #{@score} kills", "monospace", 30
          if @score > @best_score
            @best_score = @score
            @best_image = Gosu::Image.from_text self, "Best #{@best_score} kills", "monospace", 30
          end
        end

        nasty[:x] += (dx/d) * NASTY_SPEED * @delta
        nasty[:y] += (dy/d) * NASTY_SPEED * @delta

        kill
      end
    end
  end

  def draw
    @dude.draw_rot(@x, @y, 1, 0)

    @nasties.each do |nasty|
      @nasty.draw_rot nasty[:x], nasty[:y], 1, 0.0
    end

    if @shwing > 0.0
      i = (@shwing * @shwing_sprite.size).to_i
      @shwing_sprite[i].draw_rot @x, @y, 1, @me_a*180.0/Math::PI
      #@debug.draw_rot @x, @y, 1, @me_a*180.0/Math::PI
    end

    unless @playing
      @message.draw 0, 0, 1
      @best_image.draw 0, 40, 1
      if @you_got
        @you_got.draw 0, 80, 1
      end
    else
      @score_message.draw 0, 0, 1
    end
  end
end

Slashen.new.show
