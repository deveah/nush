
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
				curses.attr(curses.BLACK)
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

	--	draw the status lines
	curses.clearLine(23)
	curses.clearLine(24)
	curses.write(Global.screenWidth - Game.player.map.name:len(), 23, Game.player.map.name)
	local equip = Game.player.equipment
	local weaponry = "Weapon: "
	if equip.meleeWeapon then
		weaponry = weaponry .. equip.meleeWeapon:describe()
	else
		weaponry = weaponry .. "None"
	end
	weaponry = weaponry .. "/"
	if equip.rangedWeapon then
		weaponry = weaponry .. equip.rangedWeapon:describe()
	else
		weaponry = weaponry .. "None"
	end
	curses.write(0, 24, weaponry)

	local healthStatus
	if Game.player.hp == Game.player.maxHp then
		--	green highlight if health is full
		healthStatus = "({{GREEN}}" .. Game.player.hp .. "{{pop}}/" .. Game.player.maxHp .. ")"
	elseif Game.player.hp <= math.floor(Game.player.maxHp / 4) then
		--	red highlight if health is under 25%
		healthStatus = "({{RED}}" .. Game.player.hp .. "{{pop}}/" .. Game.player.maxHp .. ")"
	else
		healthStatus = "(" .. Game.player.hp .. "/" .. Game.player.maxHp .. ")"
	end
	UI:colorWrite(0, 23, Game.player.name .. " " .. healthStatus)

	--	position the cursor on the player, so it may be easily seen
	curses.cursor(1)
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
	self:colorWrite(math.floor((Global.screenWidth - #self:removeMarkup(str) - 2) / 2), y, " " .. str .. " ")
end

--	UI:centeredWindow() - Draw a box in the center of the screen, and
--	return x,y position of top-left corner
function UI:centeredWindow(width, height)
	width = math.min(Global.screenWidth, width)
	height = math.min(Global.screenHeight, height)
	local xOffset, yOffset = math.floor((Global.screenWidth - width) / 2), math.floor((Global.screenHeight - height) / 2)
	curses.move(xOffset, yOffset)
	curses.clearBox(width, height)
	curses.attr(curses.WHITE)
	curses.box(width, height)
	return xOffset, yOffset
end

--	UI:drawMessageBox() - Display a block of text on-screen.
--	Returns x, y, width, height (x,y being left and top of the box)
--	 title (optional): string displayed on top edge
--	 text: either a list of lines, or a single string. If it's a string
--	       then it's wrapped, choosing box width automatically.
--	 bottomLine (optional): string displayed on bottom-left edge
--	 minWidth/minHeight (optional)
function UI:drawMessageBox(title, text, bottomLine, minWidth, minHeight)
	local lines, wrapped, numLines
	local x, y, width, height
	width = minWidth or 35
	if bottomLine then
		width = math.max(#bottomLine + 4, width)
	end
	minHeight = minHeight or 0

	if type(text) == "table" then
		--	Already split into a list of lines, no wrapping done
		height = math.max(minHeight, #text + 2)
		for i = 1, #text do
			width = math.max(width, #text[i] + 4)
		end
		wrapped = table.concat(text, "\n")

	else
		--	Decide how wide to make the box and wrap 'text', picking a width which
		--	doesn't result in a too-tall box
		for wid = width, Global.screenWidth, 6 do
			width = wid
			wrapped, numLines = self:wrapString(text, width - 4)
			height = math.max(minHeight, numLines + 2)
			if height <= Global.screenHeight - 2 and 2 * height < width then
				break
			end
		end
	end

	--	Draw
	local xOffset, yOffset = self:centeredWindow(width, height)
	if title then
		self:writeCentered(yOffset, "{{WHITE}}" .. title)
	end
	self:colorWrite(xOffset + 2, yOffset + 1, wrapped)
	if bottomLine then
		self:colorWrite(xOffset + 3, yOffset + height - 1, bottomLine)
	end

	return x, y, width, height
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
		if #text > windowHeight then
			self:colorWrite(1, Global.screenHeight - 1, " {{cyan}}jk{{pop}} navigate {{cyan}}other{{pop}} exit ")
		end
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
		local key = curses.getch()
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

--	UI:wrapString() - Wraps a string around so that no line is longer than
--	width characters; returns (wrapped, numLines), where wrapped is a string
--	wgit ith "\n"s added and numLines is the number of \n characters + 1.
function UI:wrapString(text, width)
	local ret = ""
	local numLines = 0

	--	First split into lines according to newlines already in the text, and
	--	then wrap each of those independently
	local fullLines = Util.stringSplit(text, "\n")
	for lineNum, line in ipairs(fullLines) do
		--	Add back newlines stripped by stringSplit()
		if lineNum > 1 then ret = ret .. "\n" end

		--	Iterate through this line looking for points at which to wrap it.
		local idx = 1   --	current offset
		local lastSpace --	offset of last seen space
		while idx <= #line do
			--	Only check whether need to wrap when we reach a space or the end, so
			--	that we don't	call removeMarkup() in the middle of a {{tag}}.
			local isSpace = line:byte(idx) == 32
			if isSpace or idx == #line then

				--	Calling removeMarkup() so often is inefficient, but the prefix is short
				local stripped = self:removeMarkup(line:sub(1, idx))
				if #stripped <= width then
					lastSpace = idx
				else
					--	Edge case: space just past edge of line
					if isSpace and #stripped == width + 1 then
						lastSpace = idx
					end

					--	Move a prefix of 'line' to 'ret'
					if not lastSpace then
						--	No spaces found, just cut through a word (hope it's not markup!)
						ret = ret .. line:sub(1, width) .. "\n"	
						line = line:sub(width + 1)
					else
						--	Remove the last space
						ret = ret .. line:sub(1, lastSpace - 1) .. "\n"
						line = line:sub(lastSpace + 1)
					end
					numLines = numLines + 1
					idx = 0
					lastSpace = nil
				end
			end
			idx = idx + 1
		end

		ret = ret .. line
		numLines = numLines + 1
	end
	return ret, numLines
end

--	UI:colorWrite() - draws a string of text at a given position on-screen,
--	allowing the use of in-text color changing by parsing color codes like
--	{{cyan}}, and processing newlines.
--	Note: doesn't wrap automatically, use UI:wrapString() if needed.
--	Does not return anything.
--
--	Markup codes:
--		black red green yellow blue magenta cyan white
--		BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
--		normal bold reverse
--  	`text' (without inner spaces) as a shortcut for {{WHITE}}text{{pop}}
--		Also available, but not portable: underline standout blink
function UI:colorWrite(x, y, text)
	local currentX, currentY = x, y
	--	Stack of previous markup codes, starting with default
	local markupStack = {Global.defaultColor}
	curses.attr(curses[Global.defaultColor])

	--	Write string to screen while processing newlines.
	local function write(str)
		local lines = Util.stringSplit(str, "\n")
		for line = 1, #lines do
			if line > 1 then
				currentX = x
				currentY = currentY + 1
			end
			curses.write(currentX, currentY, lines[line])
			currentX = currentX + lines[line]:len()
		end
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

--	UI:itemMenu() - Display info on an item and wait for player to select from
--	a list of actions. Returns nothing.
function UI:itemMenu(actor, item)
	--	First build list of available actions
	local actionKeys = {}
	local actionString = " Actions:"

	--	Add the name of an action to the list of available actions.
	--	The letter to be highlighted should be surrounded by [], eg [d]rop
	function addAction(name)
		local key = name:match("%[(%a)%]")
		actionKeys[key] = true
		actionString = actionString .. " " .. name:gsub("%[(%a)%]", "[{{YELLOW}}%1{{pop}}]")
	end

	addAction("[d]rop")

	if item.equipped then
		addAction("[u]nequip")
	elseif item.equipSlot then
		-- if item.category == "Weapons" then
		-- 	addAction("[w]ield")
		addAction("[e]quip")
	end

	if item.consumable then
		addAction("[a]pply")
	end

	--	Draw display while preserving whatever is already on-screen
	local contents = ""
	if item.info then
		contents = contents .. item.info .. "\n\n"
	end
	if item.equipped then
		contents = contents .. "Equipped as " .. item.equipSlot .. "\n"
	end
	if item.examine then
		contents = contents .. item:examine() .. "\n"
	end
	contents = contents .. "\n" .. actionString 

	self:drawMessageBox(item:describe(), contents, " {{cyan}}other{{pop}} exit ")
	curses.cursor(0)
	--local width, height = 50, 8

	--	Controls
	local key = curses.getch()

	--	Drop
	if key == "d" then
		actor:dropItem(item)
	end

	--	Equip
	if key == "e" and actionKeys["e"] then
		actor:equip(item)
	end

	--	Unequip
	if key == "u" and actionKeys["u"] then
		actor:unequip(item)
	end

	--	Apply
	if key == "a" and actionKeys["a"] then
		if item:apply(actor) then
			--	applying a consumable consumes one piece of it
			item.count = item.count - 1
			if item.count == 0 then
				item:destroy()
			end
		end
	end

	--	quit, whether a valid action or not
	return
end


--	UI:inventoryScreen() - draws a screen showing the contents of a given actor's
--	inventory; does not return anything.
--	TODO: add scrolling and show items in categories
function UI:inventoryScreen(actor)

	local messageline = nil

	local function drawInventoryScreen()
		local currentLine = 1

		curses.clear()

		--	Draw window decoration
		curses.attr(curses.normal)
		curses.move(0, 0)
		curses.hline(Global.screenWidth)
		self:writeCentered(0, "{{WHITE}}Inventory")
		curses.move(0, Global.screenHeight - 2)
		curses.hline(Global.screenWidth)
		self:colorWrite(1, Global.screenHeight - 2, " {{cyan}}slot{{pop}} examine/use item  {{cyan}}other{{pop}} exit ")
		if messageline then
			self:colorWrite(1, Global.screenHeight - 1, messageline)
		end

		--	List items
		for _, slot in ipairs(actor.InventorySlots) do
			local item = actor.inventory[slot]
			if item then
				local description = item:describe()
				if item.equipped then
					description = description .. " (equipped)"
				end
				self:colorWrite(2, currentLine, "{{yellow}}" .. slot .. "{{pop}} - " .. description)
				currentLine = currentLine + 1
			end
		end
	end

	while true do
		drawInventoryScreen()
		messageline = nil
		local key = curses.getch()

		if Util.tableFind(actor.InventorySlots, key) then
			--	This is a valid item slot
			local slot = key
			local item = actor.inventory[slot]
			if item then
				self:itemMenu(actor, item)
				return
			else
				messageline = "{{normal}}No item in slot '" .. slot .. "'"
			end
		else
			break
		end
	end
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

--	UI:highscoreScreen() - display screen with highscore table; returns nothing
function UI:highscoreScreen()
	local csv = require "lua/csv"
	local f = csv.open("scores.csv")
	local text = {}
	
	table.insert(text, "{{YELLOW}}  # Name        Score Place       Reason of death{{pop}}")

	--	TODO: sort entries by score
	for i = 2, #f.data do
		local line = 
			string.format("%3i", i-1) .. " " ..
			f.data[i]["playerName"] .. string.rep(" ", 12 - f.data[i]["playerName"]:len()) ..
			string.format("%5i", tonumber(f.data[i]["score"])) .. " " ..
			f.data[i]["placeOfDeath"] .. string.rep(" ", 12 - f.data[i]["placeOfDeath"]:len()) ..
			f.data[i]["reasonOfDeath"]

		--	highlight current event
		if i == #f.data then
			line = "{{WHITE}}" .. line .. "{{pop}}"
		end

		table.insert(text, line)
	end

	UI:scrollableTextScreen("High scores", text, false)
end

--	UI:playerScreen() - display screen with player character information
function UI:playerScreen()
	local text = {}
	table.insert(text, "{{YELLOW}}" .. Game.player.name)
	table.insert(text, "")
	
	local healthStatus
	if Game.player.hp == Game.player.maxHp then
		healthStatus = "You have {{GREEN}}" .. Game.player.hp .. "{{pop}} out of " ..
			Game.player.maxHp .. " hit points."
	elseif Game.player.hp <= math.floor(Game.player.maxHp / 4) then
		healthStatus = "You have {{RED}}" .. Game.player.hp .. "{{pop}} out of " ..
			Game.player.maxHp .. " hit points."
	else
		healthStatus = "You have " .. Game.player.hp .. " out of " ..
			Game.player.maxHp .. " hit points."
	end
	table.insert(text, healthStatus)
	table.insert(text, "You have {{GREEN}}" .. Game.player.spendableExperience .. "{{pop}} spendable experience points, out of " .. Game.player.totalExperience .. " total gained.")
	table.insert(text, "")

	table.insert(text, "{{WHITE}}Equipment:{{pop}}")
	local equip = Game.player.equipment
	local melee, ranged
	if equip.meleeWeapon then
		melee = "{{yellow}}" .. equip.meleeWeapon:describe() .. "{{pop}}"
	else
		melee = "None"
	end
	if equip.rangedWeapon then
		ranged = "{{yellow}}" .. equip.rangedWeapon:describe() .. "{{pop}}"
	else
		ranged = "None"
	end
	table.insert(text, "     melee: " .. melee)
	table.insert(text, "    ranged: " .. ranged)
	table.insert(text, "")

	table.insert(text, "{{WHITE}}Skills:{{pop}}")
	table.insert(text, "     melee: " .. Game.player.skills.melee)
	table.insert(text, "  handguns: " .. Game.player.skills.handguns)

	UI:scrollableTextScreen("Player info", text, false)
end

--	UI:skillPointScreen() - display a screen on which the player can assign
--	skill points; does not return anything
function UI:skillPointScreen()
	local function displayPointDialog()
		local text
		if Game.player.spendableExperience == 0 then
			text = "\nYou have no experience points to assign.\n"
		else
			text =
				"You have {{green}}" .. Game.player.spendableExperience .. "{{pop}} assignable skill points.\n" ..
				"You may upgrade the following skills:\n" ..
				"[{{YELLOW}}a{{pop}}] melee (" .. Game.player.skills.melee .. ")\n" ..
				"[{{YELLOW}}b{{pop}}] handguns (" .. Game.player.skills.handguns .. ")\n" ..
				"[{{YELLOW}}c{{pop}}] lockpick (" .. Game.player.skills.lockpick .. ")"
		end

		self:drawScreen()
		self:drawMessageBox("Assign skill points", text, " {{cyan}}other{{pop}} exit ", 45)
		--	hide the cursor
		curses.cursor(0)
	end

	local canUpgrade
	local key

	while true do
		canUpgrade = Game.player.spendableExperience > 0
		displayPointDialog()
		key = curses.getch()

		--	upgrade melee
		if canUpgrade and key == "a" then
			Game.player.skills.melee = Game.player.skills.melee + 1
			Game.player.spendableExperience = Game.player.spendableExperience - 1
		end

		if canUpgrade and key == "b" then
			Game.player.skills.handguns = Game.player.skills.handguns + 1
			Game.player.spendableExperience = Game.player.spendableExperience - 1
		end

		if canUpgrade and key == "c" then
			Game.player.skills.lockpick = Game.player.skills.lockpick + 1
			Game.player.spendableExperience = Game.player.spendableExperience - 1
		end

		--	Exit if not a letter in the range of skill keys
		if not (#key == 1 and "a" <= key and key <= "c") then
			break
		end
	end

	--	restore visibility to the cursor
	curses.cursor(1)
end

return UI

