Audio = {
    eat = love.audio.newSource("duck_eat.wav", "static"),
    hurt = love.audio.newSource("duck_hurt.wav", "static"),
    outwater = love.audio.newSource("duck_outwater.wav", "static"),
    flap = love.audio.newSource("duck_flap.wav", "static"),
}

function Audio.play(name)
    Audio[name]:play()
end