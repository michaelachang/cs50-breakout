Powerup = Class{}

function Powerup:init()
    -- simple positional and dimensional variables
    self.width = 16
    self.height = 16

    self.dy = 30
    self.x = math.random(VIRTUAL_WIDTH - 16)
    self.y = 0

    self.inPlay = true
end

function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function Powerup:update(dt)
    self.y = self.y + self.dy * dt
    
end

function Powerup:render(num)
    if self.inPlay == true then
        love.graphics.draw(gTextures['main'], gFrames['powerups'][num], self.x, self.y)
    end
end