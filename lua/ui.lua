
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
local Game = require "lua/game"

--	UI.init() - initialises a new UI object, and also initializes the curses
--	interface; returns nothing
function UI:init()
	self.width, self.height = curses.init()
	self.messageList = {}
	Game.log:write("Initialized curses interface.")
	Game.log:write("Screen w/h: " .. Global.screenWidth .. "x" .. Global.screenHeight)
end

--	UI:terminate() - terminates the interface object; does not return anything
function UI:terminate()
	curses.terminate()
	Game.log:write("Terminated curses interface.")
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

	--	draw the actors on the same map as the player, who are visible from
	--	the player character's point of view; only actors who are alive
	--	can be seen
	for i = 1, #(Game.actorList) do
		if Game.actorList[i].map == map
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

--	UI:message() - pushes a message onto the message list, so the player
--	may see it in-game; handles repeating messages by counting the times
--	a message was logged; does not return anything
function UI:message(text)
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
	Game.log:write("Message logged: " .. text)
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

--  UI:messageLogScreen() - display message log with interactive scrolling;
--  does not return anything
function UI:messageLogScreen()
	--  number of message that can be shown at once
	local windowHeight = Global.screenHeight - 2
	--  maximum 'scroll' value (fully scrolled to end)
	local maxScroll = math.max(1, #(self.messageList) - (windowHeight - 1))
	--  index of scroll-back buffer at top of window
	local scroll = maxScroll

	--  writeCentered() - Draw a string at the center of a line
	function writeCentered(y, str)
		curses.write((Global.screenWidth - #str - 1) / 2, y, " " .. str .. " ")
	end

	function drawMessageLog()
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
		writeCentered(0, "Previous messages")
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

return UI

