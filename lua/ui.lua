
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
local Util = require 'lua/util'
local Log = require "lua/log"
local Game = require "lua/game"

--	UI.init() - initialises a new UI object, and also initializes the curses
--	interface; returns nothing
function UI:init()
	self.width, self.height = curses.init()
	self.messageList = {}
	Log:write("Initialized curses interface. curses.utf8=" .. tostring(curses.utf8))
	Log:write("Curses w/h: " .. self.width .. "x" .. self.height)
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

	--	draw the terrain and memory
	for i = 1, Global.mapWidth do
		for j = 1, Global.mapHeight do
			--	draw only tiles visible by the player, or tiles and items in the player's memory
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
	--	(Note: Actor:updateSight() also draws items onto map.memory)
	for i = 1, #(Game.itemList) do
		local item = Game.itemList[i]
		if item.map == map and Game.player.sightMap[item.x][item.y] then
			curses.attr(item.color)
			curses.write(item.x + xOffset, item.y + yOffset, item.face)
		end
	end

	--	draw the actors on the same map as the player; skipping over dead actors
	--	who haven't been deleted yet.
	for i = 1, #(Game.actorList) do
		local actor = Game.actorList[i]
		if actor.map == map and actor.alive then
			actor:draw(xOffset, yOffset)
		end
	end

	--	draw the particles above everything else.
	for i = 1, #(Game.particleList) do
		local particle = Game.particleList[i]
		if particle.map == map then
			particle:draw(xOffset, yOffset)
		end
	end

	--	set the default color back
	curses.attr(curses[Global.defaultColor])

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
	curses.write(Global.screenWidth - Game.player.map.name:len(), 23, Game.player.map.name)

	--	position the cursor on the player, so it may be easily seen
	curses.move(Game.player.x + xOffset, Game.player.y + yOffset)
end

--	UI:prompt() - prompts the player with a ok/cancel question, returning
--	true if the player has responded "ok", and false for every other reason
function UI:prompt(reason)
	--	show the user the reason for prompting
	self:message(reason .. " ({{WHITE}}o{{pop}}k/{{WHITE}}c{{pop}}ancel)")

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
--	dir, x, y, where dir is a code like "l" or "dl" or ".", and -1 <= x,y <= 1,
--	including possibly ".", 0, 0 for "self", or returns nil for invalid.
function UI:directionFromKey(key)
	if key == "h" or key == "left" then
		return "l", -1, 0
	elseif key == "j" or key == "down" then
		return "d", 0, 1
	elseif key == "k" or key == "up" then
		return "u", 0, -1
	elseif key == "l" or key == "right" then
		return "r", 1, 0
	elseif key == "y" or key == "upleft" or key == "home" then
		return "ul", -1, -1
	elseif key == "u" or key == "upright" or key == "pageup" then
		return "ur", 1, -1
	elseif key == "b" or key == "downleft" or key == "end" then
		return "dl", -1, 1
	elseif key == "n" or key == "downright" or key == "pagedown" then
		return "dr", 1, 1
	elseif key == "." or key == "delete" or key == "numpad5" then
		return ".", 0, 0
	else
		return nil
	end
end

--	UI:promptDirection() - prompts the player to enter a direction; returns
--	nil if invalid, or dir,x,y; see UI:directionFromKey().
--	The prompt is invisible if reason isn't given
function UI:promptDirection(reason)
	if reason then
		self:message(reason)
	end
	self:drawScreen()

	local key = curses.getch()
	local dir, dirx, diry = self:directionFromKey(key)
	if not dir then
		self:message("'" .. key .. "' isn't a valid direction.")
	end
	return dir, dirx, diry
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

--	UI:deleteMessage() - delete the last n messages, defaulting to 1.
--	Returns nothing.
function UI:deleteMessage(n)
	n = n or 1
	for i = 1, n do
		--	Delete one repetition of the last message
		local lastmsg = self.messageList[#self.messageList]
		lastmsg.times = lastmsg.times - 1
		if lastmsg.times <= 0 then
			table.remove(self.messageList)
		end
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
	self:colorWrite((Global.screenWidth - #self:removeMarkup(str) - 2) / 2, y, " " .. str .. " ")
end

--  UI:scrollableTextScreen() - display text with	interactive scrolling; does
--	not return anything.
--	title:  Text shown at top of screen
--	text:   A list of lines
--	toEnd:  If true, start scrolled to end rather than beginning
function UI:scrollableTextScreen(title, text, toEnd)
	--  number of lines that can be shown at once
	local windowHeight = Global.screenHeight - 2
	--  maximum 'scroll' value (fully scrolled to end)
	local maxScroll = math.max(1, #text - (windowHeight - 1))
	--  index of scroll-back buffer at top of window
	local scroll = 1
	if toEnd then scroll = maxScroll end

	local function drawMessages()
		for i = 0, windowHeight - 1 do
			curses.clearLine(1 + i)
			local messageLine = i + scroll
			if messageLine >= 1 and messageLine <= #text then
				self:colorWrite(1, 1 + i, text[messageLine])
			end
		end

		--  draw the window decoration
		curses.move(0, 0)
		curses.hline(Global.screenWidth)
		self:writeCentered(0, "{{WHITE}}" .. title)
		curses.move(0, Global.screenHeight - 1)
		curses.hline(Global.screenWidth)
		self:colorWrite(1, Global.screenHeight - 1, " {{cyan}}jk {{pop}}navigate {{cyan}}other {{pop}}exit ")
		if scroll > 1 then
			self:colorWrite(Global.screenWidth - 5, 0, " {{YELLOW}}^ ")
		end
		if scroll < maxScroll then
			self:colorWrite(Global.screenWidth - 5, Global.screenHeight - 1, " {{YELLOW}}v ")
		end
	end

	--	hide the cursor while showing the message log screen
	curses.cursor(0)

	while true do
		drawMessages()
		key = curses.getch()
		if key == "j" or key == "down" then
			scroll = math.min(scroll + 1, maxScroll)
		elseif key == "k" or key == "up" then
			scroll = math.max(scroll - 1, 1)
		elseif key == "pageup" or key == "upright" then
			scroll = math.max(scroll - (windowHeight - 2), 1)
		elseif key == "pagedown" or key == "downright" then
			scroll = math.min(scroll + (windowHeight - 2), maxScroll)
		elseif key == "home" or key == "upleft" then
			scroll = 1
		elseif key == "end" or key == "downleft" then
			scroll = maxScroll
		else
			break
		end
	end

	--	restore the state of the cursor
	curses.cursor(1)
end

--  UI:messageLogScreen() - display message log with interactive scrolling;
--  does not return anything
function UI:messageLogScreen()
	local lines = {}
	for line = 1, #(self.messageList) do
		lines[line] = self:getMessage(line)
	end
	self:scrollableTextScreen("Previous messages", lines, true)
end

--	UI:colorWrite() - draws a string of text at a given position on-screen,
--	allowing the use of in-text color changing by parsing color codes like
--	{{cyan}}.
--	Does not return anything.
--
--	Markup codes:
--		black red green yellow blue magenta cyan white
--		BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
--		normal bold reverse
--  	`text' (without inner spaces) as a shortcut for {{WHITE}}text{{pop}}
--		Also available, but not portable: underline standout blink
function UI:colorWrite(x, y, text)
	local currentX = x
	--	Stack of previous markup codes, starting with default
	local markupStack = {Global.defaultColor}

	local function write(str)
		curses.write(currentX, y, str)
		currentX = currentX + str:len()
	end

	--	Expand `hightlights' (maybe this should be specific to helpScreen()?)
	text = string.gsub(text, "`(%S-)'", "{{bold}}%1{{pop}}")

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

		--	Push or pop from the markup stack (we assume repeating the most previous
		--	markup is enough to undo
		if word == "pop" then
			table.remove(markupStack)
			word = markupStack[#markupStack]
		else
			table.insert(markupStack, word)
		end

		if curses[word] and type(curses[word]) == "number" then
			curses.attr(curses[word])
		else
			write(text:sub(startpos, nextpos))
		end

		pos = nextpos
	end

	--	reset to default color
	curses.attr(curses[Global.defaultColor])
end

--	UI:removeMarkup() - Returns copy of a string with all markup codes such
--	as {{white}} removed, for determining its length when drawn
function UI:removeMarkup(text)
	text = string.gsub(text, "`(%S-)'", "%1")
	return string.gsub(text, "{{(%a+)}}", "")
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
	curses.attr(curses.normal)
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

	curses.move(0, 0)
	curses.hline(Global.screenWidth)
	self:writeCentered(0, "Inventory")
	curses.move(0, Global.screenHeight - 1)
	curses.hline(Global.screenWidth)
	self:colorWrite(1, Global.screenHeight - 1, " {{cyan}}any key {{pop}}exit ")


	--	a-z
	for i = 0, 25 do
		local char = string.char(97 + i)
		if actor.inventory[char] then
			self:colorWrite(1, currentLine, "{{yellow}}" .. char .. "{{pop}} - " .. actor.inventory[char].name)
			currentLine = currentLine + 1
		end
	end

	--	A-Z
	for i = 0, 25 do
		local char = string.char(65 + i)
		if actor.inventory[char] then
			self:colorWrite(1, currentLine, "{{yellow}}" .. char .. "{{pop}} - " .. actor.inventory[char].name)
			currentLine = currentLine + 1
		end
	end

	curses.getch()
end

--	UI:helpScreen() - Display scrollable help file; returns nothing
function UI:helpScreen()
	local text = Util.iteratorToList(io.lines(Global.helpFilename))
	self:scrollableTextScreen("Help", text)
end

--	UI:testScreen() - Display screen with test graphics; returns nothing
function UI:testScreen()
	local text = Util.iteratorToList(io.lines("testscreen.txt"))
	self:scrollableTextScreen("Curses tests", text)
end

return UI

