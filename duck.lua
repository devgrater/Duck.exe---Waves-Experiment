local g = 160
local img = love.graphics.newImage("duck.png")
local duck = love.graphics.newImage("duck_duck.png")
local glide = love.graphics.newImage("duck_glide.png")

Duck = {}


function Duck.init()
    Duck.x = 32
    Duck.y = 16
    Duck.vecy = 0
    Duck.swimSpeed = 32
    --Duck.airSpeed = 0
    --Duck.diveSpeed = 160 --Not used!
    Duck.isInAir = true
    Duck.isInWater = false
    Duck.wasInWater = false --Used for water particle polish -- Overall the performance is pretty ideal?
    Duck.isDiving = false --Whether down key is held
    Duck.isFlapping = false --Whether up key is held
    Duck.startFlap = true --Whether this is the first time the duck uses flap -- Used only for sound effects
    Duck.isMoving = 0
    Duck.dirx = 1 --The direction that the duck, if moving, should move in.
    --Duck.facing = 1 -- Not used!
    Duck.rot = 0 --Actual rotation of the duck due to waves
    Duck.displayRot = 0 -- The rotation that the player sees. This is interpolated over time.
    Duck.left = 0 --Whetehr left key is held
    Duck.right = 0 --Right key
    Duck.hunger = 100 --This reduces over time. --This is now called health
    Duck.invincibleTimer = 1 --Bascially how long we have to wait before the duck no longer becomes invincible.
                             --If this value goes below 0, it means its not invincible.
end

Duck.init()

function Duck.update(dt)
    Duck.invincibleTimer = Duck.invincibleTimer - dt
    --Dealing with the player hunger
    --Hunger should also go slower, if there's lazers on the screen.

    -- Vertical Movement
    Duck.y = Duck.y + Duck.vecy * dt
    -- Horizontal movement
    Duck.x = Duck.x + (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed * dt
    Duck.x = math.min(math.max(Duck.x, 4), 60) --Cap position

    --Movement when touching water and not touching water
    local pillar = getPointAt(Duck.x) - springs[math.floor(Duck.x)].offset / 2
    if(Duck.y + 2 >=  64 - pillar) then -- If the player is touching water, we use different physics.
        local diff = 64 - pillar - Duck.y
        if(not Duck.isDiving) then
            --If the duck is not diving, apply a upward force to the duck. This usually pushes the duck upward
            --and the duck will bounce on water for a few times.
            Duck.vecy = (Duck.vecy + diff * 80 * dt)
            Duck.vecy = Duck.vecy + g * 0.01 * dt
            Duck.vecy = Duck.vecy * 0.990 --Dampen the force a bit so the duck doesn't go off screen.
        else
            Duck.vecy = Duck.vecy + g * dt
        end
        -- Cap the duck's y position so it doesn't dive off screen
        if(Duck.y >= 53) then
            Duck.y = 53
            if(Duck.vecy > 0) then
                Duck.vecy = 0
            end
        end
        Duck.isInAir = false
        Duck.isInWater = true
        Duck.startFlap = true
    else --Otherwise, use normal gravity.
        Duck.isInWater = false

        if(Duck.vecy < 0) then
            Duck.isInAir = true
        end

        Duck.vecy = Duck.vecy + g * dt --Simple gravity
        if(Duck.isDiving) then --If down key is down while falling the player falls faster
            Duck.vecy = Duck.vecy + g * dt * 2
        end
        if(Duck.isFlapping and Duck.vecy > 0) then --If up key is down while falling, the player falls slower
            Duck.vecy = Duck.vecy - g * dt * 0.666
            if(Duck.vecy > 0 and Duck.isInAir and Duck.startFlap) then
                Audio.play("flap")
                Duck.startFlap = false
            end
        end
    end

    -- If the duck jumped out of the water body, then we spawn a few particles.
    if(Duck.wasInWater and not Duck.isInWater) then
        for i = 1,6 do
            local x = (math.random() - 0.5) * 3 + Duck.x
            local y = (math.random() - 0.5) * 3 + Duck.y
            local vx = -(math.random() - 0.5) * 8 + (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed / 2
            local vy = Duck.vecy / 2 + (math.random() - 0.5) * 40
            createParticle(x, y, vx, vy)
        end
        splash(math.floor(Duck.x), Duck.vecy / 3)
    elseif(not Duck.wasInWater and Duck.isInWater) then --If the duck jumped back in water, then we also spawn particles, with different settings.
        for i = 1,6 do
            local x = (math.random() - 0.5) * 3 + Duck.x
            local y = (math.random() - 0.5) * 3 + Duck.y
            -- Water partcile should move against the player's movement.
            local vx = (math.random() - 0.5) * 8 - (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed / 2
            local vy = -Duck.vecy / 2 + (math.random() - 0.5) * 40
            createParticle(x, y, vx, vy)
        end
        --Lets put splash function here:
        splash(math.floor(Duck.x), Duck.vecy / 3)
    end

    --Interpolate the displayed rotation
    Duck.displayRot = (Duck.rot - Duck.displayRot) * math.min(40 * dt, 1.0) + Duck.displayRot
    Duck.wasInWater = Duck.isInWater
end

function Duck.draw()
    if(not Duck.isInAir and not Duck.isDiving) then
        --If not in air, use the wave diff between the two springs to determine how the duck should rotate.
        --rot = --getPointAt(Duck.x)
        local pointA = getPointAt(Duck.x)
        local pointB = getPointAt(Duck.x + Duck.dirx * 0.5)
        Duck.rot = math.atan(pointA - pointB, Duck.dirx * 0.5) * 0.8 * Duck.dirx
    --else
        --Duck.rot = 0
    end
    --Crude 1 frame animations -- Though, considering that it is a rubber duck, it probably shouldn't flap its wings
    if(Duck.isDiving) then
        love.graphics.draw(duck, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    elseif(Duck.isFlapping and Duck.isInAir and Duck.vecy > 0) then
        love.graphics.draw(glide, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    else
        love.graphics.draw(img, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    end
    --Draw particles.

end

function Duck.keypressed(key)
    if(key == "left") then
        Duck.dirx = -1
        Duck.isMoving = 1
        Duck.left = -1
    end
    if(key == "right") then
        Duck.dirx = 1
        Duck.isMoving = 1
        Duck.right = 1
    end
    if(key == "down") then
        Duck.isDiving = true
    end
    if(key == "up") then
        Duck.isFlapping = true
    end
end

function Duck.keyreleased(key)
    if(key == "left" or key == "right") then
        Duck[key] = 0
        if(not (Duck.left and Duck.right)) then
            Duck.isMoving = 0
        end
    end
    if(key == "down") then
        Duck.isDiving = false
        if(Duck.isInWater) then
            --Play the jump sound.
            Audio.play("outwater")
        end
    end
    if(key == "up") then
        Duck.isFlapping = false
    end
end

