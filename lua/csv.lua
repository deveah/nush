
--
--	csv.lua
--	Lua module that reads a subset of the CSV format
--	Members of the csv object:
--	* filename (string) - path of the file to read from
--	* fd - file descriptor of the file to read from
--	* rows (table) - contains the file's lines
--	* rawData (integer-indexed table) - contains the column data, indexed by integers
--	* data (string-indexed table) - contains the column data, indexed by column name;
--		column names are placed on the first row of the file
--

local csv = {}
csv.__index = csv

function csv.open(filename)
	local c = {}
	setmetatable(c, csv)

	--	open the file and try to parse it
	c.filename = filename
	c.fd = io.open(filename, "r")
	assert(c.fd ~= nil, "Unable to open " .. filename .. " for reading.")

	--	split file by lines
	c.rows = {}
	repeat
		local row = c.fd:read("*line")
		if row then table.insert(c.rows, row) end
	until row == nil

	c.data = {}
	c.rawData = {}
	for rowId, rowData in ipairs(c.rows) do
		c.rawData[rowId] = {}
		c.data[rowId] = {}
		
		--	split each line by comma
		rowData:gsub("([^,]+)", function(a) table.insert(c.rawData[rowId], a) end)
		if rowId > 1 then
			--	save data in tables with named fields, for easy access
			for columnId, columnData in ipairs(c.rawData[rowId]) do
				c.data[rowId][c.rawData[1][columnId]] = columnData
			end
		end
	end

	return c
end

function csv:close()
	self.fd:close()
end

function csv:dump()
	local function printTable(tbl)
		for k, v in pairs(tbl) do
			if type(v) == "table" then
				printTable(v)
			else
				print(k .. " = " .. v)
			end
		end
	end

	printTable(self.data)
end

return csv

