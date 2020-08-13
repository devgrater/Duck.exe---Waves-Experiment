--- Copyright (C) 2020 Alligrater
--- This piece of software follows the MIT license. See LICENSE for detail.

-- The game chose to be a rubber duck simulator --Alligrater
-- A bit of basic settings. These allow using canvas of any size and create good water bodies.
resx = 64
resy = 64
t = 0 --Used for determining wave offset
baseWaterHeight = 24
scaleUp = 5 -- Canvas scale up ratio

local springs = {}
local particles = {}
local canvas

--- Make a Splash With Dynamic 2D Water Effects (Michael Hoffman)
--- https://gamedevelopment.tutsplus.com/tutorials/make-a-splash-with-dynamic-2d-water-effects--gamedev-236
local springConstant = 0.325
local springIteration = 1 --This iteration count is massively reduced.
local waveSpread = 0.1

function love.load()
    io.stdout:setvbuf("no")
    love.window.setTitle("Duck.exe - Extra Side Project")
    love.window.setMode(resx * scaleUp, resy * scaleUp)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")

    require("duck")
    require("audio")

    canvas = love.graphics.newCanvas(resx,resy)

    --Populate the water springs.
    for i = 1, resx do
        local spring = {offset = 0, vel = 0}
        table.insert(springs, spring)
    end
    --profiler.start()
end

function love.update(dt)
    --This timer is used for determining the sine wave offset.
    if(dt > 0.03) then return end --30fps

    t = t + dt * 10

    Duck.update(dt)

    -- Wave physics. Not originally included in the base game but i feel like as a side project it's cool to have.
    for i,v in pairs(springs) do
        updateSpring(v, dt * 10)
    end
    propagate()

    --Polish: Water Particles
    for i,v in pairs(particles) do
        -- If the particle has lived longer than the designated time to live, destroy the particle.
        if(v.tl > v.ttl) then
            table.remove(particles, i)
        else
            -- Apply gravity and then displace particle
            v.vy = v.vy + 160 * dt
            v.y = v.y + v.vy * dt
            -- Apply air friction, and displace particle.
            if(v.vx < 0) then v.vx = math.min(v.vx + v.af * dt, 0)
            else v.vx = math.max(v.vx - v.af * dt, 0) end
            v.x = v.x + v.vx * dt
            -- Update the particles' "time lived" value.
            v.tl = v.tl + dt
        end
    end
end


function love.draw()
    --Originally created for LOWREZJAM2020, so I had to use canvas to scale up things.
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

        Duck.draw()

        --Draws water body
        love.graphics.setColor(0.2, 0.6, 1.0, 0.85)
        love.graphics.setLineWidth(1)
        for i = 1, resx do
            -- Take the base sine wave (getWaveHeightAt()), and combine it with the spring offset.
            local v = getWaveHeightAt(i)
            love.graphics.line(i, (v + springs[i].offset), i, resy)
        end

        --Draw water particle, if the particle is above water level.
        -- Thanks to the canvas being smol, I can just use points to mimic metaballs.
        for i,v in pairs(particles) do
            local offset = 0 --This gets me the offset of the springs.
            local index = math.floor(v.x)
            --Gonna quickly check if the coordinate of this is within the bounds.
            --If not, don't even bother drawing the particles.
            if(index >= 1 and index <= resx) then
                offset = springs[index].offset
                if(v.y < getWaveHeightAt(v.x) + offset) then
                    love.graphics.points(v.x, v.y)
                end
            end
        end

    love.graphics.setColor(1, 1, 1, 1.0)
    love.graphics.setCanvas()
    love.graphics.draw(canvas,0,0, 0,scaleUp,scaleUp)
    --love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)
end

function love.keypressed(key)
    Duck.keypressed(key)
    if(key == "space") then
        --profiler.stop()
        --print(profiler.report(20))
    end
end

function love.keyreleased(key)
    Duck.keyreleased(key)
end

-- Formula for calculating water waves.

function getWaveHeightAt(point)
    --Wouldn't work if we try to implement a gerstner wave...
    --But! I have a solution that looks nice!
    --\sin\left(0.3x\right)-3\ \cdot\operatorname{abs}\left(\cos\left(0.3x+t\right)\ \right) -> try pasting this in desmos.com/calculator, and drag the t value.
    -- It's not exactly a gerstner wave, but looks close enough... Maybe even looks better!
    local wave = 2 + math.sin(0.1 * point) - 3 * math.abs(math.cos(0.1 * point + t * 0.3))
    return resy - (wave * 1.5 + baseWaterHeight)

    --return resy - (xpos + baseWaterHeight)

    --return resy - (math.sin(((point + t * 1.5) / 6)) * 4  + baseWaterHeight)
    --return resy - (math.sin(((point + t * 1.5) / 8)) * -1 + baseWaterHeight + math.sin(((point + t * 3) / 4)) * -1)
    --return resy - baseWaterHeight
end

function createParticle(x, y, vx, vy, airfriction, ttl)
    --DuckParticles
    ttl = ttl or 1.5
    airfriction = airfriction or 3
    --                                                                  Time to live    Time lived
    local particle = {x = x, y = y, vx = vx, vy = vy, af = airfriction, ttl = ttl,      tl = 0}
    table.insert(particles, particle)
end

--- Codes below this section are copied and modified from an existing tutorial. See detail below:
--- Make a Splash With Dynamic 2D Water Effects (Michael Hoffman)
--- https://gamedevelopment.tutsplus.com/tutorials/make-a-splash-with-dynamic-2d-water-effects--gamedev-236

-- Following the water tutorial.
-- Though, we only used offset instead of height, because we only need to combine the offset with the waves.
function updateSpring(spring, dt)
    local acclr = spring.offset * -springConstant
    spring.offset = spring.offset + spring.vel * dt
    spring.vel = spring.vel * 0.996 + acclr * dt
    --                        This constant here, will make the spring stop gradually
end

function propagate()
    --for each springs...
    local lDeltas = {}
    local rDeltas = {}
    for j = 1, springIteration do
        for i,v in pairs(springs) do
            if(i > 1) then
                lDeltas[i] = waveSpread * (v.offset - springs[i-1].offset)
                springs[i-1].vel = springs[i-1].vel + lDeltas[i]
            end
            if(i < #springs) then
                rDeltas[i] = waveSpread * (v.offset - springs[i+1].offset)
                springs[i+1].vel = springs[i+1].vel + rDeltas[i]
            end
        end
        for i,v in pairs(springs) do
            if(i > 1) then
                springs[i-1].offset = springs[i-1].offset + lDeltas[i]
            end
            if(i < #springs) then
                springs[i+1].offset = springs[i+1].offset + rDeltas[i]
            end
        end
    end
end

function splash(index, vel)
    springs[index].vel = vel
end