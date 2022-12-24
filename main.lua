-- Dependencies
local love = require "love"
local Gamestate = require('libs.gamestate')

-- Some global variables
local debug = false
local window = {
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight()
}
love.graphics.setDefaultFilter("nearest", "nearest")
local seed = math.randomseed(os.time())

-- Gamestate menu and game states?
local menu = {}
local menu_selected_item
local menu_items = {"New Game", "Options", "Leaderboard", "Quit", ""} -- made an empty item to fix something, idk lol
local game = {}

-- Loading several assets
local pixelFont = love.graphics.newFont("src/font/press-start/PressStart2P-vaV7.ttf", 32)

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
    
end

function menu:keypressed(key, isrepeat)
    if key == 'w' then
        menu_selected_item = menu_selected_item - 1
        
        -- wrap to bottom
        if menu_selected_item < 1 then
            menu_selected_item = #menu_items - 1
        end
    elseif key == 's' then
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
    end
end

function game:enter(from)
    self.from = from

    if debug then print("we're in the game state :)") end
end

