-- Dependencies
local love = require "love"
local Gamestate = require "libs.gamestate"
local anim8 = require "libs.anim8" -- in case I change my mind and use sprites? I HAVE TO DRAW THEM FIRST
local Tserial = require('libs.TSerial')

-- Some global variables
local debug = false
local window = {
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight()
}
love.graphics.setDefaultFilter("nearest", "nearest") -- haha pixels
local interval
local highscore
local continue = false -- if the user presses continue, this is set to true
local get_continue_exists = function ()
	local continue_data = io.open("snek_data.txt", "r")
	if continue_data ~= nil then
		-- this needs additional tests (it could be a fatal flaw)
		local size = continue_data:seek("end")
		if size < 10 then
			return false
		else
			-- check whether it contains actual data? and not gibberish? (a simple test)
			continue_data:seek("set")
			local test_string = continue_data:read("*a")
			if string.find(test_string, "{") ~= nil then
				if string.find(test_string, "old_x") ~= nil then
					if string.find(test_string, "score") ~= nil then
						return true
					end
				end
			end
			return false
		end
	end
end
local continue_exists = false
local nameLetters = {'A', 'A', 'A'}
-- Data file? (contains options and config (hopefully) and the highscore data)
local data_file

-- Gamestates (using gamestate, but could be implemented with simple strings)
local menu = {}
local menu_selected_item
local menu_items = {"New Game", "Continue", "Leaderboard", "Quit", ""} -- made an empty item to fix something, idk lol
local instruction_items = {"Dismiss", "Don't show this again", ""}
local pause_items = {"Continue", "Save and quit", ""}
local game = {}
local pause = {}
local gameover = {}
local leaderboard = {}
local options = {}
local instructions = {} -- this screen will show only once I hope.
local registerHighScore = {}

-- Loading several assets
local pixelFont = love.graphics.newFont("src/font/press-start/PressStart2P-vaV7.ttf", 32)
local smolPixelFont = love.graphics.newFont("src/font/press-start/PressStart2P-vaV7.ttf", 24)
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
local save_table = {} -- save all data to file?
-- Score and idk... drawing the score incrementally?
local score = 0
local score_increment = 5 -- initially we're incrementing by 5, then increase
local score_from_zero = 0
-- Defining apples
local apple = {}
local size = 32
local test_collision = function (a)
	for i = 1, #Snek.tail, 1 do
		if a.x == Snek.tail[i][1] and a.y == Snek.tail[i][2] then
			return true
		end
	end
	if a.x == Snek.x and a.y == Snek.y then return true end
	return false
end
local createApple = function ()
    math.randomseed(os.time())
	repeat
    	apple.x = math.random(math.floor(window.width / size) - 1)
    	apple.y = math.random(math.floor(window.height / size) - 5) + 2 -- offset from the score bit at the top
	until test_collision(apple) == false
end
local drawApple = function ()
    love.graphics.setColor(0.23, 0.9, 0.12)
    love.graphics.rectangle("fill", apple.x * size, apple.y * size, size, size, 16, 16)
end
-- iterate through the score file and find a matching pattern with a number on the right hand side of the :: operand? (C++ throwbacks oof)
local getScoreTable = function ()
	data_file = io.open("save.txt", "r")
	local scores = {}
	if data_file then
		for line in data_file:lines() do
			local k, v = line:match("^(%S*::)(.*)")
			if(tonumber(v) ~= nil) then
				table.insert(scores, #scores + 1, tonumber(v))
			end
		end
		data_file:close()
	end

	return scores
end
-- duplicate function (TODO: remove? it may need a lot of tweaks)
local getKeyValueScoreTable = function ()
	data_file = io.open("save.txt", "r")
	local scores = {}
	if data_file then
		for line in data_file:lines() do
			local k, v = line:match("^(%S*::)(.*)")
			if k ~= nil then
				k = string.sub(k, 1, #nameLetters)
				if(tonumber(v) ~= nil) then
					if scores[k] == nil then
						scores[k] = v
					else
						-- key already exists
						if scores[k] > v then scores[k] = v end
					end
				end
			end
		end
		data_file:close()
	end

	return scores
end
local getHighScore = function ()
	local scores = getScoreTable()

	local max = 0
	for i = 1, #scores, 1 do
		if scores[i] > max then max = scores[i] end
	end
	return max
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
	highscore = getHighScore()

    love.graphics.setBackgroundColor(0.2, 0.2, 0.24)
    love.keyboard.setTextInput(false)

    -- Create buttons and menu elements:
    love.graphics.setFont(pixelFont)
    MenuCanvas = love.graphics.newCanvas()
    
	-- Check whether we have previously saved data
	continue_exists = get_continue_exists()
	continue = false

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
    -- Nothing here I guess? XD
end

function menu:keypressed(key, isrepeat)
    if key == 'w' or key == 'up' then
        menu_selected_item = menu_selected_item - 1
        -- we're in continue and we don't have data, skip it
		if menu_items[menu_selected_item] == "Continue" and continue_exists == false then
			menu_selected_item = menu_selected_item - 1
		end
        -- wrap to bottom
        if menu_selected_item < 1 then
            menu_selected_item = #menu_items - 1
        end
    elseif key == 's' or key == 'down' then
        menu_selected_item = menu_selected_item + 1
		-- we're in continue and we don't have data, skip it
		if menu_items[menu_selected_item] == "Continue" and continue_exists == false then
			menu_selected_item = menu_selected_item + 1
		end
        -- wrap to top
        if menu_selected_item > #menu_items - 1 then
            menu_selected_item = 1
        end
    elseif key == 'escape' then
        love.event.quit()
    elseif key == 'return' or key == 'kpenter' then
        -- do according to the selected menu item
        if menu_items[menu_selected_item] == "New Game" or menu_items[menu_selected_item] == "Continue" then
            if menu_items[menu_selected_item] == "Continue" then
				continue = true
			end
			Gamestate.switch(instructions)
        end
        if menu_items[menu_selected_item] == "Quit" then
            love.event.quit()
        end
		if menu_items[menu_selected_item] == "Leaderboard" then
			Gamestate.switch(leaderboard)
		end
    end
end

function game:enter(from)
    self.from = from

	if from ~= pause then
		-- reinitialize Snek if we weren't in the pause screen
		Snek.x = 10
		Snek.y = 10
		score = 0
		Snek.length = 0
		Snek.tail = {}
		Snek.dir = 0
	end
	if continue == true then
		-- if the user pressed continue, do this
		local save_file = io.open("snek_data.txt", "r")
		if save_file ~= nil then
			save_table = TSerial.unpack(save_file:read("*a"))
			Snek.x = save_table.x
			Snek.y = save_table.y
			Snek.length = save_table.length
			Snek.tail = save_table.tail
			Snek.dir = save_table.dir
			Snek.old_x = save_table.old_x
			Snek.old_y = save_table.old_y
			apple.x = save_table.apple.x
			apple.y = save_table.apple.y
			score = save_table.score
			save_file:close()
		end
	else
		local save_file = io.open("snek_data.txt", "w+")
		save_file:close()
	end
	love.timer.sleep(1)

    -- grid lock the snake
    interval = 20
    -- this will call drawApple() the first time it loads
	if continue == false then
		createApple()
	end
	-- get highest score stored in data_file
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
	love.graphics.setFont(smolPixelFont)
    love.graphics.print("Score: "..score, 20, 20)
	local textWidth = smolPixelFont:getWidth("High: xxx")
	love.graphics.print("High: "..highscore, window.width - textWidth - 20, 20)
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.line(16, 64, window.width - 16, 64)

	love.graphics.setFont(pixelFont)

    drawApple()
end

function game:update(dt)
    -- Continuously move the snake by intervals
    interval = interval - 1
    if interval < 0 then
        Snek:update(dt)
        if Snek.length > 10 then
            interval = 10
            score_increment = 10
        elseif Snek.length > 20 then
            interval = 8
            score_increment = 20
        elseif Snek.length > 30 then
            interval = 6
            score_increment = 30
        elseif Snek.length > 40 then
            interval = 4
            score_increment = 40
		elseif Snek.length > 60 then
            interval = 2
            score_increment = 50
        else
            interval = 12
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
    elseif Gamestate.current() == pause then
		if key == 'escape' then
			Gamestate.pop(pause)
		elseif key == 'return' or key == 'kpenter' then
			if pause_items[menu_selected_item] == "Continue" then
				Gamestate.pop(pause)
			elseif pause_items[menu_selected_item] == "Save and quit" then
				save_table.x = Snek.x
				save_table.y = Snek.y
				save_table.dir = Snek.dir
				save_table.tail = Snek.tail
				save_table.length = Snek.length
				save_table.old_x = Snek.old_x
				save_table.old_y = Snek.old_y
				save_table.score = score
				save_table.apple = {
					x = apple.x,
					y = apple.y
				}
				local continue_file = io.open("snek_data.txt", "w+")
				continue_file:write(TSerial.pack(save_table))
				continue_file:close()
				Gamestate.switch(menu)
			end
    	end
	end
end

function pause:enter(from)
    self.from = from
	menu_selected_item = 1
end

function pause:draw()
    love.graphics.setColor(0.3, 0.3, 0.36)
    love.graphics.rectangle("fill", 100, 100, window.width - 200, window.height - 200, 5, 5)
    love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("PAUSE")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("PAUSE", window.width / 2, window.height / 2 - 100, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)

	love.graphics.setFont(smolPixelFont)
	for i = 1, #pause_items, 1 do
		textWidth = smolPixelFont:getWidth(pause_items[i])
        textHeight = smolPixelFont:getHeight()

		if i == menu_selected_item then
			love.graphics.setColor(0.93, 0.12, 0.31, 1)
		else
			love.graphics.setColor(1, 1, 1, 1)
		end

		love.graphics.print(pause_items[i], window.width / 2, window.height / 2 + (i - 1) * 50 - 10, 0, 1, 1, textWidth / 2, textHeight / 2)
	end
	-- Set default font again :)
	love.graphics.setFont(pixelFont)
end

function pause:keypressed(key, isrepeat)
	if key == 'up' or key == 'w' then
		menu_selected_item = menu_selected_item - 1
		if menu_selected_item < 1 then
			menu_selected_item = #pause_items - 1
		end
	elseif key == 'down' or key == 's' then
		menu_selected_item = menu_selected_item + 1
		if menu_selected_item >= #pause_items then
			menu_selected_item = 1
		end
	end
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

	-- if the snek collides with any of its tails, it's ded
	for i = 1, #Snek.tail, 1 do
		if Snek.x == Snek.tail[i][1] and Snek.y == Snek.tail[i][2] then
			love.timer.sleep(1)
        	Gamestate.switch(gameover)
		end
	end

    if Snek.x < 0 or Snek.x > math.floor(window.width / size) - 1 or Snek.y < 2 or Snek.y > math.floor(window.height / size) - 1 then
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
	continue = false
	-- flush continue file
	local save_file = io.open("snek_data.txt", "w+")
	save_file:close()

	score_from_zero = 0
	-- recorded the previous state but I did nothing here
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

	love.graphics.setColor(0.23, 0.9, 0.12)
	if score > highscore then
		love.graphics.setFont(smolPixelFont)
    	love.graphics.printf("New high score!", 0, window.height / 2 + 80, window.width, "center")
		love.graphics.setFont(pixelFont)
	end

    -- TODO: set a 3 letter name for the leaderboard and get back to main menu?
	-- Also new highscore message if score > highscore?
end

function gameover:keypressed(key, isrepeat)
	if key == 'return' or key == 'kpenter' then
		if score > highscore then
			Gamestate.switch(registerHighScore)
		else
			Gamestate.switch(menu)
		end
	end
end

-- Register High Score functions
function registerHighScore:enter(from)
	self.from = from
	menu_selected_item = 1
end

function registerHighScore:draw()
	love.graphics.setColor(0.3, 0.3, 0.36)
	love.graphics.setFont(pixelFont)
    love.graphics.rectangle("fill", 50, 100, window.width - 100, window.height - 200, 5, 5)
    love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("NEW HIGH SCORE!")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("NEW HIGH SCORE!", window.width / 2, window.height / 2 - 100, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(smolPixelFont)
    love.graphics.printf("Enter your name using the arrow keys and press Enter", 60, window.height / 2 - 50, window.width - 120, "center")
	love.graphics.setFont(pixelFont)

	textWidth = pixelFont:getWidth("A")
	for i, letter in ipairs(nameLetters) do
		-- these aren't centered?
		if menu_selected_item == i then
			love.graphics.setColor(0.93, 0.12, 0.31, 1)
		else
			love.graphics.setColor(1, 1, 1)
		end

		love.graphics.print(letter, window.width / 2 + (i - 1) * 50, window.height / 2 + 80, 0, 1, 1, (#nameLetters * 20), textHeight / 2)
	end
end

function registerHighScore:keypressed(key, isrepeat)
	
	if key == 'return' or key == 'kpenter' then
		data_file = io.open("save.txt", "a+")
		if data_file then
			-- serialize the table nameLetters
			local str = ""
			for i, letter in ipairs(nameLetters) do
				str = str..letter
			end
			data_file:write(str.."::"..score.."\n")
			data_file:close()
		end
		Gamestate.switch(menu)
	elseif key == 'up' or key == 'w' then
		nameLetters[menu_selected_item] = string.char(nameLetters[menu_selected_item]:byte() - 1)
		if nameLetters[menu_selected_item]:byte() < 65 then nameLetters[menu_selected_item] = string.char(nameLetters[menu_selected_item]:byte() + 26) end
	elseif key == 'down' or key == 's' then
		nameLetters[menu_selected_item] = string.char(nameLetters[menu_selected_item]:byte() + 1)
		if nameLetters[menu_selected_item]:byte() >= 91 then nameLetters[menu_selected_item] = string.char(nameLetters[menu_selected_item]:byte() - 26) end
	elseif key == 'right' or key == 'd' then
		if menu_selected_item >= #nameLetters then menu_selected_item = 0 end
		menu_selected_item = menu_selected_item + 1
	end
end

-- Instructions screen?
function instructions:enter(from)
	self.from = from
	-- we'll always land here lol so we gotta check a file whether or not this has been set to be never shown again?
	-- the data_file descriptor will open a physical save.txt file (read mode)
	data_file = io.open("save.txt", "r")
	if data_file then
		local inst_line = data_file:read("*l")
		local ins, var = inst_line:match("^(%S*=)(.*)")
		if var == "false" then
			Gamestate.switch(game)
		end
		-- WAIT IT'S TRUE OTHERWISE? Always has been :)
	end
end

function instructions:draw()
	love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("Instructions")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("Instructions", window.width / 2, 50, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(smolPixelFont)
    love.graphics.printf("Use the arrow keys or WASD to move Snek around.\nMake sure not to hit the walls!\nThe more fruits you eat, the faster the game will go.", 0, window.height / 2 - 100, window.width, "center")
	
	for i = 1, #instruction_items do
		textWidth = smolPixelFont:getWidth(instruction_items[i])
        textHeight = smolPixelFont:getHeight()
		
        if i == menu_selected_item then
            love.graphics.setColor(0.93, 0.12, 0.31, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
		
        love.graphics.print(instruction_items[i], window.width / 2, window.height / 2 + 120 + (i - 1) *32, 0, 1, 1, textWidth / 2, textHeight / 2)
    end
	-- Set default font again :)
	love.graphics.setFont(pixelFont)
end

function instructions:keypressed(key, isrepeat)
	if key == 'w' or key == 'up' then
        menu_selected_item = menu_selected_item - 1
        
    	-- wrap to bottom
        if menu_selected_item < 1 then
            menu_selected_item = #instruction_items - 1
        end
    elseif key == 's' or key == 'down' then
        menu_selected_item = menu_selected_item + 1

        -- wrap to top
        if menu_selected_item > #instruction_items - 1 then
            menu_selected_item = 1
        end
    elseif key == 'return' or key == 'kpenter' then
        -- do according to the selected menu item (in instruction_items)
        if instruction_items[menu_selected_item] == "Don't show this again" then
			-- get entire data from file
			local lines = {}
            data_file = io.open("save.txt", "r")
			if data_file then
				for line in data_file:lines("*l") do
					table.insert(lines, #lines + 1, line)
				end
				data_file:close()
			end

			-- create a new file with the modified line
			data_file = io.open("save.txt", "w+")
			if data_file then
				data_file:write("show_instructions=false\n")
				-- put the data back in the file
				for i = 2, #lines, 1 do
					data_file:write(lines[i]..'\n')
				end
				data_file:close()
			end
        end
		Gamestate.switch(game)
    end
end

-- Leaderboard?

function leaderboard:enter(from)
	self.from = from
end

function leaderboard:draw()
	local scores = getKeyValueScoreTable()
	local values = {}
	for k, v in pairs(scores) do table.insert(values, v) end
	table.sort(values) -- TODO: Leaderboard isn't sorted?

	love.graphics.setFont(pixelFont)
	love.graphics.setColor(0.93, 0.12, 0.31, 1)
    local textWidth = pixelFont:getWidth("Leaderboard")
    local textHeight = pixelFont:getHeight()
    love.graphics.print("Leaderboard", window.width / 2, 50, 0, 1, 1, textWidth / 2, textHeight / 2)
    love.graphics.setColor(1, 1, 1)

	local iterations = 8
	if #values < 8 then
		iterations = #values
	end

	local printed_keys = {} -- to find duplicate values having the same keys
	local not_printed = function (t, key)
		for i = 1, #t, 1 do
			if t[i] == key then
				return false
			end
		end
		return true
	end

	for i = 1, iterations, 1 do
		-- find the key for the corresponding value and print it
		local c_key = ""
		for key, value in pairs(scores) do
			if values[i] == value and not_printed(printed_keys, key) then
				c_key = key
				break
			end
		end

		local string_value = tostring(values[i])
		while #string_value < 4 do
			string_value = "0"..string_value
		end
		textWidth = pixelFont:getWidth(c_key.."\t"..string_value)
		textHeight = pixelFont:getHeight()
		
		table.insert(printed_keys, c_key)
		love.graphics.print(c_key.."\t"..string_value, window.width / 2, window.height / 2 - 100 + (iterations - i) * 40, 0, 1, 1, textWidth / 2, textHeight / 2)
	end
end

function leaderboard:keypressed(key, isrepeat)
	if key == 'escape' then
		Gamestate.switch(menu)
	end
end