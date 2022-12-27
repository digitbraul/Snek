-- Dependencies
local love = require "love"
local Gamestate = require "libs.gamestate"
local anim8 = require "libs.anim8"

-- Some global variables
local debug = false
local window = {
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight()
}
love.graphics.setDefaultFilter("nearest", "nearest")
local interval

-- Gamestates (using gamestate, but could be implemented with simple strings)
local menu = {}
local menu_selected_item
local menu_items = {"New Game", "Options", "Leaderboard", "Quit", ""} -- made an empty item to fix something, idk lol
local game = {}
local pause = {}
local gameover = {}
local leaderboard = {}
local options = {}

-- Loading several assets
local pixelFont = love.graphics.newFont("src/font/press-start/PressStart2P-vaV7.ttf", 32)
local sprite_path = "src/sprites/snek.png"

-- Defining the player object (Snake)
local Snek = {
    x = 10,
    y = 10, -- these will be randomized later on
    dir = 0, -- 0 for up, 1 for left, 2 for right and 3 for down
    dx = 0,
    dy = 0,
    speed = 10, -- this will increase whenever the Snek eats an apple :)
    size = 32,
    length = 0,
    tail = {},
    old_x = 0,
    old_y = 0
}
-- Score and idk... drawing the score incrementally?
local score = 0
local score_increment = 5 -- initially we're incrementing by 5, then increase
local score_from_zero = 0
-- Defining apples
local apple = {}
local size = 32
local createApple = function ()
    math.randomseed(os.time())
    apple.x = math.random(19)
    apple.y = math.random(10) + 2
end
local drawApple = function ()
    love.graphics.setColor(0.23, 0.9, 0.12)
    love.graphics.rectangle("fill", apple.x * size, apple.y * size, size, size, 16, 16)
end

-- Global LOAD function, only called once when the game loads
function love.load(args)
    -- Using --debug arg to print commands
	for k, v in ipairs(args) do
		if v == "--debug" then
			debug = true
		else
			print('Launching with debug disabled...')
		end
	end

    -- Switch to menu gamestate upon launch
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end

-- Defining menu gamestate entry
function menu:enter(from)
    self.from = from

    love.graphics.setBackgroundColor(0.2, 0.2, 0.24)
    love.keyboard.setTextInput(false)

    -- Create buttons and menu elements:
    love.graphics.setFont(pixelFont)
    MenuCanvas = love.graphics.newCanvas()
    
    -- set default option to "New Game"
    menu_selected_item = 1
end

function menu:draw()
    love.graphics.setCanvas(MenuCanvas)
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.line(50, window.height / 2 - 50, window.width - 50, window.height / 2 - 50)

    for i = 1, #menu_items do
        local textWidth = pixelFont:getWidth(menu_items[i])
        local textHeight = pixelFont:getHeight()

        if i == menu_selected_item then
            -- if a menu item is selected, draw it in RED
            love.graphics.setColor(0.93, 0.12, 0.31, 1)
        else
            -- other menu items are white
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Draw menu texts
        love.graphics.print(menu_items[i], window.width / 2, window.height / 2 + (i - 1) *50, 0, 1, 1, textWidth / 2, textHeight / 2)
    end

    -- Drawing the menu canvas
    love.graphics.setCanvas()
    love.graphics.draw(MenuCanvas, 0, 0)
end

function menu:update(dt)
    -- Nothing here I guess?
end

function menu:keypressed(key, isrepeat)
    if key == 'w' or key == 'up' then
        menu_selected_item = menu_selected_item - 1
        
        -- wrap to bottom
        if menu_selected_item < 1 then
            menu_selected_item = #menu_items - 1
        end
    elseif key == 's' or key == 'down' then
        menu_selected_item = menu_selected_item + 1

        -- wrap to top
        if menu_selected_item > #menu_items - 1 then
            menu_selected_item = 1
        end
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'return' or key == 'kpenter' then
        -- do according to the selected menu item
        if menu_items[menu_selected_item] == "New Game" then
            Gamestate.switch(game)
        end
        if menu_items[menu_selected_item] == "Quit" then
            love.event.quit()
        end
    end
end

function game:enter(from)
    self.from = from

    -- grid lock the snake
    interval = 20
    -- this will call drawApple() the first time it loads
    createApple()
end

function game:draw()
    -- Rectangle for a snake? at least for now
    love.graphics.setColor(0.93, 0.12, 0.31, 1)
    love.graphics.rectangle("fill", Snek.x * Snek.size, Snek.y * Snek.size, Snek.size, Snek.size, 8, 8)

    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for i = 1, #Snek.tail, 1 do
        love.graphics.rectangle("fill", Snek.tail[i][1] * Snek.size, Snek.tail[i][2] * Snek.size, Snek.size, Snek.size, 16, 16)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Score: "..score, 16, 16)
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.line(16, 64, window.width - 16, 64)

    drawApple()
end

function game:update(dt)
    -- Continuously move the snake by intervals
    interval = interval - 1
    if interval < 0 then
        Snek:update(dt)
        if Snek.length > 10 then
            interval = 15
            score_increment = 10
        elseif Snek.length > 20 then
            interval = 10
            score_increment = 20
        elseif Snek.length > 30 then
            interval = 5
            score_increment = 30
        elseif Snek.length > 40 then
            interval = 1
            score_increment = 40
        else
            interval = 20
        end
    end
end

function game:keypressed(key, isrepeat)
	-- the snek shouldn't go directly opposite to the direction it's going
    if (key == 'w' or key == 'up') and Snek.dir ~= 1 then
        Snek.dir = 0
    elseif (key == 's' or key == 'down') and Snek.dir ~= 0 then
        Snek.dir = 1
    elseif (key == 'd' or key == 'right') and Snek.dir ~= 3 then
        Snek.dir = 2
    elseif (key == 'a' or key == 'left') and Snek.dir ~= 2 then
        Snek.dir = 3
    end
end

function love.keypressed(key, isrepeat)
    if Gamestate.current() == game and key == 'escape' then
        Gamestate.push(pause)
    elseif Gamestate.current() == pause and (key == 'escape' or key == 'return' or key == 'kpenter') then
        Gamestate.pop(pause)
    end
end

function pause:enter(from)
    self.from = from
end

function pause:draw()
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.rectangle("fill", 100, 100, window.width - 200, window.height - 200, 5, 5)
    love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("PAUSE")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("PAUSE", window.width / 2, window.height / 2, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)
end

function Snek:update(dt)
    if Snek.dir == 0 then
        Snek.dx, Snek.dy = 0, -1
    elseif Snek.dir == 1 then
        Snek.dx, Snek.dy = 0, 1
    elseif Snek.dir == 2 then
        Snek.dx, Snek.dy = 1, 0
    elseif Snek.dir == 3 then
        Snek.dx, Snek.dy = -1, 0
    end

    Snek.old_x, Snek.old_y = Snek.x, Snek.y

    Snek.x = Snek.x + Snek.dx
    Snek.y = Snek.y + Snek.dy

    if Snek.x == apple.x and Snek.y == apple.y then
        createApple()
        drawApple()
        Snek.length = Snek.length + 1
        score = score + score_increment
        table.insert(Snek.tail, {0, 0})
    end

	-- also collision detection?
	for i = 1, #Snek.tail, 1 do
		if Snek.x == Snek.tail[i][1] and Snek.y == Snek.tail[i][2] then
			love.timer.sleep(1)
        	Gamestate.switch(gameover)
		end
	end

    -- idk what 19 or 14 are but make sure not to change the screen resolution :))))
    if Snek.x < 0 or Snek.x > 19 or Snek.y < 2 or Snek.y > 14 then
        love.timer.sleep(1) -- for the dramatic effect (also the sound to play?)
        Gamestate.switch(gameover)
    end

    if Snek.length > 0 then
        for i = 1, #Snek.tail, 1 do
            local x, y = Snek.tail[i][1], Snek.tail[i][2]
            Snek.tail[i][1], Snek.tail[i][2] = Snek.old_x, Snek.old_y
            Snek.old_x, Snek.old_y = x, y
        end
    end
end

-- Gameover State
function gameover:enter(from)
    self.from = from
end

function gameover:draw()
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.rectangle("fill", 100, 100, window.width - 200, window.height - 200, 5, 5)
    love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("GAME OVER!")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("GAME OVER!", window.width / 2, window.height / 2 - 100, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Score", 0, window.height / 2 - 50, window.width, "center")
    -- idk just thought it'd be cool to draw score this way? oof nvm
    love.graphics.printf(tostring(score_from_zero), 0, window.height / 2, window.width, "center")
    if score_from_zero < score then
        score_from_zero = score_from_zero + 1
    end

    -- TODO: a way to set a 3 letter name for the leaderboard?
end
