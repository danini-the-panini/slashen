require 'gosu'
require 'opengl'
require 'glfw'

MOVEMENT_SPEED = 0.3
NASTY_SPEED = 0.2
SHWING = 0.01
MULTIKILL_SPEED = 0.003
NASTY_TIME = 1000
ATTACK_MOVE = 0.15
NASTY_STAYS = 0.001

UP, DOWN, LEFT, RIGHT = 0, 1, 2, 3

OpenGL.load_dll
GLFW.load_dll

include OpenGL
include GLFW

glfwInit

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

class MultiKill
  def initialize window, kills, x, y
    @sprite = Gosu::Image.from_text window, "#{kills} kills!", Gosu::default_font_name, 10+(kills*10)
    @time = 1.0
    @x, @y = x, y
  end

  def update dt
    @time -= MULTIKILL_SPEED * dt

    @time <= 0.0
  end

  def draw
    @sprite.draw_rot @x, @y-(1-@time)*40, 1, 0
  end
end

class Slashen < Gosu::Window
  def initialize width = 800, height = 600, fullscreen = false
    super

    @dude = Gosu::Image.new self, "dude.png"
    @dead_dude = Gosu::Image.new self, "dead_dude.png"
    @shwing_sprite = Gosu::Image.load_tiles self, "shwing.png", 72, 72, false
    @debug = Gosu::Image.new self, "debug.png"
    @nasty = Gosu::Image.new self, "nasty.png"
    @dead_nasty = Gosu::Image.new self, "dead_nasty.png"
    @message = Gosu::Image.from_text self, "Press Enter to Kill Things", Gosu::default_font_name, 30
    @time = Gosu::milliseconds
    @speed = Gosu::Image.new self, "speed.png"
    @multikills = []
    start_game
    @playing = false
    @best_score = 0
    @best_kills = 0
    @best_combo = 0
    update_best_image
  end

  def button_up id
    if @playing
      case id
      when Gosu::KbUp, Gosu::KbI, Gosu::GpUp
        @inputs[UP] = false
      when Gosu::KbDown, Gosu::KbK, Gosu::GpDown
        @inputs[DOWN] = false
      when Gosu::KbLeft, Gosu::KbJ, Gosu::GpLeft
        @inputs[LEFT] = false
      when Gosu::KbRight, Gosu::KbL, Gosu::GpRight
        @inputs[RIGHT] = false
      end
    end
  end

  def reset_game
    @nasties = []
    @x, @y = 400, 300
    @vx, @vy = 0, 0
    @dir_x, @dir_y = 1, 0
    @last_nasty = 0
    @shwing = 0.0
    @inputs = Array.new(4, false)
    @me_a = 0.0
    @me_d = 1.0
    @kills = 0
    @score = 0
    @max_combo = 0
    @dead = false
    update_score_image
  end

  def update_score_image
    @score_message = Gosu::Image.from_text self, "#{@kills} kills, #{@score} score, best combo: #{@max_combo}", Gosu.default_font_name, 30
  end

  def update_best_image
    @best_image = Gosu::Image.from_text self, "Best #{@best_kills} kills, #{@best_score} score, #{@best_combo} combo.", Gosu::default_font_name, 30
  end

  def update_you_got
    @you_got = Gosu::Image.from_text self, "You got #{@kills} kills, #{@score} score, #{@max_combo} combo.", Gosu::default_font_name, 30
  end

  def start_game
    reset_game
    @playing = true
  end

  def do_shwing
    @shwing = 1.0
    @shwing_kills = 0
  end

  def button_down id
    if !@playing
      start_game if id == Gosu::KbEnter || id == Gosu::KbReturn || id == Gosu::GpButton12
    else
      case id
      when Gosu::KbUp, Gosu::KbI, Gosu::GpUp
        @inputs[UP] = true
      when Gosu::KbDown, Gosu::KbK, Gosu::GpDown
        @inputs[DOWN] = true
      when Gosu::KbLeft, Gosu::KbJ, Gosu::GpLeft
        @inputs[LEFT] = true
      when Gosu::KbRight, Gosu::KbL, Gosu::GpRight
        @inputs[RIGHT] = true
      when Gosu::KbSpace, Gosu::GpButton12
        do_shwing unless @shwing > 0.0
      end
    end
  end

  def update
    newtime = Gosu::milliseconds
    @delta = newtime - @time
    @time = newtime

    @multikills.delete_if do |mk|
      mk.update @delta
    end

    if @playing
      vx = 0
      vx += 1 if @inputs[RIGHT]
      vx -= 1 if @inputs[LEFT]
      vy = 0
      vy += 1 if @inputs[DOWN]
      vy -= 1 if @inputs[UP]

      if vx != 0 || vy != 0
        @me_a = Math::atan2(vy, vx)
        @me_d = Math::sqrt(vx*vx + vy*vy)
        vx /= @me_d
        vy /= @me_d
        @dir_x = vx
        @dir_y = vy
      end

      if @shwing > 0.0
        @shwing -= SHWING * @delta
        vx += @dir_x * ATTACK_MOVE * @delta
        vy += @dir_y * ATTACK_MOVE * @delta

        if @shwing <= 0.0
          @score += @shwing_kills*2 - 1 unless @shwing_kills == 0
          if @shwing_kills > 1
            @multikills << MultiKill.new(self, @shwing_kills, @x, @y)
          end
          if @shwing_kills > @max_combo
            @max_combo = @shwing_kills
          end
          update_score_image
        end
      end

      @x += vx * @delta * MOVEMENT_SPEED
      @y += vy * @delta * MOVEMENT_SPEED

      if @time - @last_nasty > NASTY_TIME
        @last_nasty = @time
        a = Gosu::random(0,Math::PI*2)
        @nasties << { x: 1000*Math::cos(a), y: 1000*Math::sin(a), a: 0.0 }
      end

      @nasties.delete_if do |nasty|
        if nasty[:death].nil?
          dx = @x - nasty[:x]
          dy = @y - nasty[:y]

          d = Math::sqrt(dx*dx + dy*dy)
          nasty_dot = dot(@dir_x/@me_d,@dir_y/@me_d,-dx/d,-dy/d)
          if d < (36+16) && nasty_dot > 0 && @shwing > 0.0
            @shwing_kills += 1
            nasty[:death] = 1.0
            nasty[:a] = @me_a*180.0/Math::PI + (Gosu::random(-20.0,20.0))
            @kills += 1
            update_score_image
          elsif d < 24+16
            @playing = false
            @dead = true
            if @score > @best_score
              @best_score = @score
            end
            if @kills > @best_kills
              @best_kills = @kills
            end
            if @max_combo > @best_combo
              @best_combo = @max_combo
            end
            update_best_image
            update_you_got
          end

          nasty[:x] += (dx/d) * NASTY_SPEED * @delta
          nasty[:y] += (dy/d) * NASTY_SPEED * @delta

          false
        else
          nasty[:death] -= NASTY_STAYS * @delta

          nasty[:death] < 0.0
        end
      end
    end
  end

  def endpoints_facing x1, y1, x2, y2, r
    a = Gosu::angle x1, y1, x2, y2
    x3 = x1 + Gosu::offset_x(a + 90, r)
    y3 = y1 + Gosu::offset_y(a + 90, r)

    x4 = x1 + Gosu::offset_x(a - 90, r)
    y4 = y1 + Gosu::offset_y(a - 90, r)

    [x3, y3, x4, y4]
  end

  def draw
    gl do
      if @dead
        glClearColor 0, 0, 0, 1.0
      else
        glClearColor 0.3, 0.3, 0.3, 1.0
      end
      glClear GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT
    end

    @nasties.each do |nasty|
      next if nasty[:death]

      x = nasty[:x]
      y = nasty[:y]

      bx1, by1, bx2, by2 = endpoints_facing x, y, @x, @y, 16
      px1, py1, px2, py2 = endpoints_facing @x, @y, x, y, 24

      #gl 100 do
        #glBegin GL_LINES
        #glVertex3f x.to_f, y.to_f, 0.0
        #glVertex3f @x.to_f, @y.to_f, 0.0
        #glEnd

        #glBegin GL_LINES
        #glVertex3f bx1.to_f, by1.to_f, 0.0
        #glVertex3f bx2.to_f, by2.to_f, 0.0
        #glVertex3f px2.to_f, py2.to_f, 0.0
        #glVertex3f px1.to_f, py1.to_f, 0.0
        #glEnd
      #end

      a1 = Gosu::angle @x, @y, bx1, by1
      a2 = Gosu::angle @x, @y, bx2, by2

      ax1 = bx1 + Gosu::offset_x(a1, 1000)
      ay1 = by1 + Gosu::offset_y(a1, 1000)

      ax2 = bx2 + Gosu::offset_x(a2, 1000)
      ay2 = by2 + Gosu::offset_y(a2, 1000)

      gl 0 do
        glDisable GL_DEPTH_TEST
        glEnable GL_BLEND
        glBlendEquationSeparate GL_FUNC_ADD, GL_FUNC_ADD
        glBlendFuncSeparate GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO

        glBegin GL_QUADS
        glColor4f 0, 0, 0, 0
        glVertex3f ax1.to_f, ay1.to_f, 0.0
        glVertex3f ax2.to_f, ay2.to_f, 0.0
        glColor4f 0, 0, 0, 1
        glVertex3f bx2.to_f, by2.to_f, 0.0
        glVertex3f bx1.to_f, by1.to_f, 0.0
        glEnd
      end
    end

    @dead_dude.draw_rot(@x, @y, 1, 0) if @dead

    @nasties.each do |nasty|
      (nasty[:death] ? @dead_nasty : @nasty).draw_rot nasty[:x], nasty[:y], 1, nasty[:a]
    end

    @dude.draw_rot(@x, @y, 1, 0) unless @dead

    if @shwing > 0.0
      i = (@shwing * @shwing_sprite.size).to_i
      i = 0 if i < 0
      i = @shwing_sprite.size-1 if i >= @shwing_sprite.size
      @shwing_sprite[i].draw_rot @x, @y, 1, @me_a*180.0/Math::PI
      #@debug.draw_rot @x, @y, 1, @me_a*180.0/Math::PI

      @speed.draw_rot @x, @y, 1, @me_a*180.0/Math::PI, 1.0, 0.5
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

    @multikills.each do |mk|
      mk.draw
    end
  end
end

Slashen.new.show
