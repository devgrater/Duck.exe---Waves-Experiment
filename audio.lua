--- Copyright (C) 2020 Alligrater
--- This piece of software follows the MIT license. See LICENSE for detail.

Audio = {
    hurt = love.audio.newSource("se/duck_hurt.wav", "static"),
    outwater = love.audio.newSource("se/duck_outwater.wav", "static"),
    flap = love.audio.newSource("se/duck_flap.wav", "static"),
}

function Audio.play(name)
    Audio[name]:play()
end