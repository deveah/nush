
--
--	ui.lua
--	functions related to UI
--	
--	The UI object has the following members:
--	*	width and height (integers) - size of the terminal window
--	* messageList (table) - a list of in-game messages
--

--	The singleton UI object
local UI = {}
--	This allows recursively requiring ui.lua
package.loaded['lua/ui'] = UI

local Global = require 'lua/global'
local Log = require "lua/log"
local Game = require "lua/game"

--	UI.init() - initialises a new UI object, and also initializes the curses
--	interface; returns nothing
function UI:init()
	self.width, self.height = curses.init()
	self.messageList = {}
	Log:write("Initialized curses interface.")
	Log:write("Screen w/h: " .. Global.screenWidth .. "x" .. Global.screenHeight)
end

--	UI:terminate() - terminates the interface object; does not return anything
function UI:terminate()
	curses.terminate()
	Log:write("Terminated curses interface.")
end

--	UI.drawScreen() - draws the main screen, which includes the map, HUD, and
--	message bars; does not return anything
function UI:drawScreen()
	--	the offsets from array indices to screen coordinates
	local xOffset, yOffset = -1, 2

	--	the map that we want to draw is the map the player-controlled character
	--	is currently on
	local map = Game.player.map

	--	draw the terrain
	for i = 1, Global.mapWidth do
		for j = 1, Global.mapHeight do
			--	draw only tiles visible by the player, or in the player's memory
			if Game.player.sightMap[i][j] then
				curses.attr(map.tile[i][j].color)
				curses.write(i + xOffset, j + yOffset, map.tile[i][j].face)
			elseif map.memory[i][j] ~= " " then
				curses.attr(curses.white)
				curses.write(i + xOffset, j + yOffset, map.memory[i][j])
			else
				curses.attr(curses.black)
				curses.write(i + xOffset, j + yOffset, " ")
			end
		end
	end

	--	draw the items on the same map as the player, who are visible from the
	--	player character's point of view
	for i = 1, #(Game.itemList) do
		if	Game.itemList[i].map == map
				and Game.player.sightMap[Game.itemList[i].x][Game.itemList[i].y] then
			curses.attr(Game.itemList[i].color)
			curses.write(Game.itemList[i].x + xOffset, Game.itemList[i].y + yOffset,
				Game.itemList[i].face)
		end
	end

	--	draw the actors on the same map as the player, who are visible from
	--	the player character's point of view; only actors who are alive
	--	can be seen
	for i = 1, #(Game.actorList) do
		if	Game.actorList[i].map == map
				and Game.player.sightMap[Game.actorList[i].x][Game.actorList[i].y]
				and Game.actorList[i].alive then
			curses.attr(Game.actorList[i].color)
			curses.write(Game.actorList[i].x + xOffset, Game.actorList[i].y + yOffset,
				Game.actorList[i].face)
		end
	end

	--	set the default color back
	curses.attr(curses.white)

	--	clear the message lines
	for i = 0, 2 do
		curses.clearLine(i)
	end

	--	draw the most recent 3 messages (if any)
	local offset = 0
	for i = #(self.messageList) - 2, #(self.messageList) do
		if i > 0 then
			self:colorWrite(0, offset, self:getMessage(i))
			offset = offset + 1
		end
	end

	--	draw the status line
	curses.clearLine(23)
	curses.write(0, 23, "Placeholder status line.")

	--	position the cursor on the player, so it may be easily seen
	curses.move(Game.player.x + xOffset, Game.player.y + yOffset)
end

--	UI:prompt() - prompts the player with a ok/cancel question, returning
--	true if the player has responded "ok", and false for every other reason
function UI:prompt(reason)
	--	show the user the reason for prompting
	self:message(reason .. " (ok/cancel)")

	--	update the screen so the prompt is visible
	self:drawScreen()

	--	read user input and act accordingly
	local k = curses.getch()
	if k == "o" then
		return true
	else
		--	show the user that the action has been cancelled
		self:message("Okay, then.")
		return false
	end
end

--	UI:directionFromKey() - given a key or keycode from curses.getch(), returns
--	nil if not recognised as a direction, or a sequence {x, y}, -1 <= x,y <= 1,
--	including possibly {0, 0}.
function UI:directionFromKey(key)
	if key == "h" or key == "left" then
		return {-1, 0}
	elseif key == "j" or key == "down" then
		return {0, 1}
	elseif key == "k" or key == "up" then
		return {0, -1}
	elseif key == "l" or key == "right" then
		return {1, 0}
	elseif key == "y" or key == "upleft" or key == "home" then
		return {-1, -1}
	elseif key == "u" or key == "upright" or key == "pageup" then
		return {1, -1}
	elseif key == "b" or key == "downleft" or key == "end" then
		return {-1, 1}
	elseif key == "n" or key == "downright" or key == "pagedown" then
		return {1, 1}
	elseif key == "." or key == "numpad5" then
		return {0, 0}
	else
		return nil
	end
end

--	UI:promptDirection() - prompts the player to enter a direction; returns
--	nil if invalid, or a sequence {x, y}, -1 <= x,y <= 1,	including possibly
--	{0, 0}.
function UI:promptDirection()
	self:message("Which direction?")
	self:drawScreen()

	local key = curses.getch()
	local dir = self:directionFromKey(key)
	if not dir then
		self:message("'" .. key .. "' isn't a valid direction.")
	end
	return dir
end

--	UI:message() - pushes a message onto the message list, so the player
--	may see it in-game; handles repeating messages by counting the times
--	a message was logged; does not return anything
function UI:message(text)
	Log:write("Message logged: " .. text)
	--	if there are no messages, there's no purpose in testing for repeats
	if #self.messageList == 0 then
		table.insert(self.messageList, {text = text, times = 1})
		return
	end

	--	last message shown, used to compare with current message
	local lastmsg = self.messageList[#self.messageList]
	if lastmsg.text == text then
		lastmsg.times = lastmsg.times + 1
	else
		table.insert(self.messageList, {text = text, times = 1})
	end
end

--	UI:getMessage() - returns the message at a given index, mentioning the
--	times the message has been repeated
function UI:getMessage(index)
	local msg = self.messageList[index]
	if msg.times == 1 then
		return msg.text
	else
		return msg.text .. " (x" .. msg.times .. ")"
	end
end

--  writeCentered() - Draws a string at the center of a line; does not return anything
function UI:writeCentered(y, str)
	curses.write((Global.screenWidth - #str - 1) / 2, y, " " .. str .. " ")
end

--  UI:messageLogScreen() - display message log with interactive scrolling;
--  does not return anything
function UI:messageLogScreen()
	--  number of message that can be shown at once
	local windowHeight = Global.screenHeight - 2
	--  maximum 'scroll' value (fully scrolled to end)
	local maxScroll = math.max(1, #(self.messageList) - (windowHeight - 1))
	--  index of scroll-back buffer at top of window
	local scroll = maxScroll

	local function drawMessageLog()
		for i = 0, windowHeight - 1 do
			curses.clearLine(1 + i)
			local messageLine = i + scroll
			if messageLine >= 1 and messageLine <= #(self.messageList) then
				self:colorWrite(0, 1 + i, self:getMessage(messageLine))
			end
		end

		--  draw the window decoration
		local banner = string.rep("-", Global.screenWidth)
		curses.write(0, 0, banner)
		self:writeCentered(0, "Previous messages")
		curses.write(0, Global.screenHeight - 1, banner)
		self:colorWrite(1, Global.screenHeight - 1, " {{cyan}}jk {{white}}navigate {{cyan}}other {{white}}exit ")
		if scroll > 1 then
			curses.write(Global.screenWidth - 5, 0, " ^ ")
		end
		if scroll < maxScroll then
			curses.write(Global.screenWidth - 5, Global.screenHeight - 1, " v ")
		end
	end

	--	hide the cursor while showing the message log screen
	curses.cursor(0)

	while true do
		drawMessageLog()
		key = curses.getch()
		if key == "j" or key == "down" then
			scroll = math.min(scroll + 1, maxScroll)
		elseif key == "k" or key == "up" then
			scroll = math.max(scroll - 1, 1)
		else
			break
		end
	end

	--	restore the state of the cursor
	curses.cursor(1)
end

--	UI:colorWrite() - draws a string of text at a given position on-screen,
--	allowing the use of in-text color changing by parsing color codes like {{cyan}}
--	Does not return anything.
function UI:colorWrite(x, y, text)
	local currentX = x

	local function write(str)
		curses.write(currentX, y, str)
		currentX = currentX + str:len()
	end

	--	Break text into pieces delimited by color tokens
	local pos = 1
	while pos <= #text do
		local startpos, word, nextpos = text:match("(){{(%a+)}}()", pos)

		--	Print the last piece of the text
		if startpos == nil then
			write(text:sub(pos))
			break
		end

		--	Print anything we jumped over
		if startpos > pos then
			write(text:sub(pos, startpos - 1))
		end

		if		 word == "white" then		curses.attr(curses.white)
		elseif word == "red" then			curses.attr(curses.red)
		elseif word == "green" then		curses.attr(curses.green)
		elseif word == "blue" then		curses.attr(curses.blue)
		elseif word == "yellow" then	curses.attr(curses.yellow)
		elseif word == "magenta" then	curses.attr(curses.magenta)
		elseif word == "cyan" then		curses.attr(curses.cyan)
		else
			write(text:sub(startpos, nextpos))
		end

		pos = nextpos
	end

	--	reset to default color
	curses.attr(curses.white)
end

--	UI:drawTitleScreen() - draws the title screen, asking the player for a
--	character name; returns the name given by the player, or a default name
--	taken from the Global table
function UI:drawTitleScreen()
	local logo = 
	{	".--. .  . .--. .  .",
		"|  | |  | '--. |--|",
		"'  ' '--' '--' '  '" }

	curses.clear()
	curses.cursor(0)

	--	draw the logo
	curses.attr(curses.cyan + curses.bold)
	curses.write(10, 3, logo[1])
	curses.write(10, 4, logo[2])
	curses.write(10, 5, logo[3])
	curses.attr(curses.cyan)
	curses.write(10, 6, "A coffeebreak roguelike")
	curses.attr(curses.white)
	curses.write(10, 7, "http://github.com/deveah/nush")

	--	ask the player for a name
	curses.write(10, 10, "Please type a name (default is '" .. Global.defaultName .. "'):")
	curses.cursor(1)
	curses.move(10, 11)
	local name = curses.getstr()
	curses.cursor(0)

	if name == "" then
		return Global.defaultName
	else
		return name
	end
end

--	UI:drawInventoryScreen() - draws a screen showing the contents of a given actor's
--	inventory; does not return anything
function UI:drawInventoryScreen(actor)
	local currentLine = 1

	curses.clear()

	local banner = string.rep("-", Global.screenWidth)
	curses.write(0, 0, banner)
	self:writeCentered(0, "Inventory")
	curses.write(0, Global.screenHeight - 1, banner)
	self:colorWrite(1, Global.screenHeight - 1, " {{cyan}}any key {{white}}exit ")


	--	a-z
	for i = 0, 25 do
		local char = string.char(97 + i)
		if actor.inventory[char] then
			self:colorWrite(1, currentLine, "{{yellow}}" .. char .. "{{white}} - " .. actor.inventory[char].name)
			currentLine = currentLine + 1
		end
	end

	--	A-Z
	for i = 0, 25 do
		local char = string.char(65 + i)
		if actor.inventory[char] then
			self:colorWrite(1, currentLine, "{{yellow}}" .. char .. "{{white}} - " .. actor.inventory[char].name)
			currentLine = currentLine + 1
		end
	end

	curses.getch()
end

return UI

