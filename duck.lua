--- Copyright (C) 2020 Alligrater
--- This piece of software follows the MIT license. See LICENSE for detail.

local g = 160
local img = love.graphics.newImage("img/duck.png")
local duck = love.graphics.newImage("img/duck_duck.png")
local glide = love.graphics.newImage("img/duck_glide.png")
local particleDelay = 0.1
local currentParticleTime = 0

Duck = {}

function Duck.init()
    Duck.x = 32
    Duck.y = 16
    Duck.vecy = 0
    Duck.swimSpeed = 32
    Duck.isInAir = true
    Duck.isInWater = false
    Duck.wasInWater = false --Used for water particle polish -- Overall the performance is pretty ideal?
    Duck.isDiving = false --Whether down key is held
    Duck.isFlapping = false --Whether up key is held
    Duck.startFlap = true --Whether this is the first time the duck uses flap -- Used only for sound effects
    Duck.isMoving = 0
    Duck.dirx = 1 --The direction that the duck, if moving, should move in.
    Duck.rot = 0 --Actual rotation of the duck due to waves
    Duck.displayRot = 0 -- The rotation that the player sees. This is interpolated over time.
    Duck.left = 0 --Whetehr left key is held
    Duck.right = 0 --Right key
end

Duck.init()

function Duck.update(dt)

    -- Vertical Movement
    Duck.y = Duck.y + Duck.vecy * dt
    -- Horizontal movement
    Duck.x = Duck.x + (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed * dt
    Duck.x = math.min(math.max(Duck.x, 4), resx - 4) --Cap position

    --Movement when touching water and not touching water
    local pillar = getWaveHeightAt(Duck.x) -- Once we know the wave height, we can determine whether the duck is in water or in air.
    if(Duck.y + 2 >= pillar) then -- If the player is touching water...
        -- Calculate out how far the duck's bottom is from the top of the water.
        local diff = pillar - Duck.y
        if(not Duck.isDiving) then
            --If the duck is not diving, apply a upward force to the duck. This usually pushes the duck upward
            --and the duck will bounce on water for a few times.
            -- The rest is just playing with these constants and find the best match.
            Duck.vecy = (Duck.vecy + diff * 80 * dt)
            Duck.vecy = Duck.vecy + g * 0.01 * dt
            Duck.vecy = Duck.vecy * 0.993 --Dampen the force a bit so the duck doesn't go off screen.
        else
            Duck.vecy = Duck.vecy + g * dt
        end
        -- Cap the duck's y position so it doesn't dive off screen
        if(Duck.y >= resy - (baseWaterHeight - 15)) then
            Duck.y = resy - (baseWaterHeight - 15)
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

    --Duck move particles. This spawns every particleDelay seconds.
    if(not Duck.isInAir and (Duck.left + Duck.right) ~= 0) then
        if(currentParticleTime > particleDelay) then
            currentParticleTime = 0
            for i = 1,3 do
                local x = (math.random() - 0.5) * 3 + Duck.x
                local y = (math.random() - 0.5) * 3 + Duck.y
                local vx = (math.random() - 0.5) * 8 - (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed / 2
                local vy = -6 + (math.random() - 0.5) * 40
                createParticle(x, y, vx, vy, 3, 0.5) --This particle has much less ttl
            end
        else
            currentParticleTime = currentParticleTime + dt
        end
    end

    -- If the duck jumped out of the water body, then we spawn a few particles that matches the duck's vector.
    if(Duck.wasInWater and not Duck.isInWater) then
        for i = 1,6 do
            local x = (math.random() - 0.5) * 3 + Duck.x
            local y = (math.random() - 0.5) * 3 + Duck.y
            local vx = -(math.random() - 0.5) * 8 + (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed / 2
            local vy = Duck.vecy / 2 + (math.random() - 0.5) * 40
            createParticle(x, y, vx, vy)
        end
        -- Then, we can apply a force to the springs.
        splash(math.floor(Duck.x), Duck.vecy)
    --If the duck jumped back in water, then we also spawn particles, that are against the duck's vector.
    elseif(not Duck.wasInWater and Duck.isInWater) then
        for i = 1,6 do
            local x = (math.random() - 0.5) * 3 + Duck.x
            local y = (math.random() - 0.5) * 3 + Duck.y
            -- Water partcile should move against the player's movement.
            local vx = (math.random() - 0.5) * 8 - (Duck.left + Duck.right) * Duck.isMoving * Duck.swimSpeed / 2
            local vy = -Duck.vecy / 3 + (math.random() - 0.5) * 40
            createParticle(x, y, vx, vy)
        end
        -- Similarly, apply a force to the springs.
        splash(math.floor(Duck.x), Duck.vecy / 3)
    end

    --Interpolate the displayed rotation
    Duck.displayRot = (Duck.rot - Duck.displayRot) * math.min(40 * dt, 1.0) + Duck.displayRot
    Duck.wasInWater = Duck.isInWater
end

function Duck.draw()
    if(not Duck.isInAir and not Duck.isDiving) then
        -- If not in air, we calculate out the slope between duck's x position and 1 pixel to the duck's facing direction.
        local pointA = getWaveHeightAt(Duck.x)
        local pointB = getWaveHeightAt(Duck.x + Duck.dirx * 0.5)
        -- simple geometry -- The value is reduced by a bit such that the sprite doesn't get too distorted.
        Duck.rot = math.atan(pointB - pointA, Duck.dirx * 0.5) * 0.8 * Duck.dirx
    end

    --Crude 1 frame animations -- Though, considering that it is a rubber duck, it probably shouldn't flap its wings
    if(Duck.isDiving) then
        love.graphics.draw(duck, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    elseif(Duck.isFlapping and Duck.isInAir and Duck.vecy > 0) then
        love.graphics.draw(glide, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    else
        love.graphics.draw(img, Duck.x , Duck.y, Duck.displayRot, Duck.dirx, 1, 4, 6)
    end
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

