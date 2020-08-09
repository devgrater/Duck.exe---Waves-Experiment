-- The game chose to be a rubber duck simulator --Alligrater


local resx = 64
local resy = 64
local t = 0 --Used for determining wave offset
local baseWaterHeight = 30

-- Screen shake stuff
local shakeLast = 0
local shakeFrq = 0
local currentShakeTime = 0
local shakeMagnitude = 0
local screenOffset = {
    x = 0, y = 0
}

local scaleUp = 8 -- Canvas scale up ratio
springs = {}
local particles = {}

local springConstant = 0.425
local springIteration = 3
local waveSpread = 0.03

function love.load()
    io.stdout:setvbuf("no")
    love.window.setTitle("Duck.exe")
    love.window.setMode(resx * scaleUp, resy * scaleUp)
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")

    require("duck")
    require("audio")

    canvas = love.graphics.newCanvas(resx,resy)

    -- Just following the tutorial (https://gamedevelopment.tutsplus.com/tutorials/make-a-splash-with-dynamic-2d-water-effects--gamedev-236)
    for i = 1, 64 do
        local spring = {offset = 0, vel = 0}
        table.insert(springs, spring)
    end
end

function love.update(dt)
    t = t + dt * 10

    Duck.update(dt)
    --Gotta update the springs!
    for i,v in pairs(springs) do
        updateSpring(v, dt * 10)
    end

    -- Then, propagate?
    propagate()

    --Polish: Water Particles
    for i,v in pairs(particles) do
        if(v.tl > v.ttl) then
            table.remove(particles, i)
        else
            v.vy = v.vy + 160 * dt
            v.y = v.y + v.vy * dt
            -- Apply air friction
            if(v.vx < 0) then v.vx = math.min(v.vx + v.af * dt, 0)
            else v.vx = math.max(v.vx - v.af * dt, 0) end
            --v.vx = v.vx
            v.x = v.x + v.vx * dt
            v.tl = v.tl + dt
        end
    end

    screenShake(dt)
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

        Duck.draw()
        --Draws water body
        love.graphics.setColor(0.2, 0.6, 0.8 + 0.2, 0.85)
        love.graphics.setLineWidth(1)
        for i = 1, 64 do
            local v = getPointAt(i)
            love.graphics.line(i, (64 - v + springs[i].offset), i, 64)
        end

        --Draw water particle, if the particle is above water level.
        for i,v in pairs(particles) do
            local offset = 0
            local index = math.floor(v.x)
            if(index > 1 and index <= 64) then
                offset = springs[index].offset
            end
            if(v.y <= 64 - getPointAt(v.x) + offset) then
                --Draw:
                love.graphics.points(v.x, v.y)
            end
        end

    --Draw out the UI Texts
    love.graphics.setColor(1, 1, 1, 1.0)
    love.graphics.setCanvas()
    love.graphics.draw(canvas,screenOffset.x * scaleUp,screenOffset.y * scaleUp, 0,scaleUp,scaleUp)
end

function love.keypressed(key)
    if(isGameOver and gameOverWait <= 0) then
        initGame()
        firstStart = false
    else
        Duck.keypressed(key)
    end
end

function love.keyreleased(key)
    Duck.keyreleased(key)
end

-- Formula for calculating water waves.
function getPointAt(point)
    return math.sin(((point + t * 1.5) / 6)) * -3 + baseWaterHeight
end

function scheduleScreenShake(last, frequency, amplitude )
    shakeLast = last
    shakeMagnitude = amplitude
    shakeFrq = frequency
end

function screenShake(dt)
    if(shakeLast <= 0) then screenOffset = {x = 0, y = 0} return end
    shakeLast = shakeLast - dt
    currentShakeTime = currentShakeTime + dt
    if(currentShakeTime >= shakeFrq) then
        currentShakeTime = 0
        --Update the screen
        local shakeX = math.random(-shakeMagnitude, shakeMagnitude)
        while(shakeX == 0) do
            shakeX = math.random(-shakeMagnitude, shakeMagnitude)
        end
        local shakeY = math.random(-shakeMagnitude, shakeMagnitude)
        while(shakeY == 0) do
            shakeY = math.random(-shakeMagnitude, shakeMagnitude)
        end
        screenOffset.x = shakeX
        screenOffset.y = shakeY
    end
end

function createParticle(x, y, vx, vy, airfriction, ttl)
    --DuckParticles
    ttl = ttl or 1.5
    airfriction = airfriction or 3
    --                                                                  Time to live    Time lived
    local particle = {x = x, y = y, vx = vx, vy = vy, af = airfriction, ttl = ttl,      tl = 0}
    table.insert(particles, particle)
end

function updateSpring(spring, dt)
    local acclr = spring.offset * -springConstant
    spring.offset = spring.offset + spring.vel * dt
    spring.vel = (spring.vel + acclr * dt) * 0.999 -- This constant here, will make the spring stop gradually, simulating the mechanical energy loss
end
-- this is also just following the tutorial.
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