--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.level = params.level

    self.ballsCounter = 1
    self.balls = {
        [1] = params.ball
    }

    self.powerups = {}
    self.lockedBrickHit = false
    self.recoverPoints = self.health == 3 and 5000 or params.recoverPoints

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)

    self.hitCounter = 0
    self.hitGoal = 1
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for k, ball in pairs(self.balls) do
        self:checkPaddleCollision(ball)
        self:checkBrickCollision(ball)
        ball:update(dt)
    end
    
    -- powerup logic
    if next(self.powerups) == 1 then
        for k, powerup in pairs(self.powerups) do
            if powerup.inPlay then
                -- detect collision with powerup
                if powerup:collides(self.paddle) then
                    powerup.inPlay = false

                    -- ball powerup
                    if k == 1 then
                        -- initialize new balls
                        self.ballsCounter = 3

                        for i = 2, 3, 1 do
                            self.balls[i] = Ball()
                            self.balls[i].skin = math.random(7)
                            self.balls[i]:reset()
                            self.balls[i].dx = math.random(-200, 200)
                            self.balls[i].dy = math.random(-50, -60)
                        end
                    elseif k == 2 then
                        gSounds['hurt']:play()
                        -- logic for key
                    end
                    gSounds['confirm']:play()
                end
                powerup:update(dt)
            end
        end
    end

    -- if ball goes below bounds remove from play
    self.falseCounter = 0
    for k, ball in pairs(self.balls) do

        if ball.inPlay then
            if ball.y >= VIRTUAL_HEIGHT then
                ball.inPlay = false
                self.falseCounter = self.falseCounter + 1
            end
        else
            self.falseCounter = self.falseCounter + 1   
        end

        -- Check if all balls have fallen
        if self.falseCounter == self.ballsCounter then
            self.health = self.health - 1
            gSounds['hurt']:play()

            -- Reduce paddle size
            self.paddle.size = math.max(1, self.paddle.size - 1)
            self.paddle.width = 32 * self.paddle.size

            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()

    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    if self.hitCounter >= 1 then
        self.powerups[1]:render(9)
        if self.hitCounter > 2 then
            self.powerups[2]:render(10)
        end
    end

    self.paddle:render()
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end

    -- display counter
    love.graphics.setFont(gFonts['small'])
    love.graphics.setColor(0, 255, 255, 255)
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function PlayState:checkPaddleCollision(ball)
    if ball:collides(self.paddle) then
        -- raise ball above paddle in case it goes below it, then reverse dy
        ball.y = self.paddle.y - 8
        ball.dy = -ball.dy

        --
        -- tweak angle of bounce based on where it hits the paddle
        --

        -- if we hit the paddle on its left side while moving left...
        if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
            ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
        
        -- else if we hit the paddle on its right side while moving right...
        elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
            ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
        end

        gSounds['paddle-hit']:play()
    end
end

function PlayState:checkBrickCollision(ball)
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay and ball:collides(brick) then

            -- initialize powerups
            self.hitCounter = self.hitCounter + 1
            if self.hitCounter == 1 then
                self.powerups[1] = Powerup()
            elseif self.hitCounter == 3 and self.lockedBrickHit == false then
                self.powerups[2] = Powerup()
            end

            -- add to score
            if brick.color == 22 then
                if self.hitCounter > 3 then
                    if self.powerups[2].inPlay == false then
                        self.score = self.score + 5000
                        gSounds['confirm']:play()
                        gSounds['confirm']:play()
                        self.lockedBrickHit = true
                    end
                end
            else
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
            end

            -- trigger the brick's hit function, which removes it from play
            brick:hit()

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = math.max(100000, self.recoverPoints * 2)

                -- play recover sound effect
                gSounds['recover']:play()

                -- grow paddle
                self.paddle.size = math.min(4, self.paddle.size + 1)
                self.paddle.width = 32 * self.paddle.size
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.ball,
                    recoverPoints = self.recoverPoints
                })
            end

            --
            -- collision code for bricks
            --
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 
            --

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if ball.x + 2 < brick.x and ball.dx > 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x - 8
            
            -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                
                -- flip x velocity and reset position outside of brick
                ball.dx = -ball.dx
                ball.x = brick.x + 32
            
            -- top edge if no X collisions, always check
            elseif ball.y < brick.y then
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y - 8
            
            -- bottom edge if no X collisions or top collision, last possibility
            else
                
                -- flip y velocity and reset position outside of brick
                ball.dy = -ball.dy
                ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(ball.dy) < 150 then
                ball.dy = ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end
end