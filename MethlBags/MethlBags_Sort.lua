--[[
	MethlBags_Sort.lua
		Item sorting and categorization logic adapted from EngBags.
		Sorts items by category, then by name within each category.
--]]

-- Sort mode constants
METHLBAGS_NOSORT = 0
METHLBAGS_SORTBYNAME = 1
METHLBAGS_SORTBYNAMEREV = 2  -- reverses word order then sorts: "Potion Mana Major" vs "Major Mana Potion"

-- Category sort priority (lower number = higher priority in the display)
-- Items are first assigned a category, then sorted by name within that category.
MethlBags_CategoryPriority = {
	["HEARTH"]            = 1,
	["MOUNT"]             = 2,
	["SOULSHARDS"]        = 3,
	["KEYS"]              = 4,
	["KEYS_1"]            = 5,
	["KEYS_1_OTHER"]      = 6,
	["QUEST"]             = 10,
	["CLASS_ITEMS1"]      = 15,
	["CLASS_ITEMS2"]      = 16,
	["RUNE"]              = 20,
	["POTION"]            = 25,
	["HEALINGPOTION"]     = 26,
	["MANAPOTION"]        = 27,
	["ELIXIR"]            = 28,
	["ELIXIR_ZANZA"]      = 29,
	["ELIXIR_BLASTEDLANDS"] = 30,
	["FOOD"]              = 31,
	["DRINK"]             = 32,
	["BANDAGE"]           = 33,
	["CONSUMABLE"]        = 35,
	["JUJU"]              = 36,
	["EXPLOSIVE"]         = 37,
	["WEAPON_BUFF"]       = 40,
	["ROGUE_POISON"]      = 41,
	["ROGUE_REAGENTS"]    = 42,
	["PRIEST_REAGENTS"]   = 43,
	["MAGE_REAGENTS"]     = 44,
	["WARLOCK_REAGENTS"]  = 45,
	["SHAMAN_REAGENTS"]   = 46,
	["PALADIN_REAGENTS"]  = 47,
	["DRUID_REAGENTS"]    = 48,
	["TRADETOOLS"]        = 50,
	["RECIPE"]            = 55,
	["PATTERN"]           = 56,
	["SCHEMATIC"]         = 57,
	["FORMULA"]           = 58,
	["MANUAL"]            = 59,
	["PROJECTILE"]        = 60,
	["TRADESKILL"]        = 65,
	["TRADEGOODS"]        = 70,
	["EQUIPPED"]          = 75,
	["SOULBOUND"]         = 80,
	["MINIPET"]           = 85,
	["MISC"]              = 90,
	["REAGENT"]           = 91,
	["TOKEN"]             = 92,
	["GRAY"]              = 95,
	["EMPTY"]             = 99,
	["UNKNOWN"]           = 100,
}

--[[
	Known item overrides table.
	Maps "itemID:0:0:0" or "itemID:0:0:0-SB" to a category string.
	Adapted from EngBags default_items.lua.
--]]
MethlBags_ItemOverrides = {
	["6948:0:0:0-SB"]  = "HEARTH",         -- Hearthstone
	["21213:0:0:0"]    = "MOUNT",           -- Preserved Holly
	["7005:0:0:0"]     = "TRADETOOLS",      -- Skinning Knife
	["12709:0:0:0-SB"] = "TRADETOOLS",      -- Finkle's Skinner
	["5956:0:0:0"]     = "TRADETOOLS",      -- Blacksmith Hammer
	["6219:0:0:0"]     = "TRADETOOLS",      -- Arclight Spanner
	["2901:0:0:0"]     = "TRADETOOLS",      -- Mining Pick
	["6218:0:0:0-SB"]  = "TRADETOOLS",      -- Runed Copper Rod
	["6339:0:0:0-SB"]  = "TRADETOOLS",      -- Runed Silver Rod
	["11130:0:0:0-SB"] = "TRADETOOLS",      -- Runed Golden Rod
	["11145:0:0:0-SB"] = "TRADETOOLS",      -- Runed Truesilver Rod
	["20051:0:0:0-SB"] = "TRADETOOLS",      -- Runed Arcanite Rod
	["9149:0:0:0-SB"]  = "TRADETOOLS",      -- Philosopher's Stone
	["4471:0:0:0"]     = "TRADETOOLS",      -- Flint and Tinder
	["17029:0:0:0"]    = "PRIEST_REAGENTS", -- Sacred Candle
	["17028:0:0:0"]    = "PRIEST_REAGENTS", -- Holy Candle
	["17020:0:0:0"]    = "MAGE_REAGENTS",   -- Arcane Powder
	["17031:0:0:0"]    = "MAGE_REAGENTS",   -- Rune of Teleportation
	["17032:0:0:0"]    = "MAGE_REAGENTS",   -- Rune of Portals
	["5565:0:0:0"]     = "WARLOCK_REAGENTS",-- Infernal stone
	["16583:0:0:0"]    = "WARLOCK_REAGENTS",-- Demonic Figurine
	["6265:0:0:0-SB"]  = "SOULSHARDS",      -- Soul Shard
	["5530:0:0:0"]     = "ROGUE_REAGENTS",  -- Blinding Powder
	["5140:0:0:0"]     = "ROGUE_REAGENTS",  -- Flash Powder
	["17030:0:0:0"]    = "SHAMAN_REAGENTS", -- Ankh
	["17033:0:0:0"]    = "PALADIN_REAGENTS",-- Symbol of Divinity
	["21177:0:0:0"]    = "PALADIN_REAGENTS",-- Symbol of Kings
	["17026:0:0:0"]    = "DRUID_REAGENTS",  -- Wild Thornroot
	["17038:0:0:0"]    = "DRUID_REAGENTS",  -- Ironwood Seed
	["17037:0:0:0"]    = "DRUID_REAGENTS",  -- Hornbeam Seed
	["17036:0:0:0"]    = "DRUID_REAGENTS",  -- Ashwood Seed
	["17035:0:0:0"]    = "DRUID_REAGENTS",  -- Stranglethorn Seed
	["17034:0:0:0"]    = "DRUID_REAGENTS",  -- Maple Seed
	["20079:0:0:0-SB"] = "ELIXIR_ZANZA",    -- Spirit of Zanza
	["20080:0:0:0-SB"] = "ELIXIR_ZANZA",    -- Sheen of Zanza
	["20081:0:0:0-SB"] = "ELIXIR_ZANZA",    -- Swiftness of Zanza
	["13510:0:0:0"]    = "ELIXIR",           -- Flask of the Titans
	["13511:0:0:0"]    = "ELIXIR",           -- Flask of Distilled Wisdom
	["13512:0:0:0"]    = "ELIXIR",           -- Flask of Supreme Power
	["13513:0:0:0"]    = "ELIXIR",           -- Flask of Chromatic Resistance
	["13506:0:0:0"]    = "ELIXIR",           -- Flask of Petrification
	["10646:0:0:0"]    = "EXPLOSIVE",        -- Goblin Sapper Charge
	["13180:0:0:0-SB"] = "EXPLOSIVE",        -- Stratholme Holy Water
	["8956:0:0:0"]     = "EXPLOSIVE",        -- Oil of Immolation
}

--[[
	Tooltip-based search patterns for categorization.
	Each entry: { category, tooltip_pattern }
	First match wins (order matters).
	Adapted from EngBags DefaultSearchList.
--]]
MethlBags_TooltipSearchList = {
	{ "FOOD",          "Restores ([0-9.]+) health over ([0-9.]+) sec" },
	{ "DRINK",         "Restores ([0-9.]+) mana over ([0-9.]+) sec" },
	{ "HEALINGPOTION", "Restores ([0-9.]+) to ([0-9.]+) health" },
	{ "MANAPOTION",    "Restores ([0-9.]+) to ([0-9.]+) mana" },
	{ "PROJECTILE",    "Projectile" },
	{ "JUJU",          "Juju" },
	{ "BANDAGE",       "Bandage" },
	{ "RECIPE",        "Recipe:" },
	{ "PATTERN",       "Pattern:" },
	{ "SCHEMATIC",     "Schematic:" },
	{ "FORMULA",       "Formula:" },
	{ "MINIPET",       "Right Click to summon and dismiss your" },
}

--[[
	GetItemInfo type-based categorization.
	Maps the 6th return value of GetItemInfo (itemType) to a category.
--]]
MethlBags_TypeCategories = {
	["Quest"]         = "QUEST",
	["Trade Goods"]   = "TRADEGOODS",
	["Consumable"]    = "CONSUMABLE",
	["Reagent"]       = "REAGENT",
	["Miscellaneous"] = "MISC",
	["Recipe"]        = "RECIPE",
}

--[[
	Reverse word order in a string for SORTBYNAMEREV mode.
	"Major Mana Potion" becomes "Potion Mana Major"
--]]
function MethlBags_ReverseString(str)
	if not str or str == "" then return "" end
	local words = {}
	for w in string.gfind(str, "%S+") do
		table.insert(words, 1, w)
	end
	return table.concat(words, " ")
end

--[[
	Extract item ID from an item link.
	Returns "itemID:enchant:suffix:unique" string or nil.
--]]
function MethlBags_GetItemKey(link)
	if not link then return nil end
	local _, _, itemKey = string.find(link, "item:(%d+:%d+:%d+:%d+)")
	return itemKey
end

--[[
	Extract item name from an item link.
--]]
function MethlBags_GetItemName(link)
	if not link then return nil end
	local _, _, name = string.find(link, "|h%[(.-)%]|h")
	return name
end

--[[
	Determine item rarity (quality) from link color.
	Returns quality number: 0=gray, 1=white, 2=green, 3=blue, 4=purple, 5=orange
--]]
function MethlBags_GetItemRarity(link)
	if not link then return 0 end
	local _, _, hexColor = string.find(link, "|cff(%x+)|H")
	if not hexColor then return 1 end
	-- gray
	if hexColor == "9d9d9d" then return 0 end
	-- white
	if hexColor == "ffffff" then return 1 end
	-- green
	if hexColor == "1eff00" then return 2 end
	-- blue
	if hexColor == "0070dd" then return 3 end
	-- purple
	if hexColor == "a335ee" then return 4 end
	-- orange (legendary)
	if hexColor == "ff8000" then return 5 end
	return 1
end

--[[
	Categorize an item given its link, tooltip text, and soulbound status.
	Returns a category string from the priority table.

	Categorization order (adapted from EngBags):
	1. Check known item overrides
	2. Check tooltip-based patterns
	3. Check GetItemInfo type
	4. Check if soulbound equipment
	5. Gray items
	6. Fall back to UNKNOWN
--]]
function MethlBags_CategorizeItem(link, bagID, slotID)
	if not link then return "EMPTY" end

	local itemKey = MethlBags_GetItemKey(link)
	if not itemKey then return "UNKNOWN" end

	-- Check soulbound via tooltip
	local isSoulbound = false
	MethlBagsTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	if bagID == -1 then
		MethlBagsTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slotID))
	else
		MethlBagsTooltip:SetBagItem(bagID, slotID)
	end
	local tooltipText = ""
	for i = 1, MethlBagsTooltip:NumLines() do
		local line = getglobal("MethlBagsTooltipTextLeft" .. i)
		if line then
			local text = line:GetText()
			if text then
				tooltipText = tooltipText .. " " .. text
				if string.find(text, "Soulbound") then
					isSoulbound = true
				end
			end
		end
	end
	MethlBagsTooltip:Hide()

	-- Build override key
	local overrideKey = itemKey
	if isSoulbound then
		overrideKey = itemKey .. "-SB"
	end

	-- Step 1: Check known item overrides (try SB key first if soulbound)
	if isSoulbound and MethlBags_ItemOverrides[overrideKey] then
		return MethlBags_ItemOverrides[overrideKey]
	end
	if MethlBags_ItemOverrides[itemKey] then
		return MethlBags_ItemOverrides[itemKey]
	end

	-- Step 2: Gray items
	local rarity = MethlBags_GetItemRarity(link)
	if rarity == 0 then return "GRAY" end

	-- Step 3: Tooltip pattern matching
	for _, entry in ipairs(MethlBags_TooltipSearchList) do
		if string.find(tooltipText, entry[2]) then
			return entry[1]
		end
	end

	-- Step 4: GetItemInfo type
	local _, _, _, _, _, itemType = GetItemInfo(MethlBags_GetItemIDFromLink(link))
	if itemType and MethlBags_TypeCategories[itemType] then
		return MethlBags_TypeCategories[itemType]
	end

	-- Step 5: Soulbound equipment
	if isSoulbound then
		-- Check if it's equippable (has an equip slot in tooltip)
		local equipSlots = {"Head", "Neck", "Shoulder", "Back", "Chest", "Wrist",
			"Hands", "Waist", "Legs", "Feet", "Finger", "Trinket",
			"Main Hand", "Off Hand", "One-Hand", "Two-Hand", "Ranged"}
		for _, slot in ipairs(equipSlots) do
			if string.find(tooltipText, slot) then
				return "SOULBOUND"
			end
		end
		return "SOULBOUND"
	end

	return "UNKNOWN"
end

--[[
	Extract numeric item ID from a link.
--]]
function MethlBags_GetItemIDFromLink(link)
	if not link then return nil end
	local _, _, id = string.find(link, "item:(%d+)")
	if id then return tonumber(id) end
	return nil
end

--[[
	Build a sortable key for an item.
	Format: "PP_CategoryName_ItemName_Count" where PP is zero-padded priority.
--]]
function MethlBags_BuildSortKey(link, category, sortMode)
	local priority = MethlBags_CategoryPriority[category] or 100
	local name = MethlBags_GetItemName(link) or ""

	if sortMode == METHLBAGS_SORTBYNAMEREV then
		name = MethlBags_ReverseString(name)
	end

	return string.format("%03d_%s_%s", priority, category, name)
end

--[[
	Sort an array of item entries.
	Each entry is: { bagID, slotID, link, texture, count, sortKey }
	Sorts by sortKey (category priority + name).
--]]
function MethlBags_SortItems(items, sortMode)
	if not sortMode then sortMode = METHLBAGS_SORTBYNAME end

	-- Assign sort keys
	for _, item in ipairs(items) do
		if item.link then
			local category = MethlBags_CategorizeItem(item.link, item.bagID, item.slotID)
			item.category = category
			item.sortKey = MethlBags_BuildSortKey(item.link, category, sortMode)
		else
			item.category = "EMPTY"
			item.sortKey = string.format("%03d_EMPTY", 99)
		end
	end

	-- Sort by sortKey
	table.sort(items, function(a, b)
		return a.sortKey < b.sortKey
	end)

	return items
end
