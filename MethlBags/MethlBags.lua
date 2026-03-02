--[[
	MethlBags.lua
		Unified one-bag inventory view with bank viewing button
		and EngBags-style item sorting.

	Features:
		- Single frame showing all bag contents (bags 0-4 + keyring)
		- "Show Bank" button to view cached bank contents
		- Sort button using EngBags-style categorization
		- Movable, resizable frame with close button
--]]

-- Constants
local DEFAULT_COLS = 10
local DEFAULT_SPACING = 2
local ITEM_SIZE = 37

-- State
local methlBags_sortMode = METHLBAGS_SORTBYNAME
local methlBags_showingBank = false
local methlBags_atBank = false
local methlBags_bankCache = {}  -- cached bank item data

-- Bag sets
local INVENTORY_BAGS = {0, 1, 2, 3, 4}  -- keyring (-2) excluded from main display for simplicity
local BANK_BAGS = {-1, 5, 6, 7, 8, 9, 10}

--[[ ==================== ]]--
--[[ Initialization        ]]--
--[[ ==================== ]]--

function MethlBags_OnLoad()
	this:RegisterEvent("ADDON_LOADED")
	this:RegisterEvent("BAG_UPDATE")
	this:RegisterEvent("ITEM_LOCK_CHANGED")
	this:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	this:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
	this:RegisterEvent("BANKFRAME_OPENED")
	this:RegisterEvent("BANKFRAME_CLOSED")
	this:RegisterEvent("PLAYER_MONEY")
end

function MethlBags_OnEvent()
	if event == "ADDON_LOADED" and arg1 == "MethlBags" then
		MethlBags_Initialize()
	elseif event == "BAG_UPDATE" then
		if MethlBagsFrame:IsVisible() and not methlBags_showingBank then
			MethlBags_UpdateDisplay()
		end
	elseif event == "ITEM_LOCK_CHANGED" then
		if MethlBagsFrame:IsVisible() then
			MethlBags_UpdateLocks()
		end
	elseif event == "BANKFRAME_OPENED" then
		methlBags_atBank = true
		MethlBags_CacheBankItems()
		if methlBags_showingBank and MethlBagsFrame:IsVisible() then
			MethlBags_UpdateDisplay()
		end
	elseif event == "BANKFRAME_CLOSED" then
		methlBags_atBank = false
		if methlBags_showingBank and MethlBagsFrame:IsVisible() then
			MethlBags_UpdateDisplay()
		end
	elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
		if methlBags_atBank then
			MethlBags_CacheBankItems()
			if methlBags_showingBank and MethlBagsFrame:IsVisible() then
				MethlBags_UpdateDisplay()
			end
		end
	elseif event == "PLAYER_MONEY" then
		if MethlBagsFrame:IsVisible() then
			MethlBags_UpdateMoney()
		end
	end
end

function MethlBags_Initialize()
	-- Initialize saved variables
	if not MethlBagsSets then
		MethlBagsSets = {
			cols = DEFAULT_COLS,
			sortMode = METHLBAGS_SORTBYNAME,
		}
	end

	methlBags_sortMode = MethlBagsSets.sortMode or METHLBAGS_SORTBYNAME

	-- Make closable with Escape
	tinsert(UISpecialFrames, "MethlBagsFrame")

	-- Override bag hooks so opening any bag opens MethlBags
	MethlBags_HookBags()

	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffMethlBags|r loaded. Type |cff00ff00/mb|r for commands.", 0.5, 0.8, 1.0)
end

--[[ ==================== ]]--
--[[ Bag Hook Overrides    ]]--
--[[ ==================== ]]--

function MethlBags_HookBags()
	-- Override ToggleBackpack to open our unified view
	local origToggleBackpack = ToggleBackpack
	ToggleBackpack = function()
		MethlBags_Toggle()
	end

	-- Override OpenBackpack
	local origOpenBackpack = OpenBackpack
	OpenBackpack = function()
		if not MethlBagsFrame:IsVisible() then
			MethlBags_Show()
		end
	end

	-- Override CloseBackpack
	local origCloseBackpack = CloseBackpack
	CloseBackpack = function()
		if MethlBagsFrame:IsVisible() then
			MethlBagsFrame:Hide()
		end
	end

	-- Override ToggleBag
	local origToggleBag = ToggleBag
	ToggleBag = function(id)
		if id >= 0 and id <= 4 then
			MethlBags_Toggle()
		else
			origToggleBag(id)
		end
	end

	-- Override OpenBag
	local origOpenBag = OpenBag
	OpenBag = function(id)
		if id >= 0 and id <= 4 then
			if not MethlBagsFrame:IsVisible() then
				MethlBags_Show()
			end
		else
			origOpenBag(id)
		end
	end

	-- Override CloseBag
	local origCloseBag = CloseBag
	CloseBag = function(id)
		if id >= 0 and id <= 4 then
			-- Only close if not manually opened
			if MethlBagsFrame:IsVisible() and not MethlBagsFrame.manOpened then
				MethlBagsFrame:Hide()
			end
		else
			origCloseBag(id)
		end
	end

	-- Override OpenAllBags (actually a toggle in vanilla)
	local origOpenAllBags = OpenAllBags
	OpenAllBags = function(forceOpen)
		MethlBags_Toggle()
	end

	-- Override CloseAllBags
	local origCloseAllBags = CloseAllBags
	CloseAllBags = function()
		if MethlBagsFrame:IsVisible() then
			MethlBagsFrame:Hide()
		end
	end
end

--[[ ==================== ]]--
--[[ Show / Hide / Toggle  ]]--
--[[ ==================== ]]--

function MethlBags_Show()
	methlBags_showingBank = false
	MethlBagsBankButton:SetText("Show Bank")
	MethlBagsFrameTitle:SetText(UnitName("player") .. "'s Inventory")
	MethlBags_UpdateDisplay()
	MethlBagsFrame:Show()
	MethlBagsFrame.manOpened = true
	PlaySound("igBackPackOpen")
end

function MethlBags_Hide()
	MethlBagsFrame:Hide()
	MethlBagsFrame.manOpened = nil
	PlaySound("igBackPackClose")
end

function MethlBags_Toggle()
	if MethlBagsFrame:IsVisible() then
		MethlBags_Hide()
	else
		MethlBags_Show()
	end
end

--[[ ==================== ]]--
--[[ Bank Button            ]]--
--[[ ==================== ]]--

function MethlBags_ToggleBank()
	methlBags_showingBank = not methlBags_showingBank

	if methlBags_showingBank then
		MethlBagsBankButton:SetText("Show Bags")
		MethlBagsFrameTitle:SetText(UnitName("player") .. "'s Bank")
	else
		MethlBagsBankButton:SetText("Show Bank")
		MethlBagsFrameTitle:SetText(UnitName("player") .. "'s Inventory")
	end

	MethlBags_UpdateDisplay()
end

--[[ ==================== ]]--
--[[ Sort Button            ]]--
--[[ ==================== ]]--

function MethlBags_ToggleSort()
	if methlBags_sortMode == METHLBAGS_NOSORT then
		methlBags_sortMode = METHLBAGS_SORTBYNAME
		MethlBagsSortButton:SetText("Sorted")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffMethlBags|r: Sort by name enabled.", 0.5, 0.8, 1.0)
	elseif methlBags_sortMode == METHLBAGS_SORTBYNAME then
		methlBags_sortMode = METHLBAGS_SORTBYNAMEREV
		MethlBagsSortButton:SetText("Sorted (Rev)")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffMethlBags|r: Sort by reversed name enabled.", 0.5, 0.8, 1.0)
	else
		methlBags_sortMode = METHLBAGS_NOSORT
		MethlBagsSortButton:SetText("Unsorted")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffMethlBags|r: Sorting disabled.", 0.5, 0.8, 1.0)
	end

	MethlBagsSets.sortMode = methlBags_sortMode
	MethlBags_UpdateDisplay()
end

--[[ ==================== ]]--
--[[ Bank Caching           ]]--
--[[ ==================== ]]--

function MethlBags_CacheBankItems()
	methlBags_bankCache = {}

	for _, bagID in BANK_BAGS do
		local numSlots
		if bagID == -1 then
			numSlots = 24
		else
			numSlots = GetContainerNumSlots(bagID)
		end

		for slotID = 1, numSlots do
			local texture, count, locked
			local link

			if bagID == -1 then
				-- Bank main slots
				local invSlot = BankButtonIDToInvSlotID(slotID)
				texture = GetInventoryItemTexture("player", invSlot)
				count = GetInventoryItemCount("player", invSlot)
				link = GetInventoryItemLink("player", invSlot)
			else
				texture, count, locked = GetContainerItemInfo(bagID, slotID)
				link = GetContainerItemLink(bagID, slotID)
			end

			table.insert(methlBags_bankCache, {
				bagID = bagID,
				slotID = slotID,
				link = link,
				texture = texture,
				count = count or 0,
			})
		end
	end
end

--[[ ==================== ]]--
--[[ Collect Items          ]]--
--[[ ==================== ]]--

function MethlBags_CollectInventoryItems()
	local items = {}

	for _, bagID in INVENTORY_BAGS do
		local numSlots = GetContainerNumSlots(bagID)
		for slotID = 1, numSlots do
			local texture, count, locked = GetContainerItemInfo(bagID, slotID)
			local link = GetContainerItemLink(bagID, slotID)

			table.insert(items, {
				bagID = bagID,
				slotID = slotID,
				link = link,
				texture = texture,
				count = count or 0,
			})
		end
	end

	return items
end

function MethlBags_CollectBankItems()
	-- If we're at the bank, get fresh data; otherwise use cache
	if methlBags_atBank then
		MethlBags_CacheBankItems()
	end

	-- Return a copy of the cache
	local items = {}
	for _, item in methlBags_bankCache do
		table.insert(items, {
			bagID = item.bagID,
			slotID = item.slotID,
			link = item.link,
			texture = item.texture,
			count = item.count,
		})
	end

	return items
end

--[[ ==================== ]]--
--[[ Display Logic          ]]--
--[[ ==================== ]]--

function MethlBags_UpdateDisplay()
	local items

	if methlBags_showingBank then
		items = MethlBags_CollectBankItems()
	else
		items = MethlBags_CollectInventoryItems()
	end

	-- Apply sorting
	if methlBags_sortMode ~= METHLBAGS_NOSORT then
		items = MethlBags_SortItems(items, methlBags_sortMode)
	end

	local cols = MethlBagsSets.cols or DEFAULT_COLS
	local space = DEFAULT_SPACING
	local totalItems = table.getn(items)

	-- Create/update item buttons
	for i = 1, totalItems do
		local item = items[i]
		local button = getglobal("MethlBagsItem" .. i)

		if not button then
			button = MethlBags_CreateItemButton(i)
		end

		-- Store bag/slot reference for click handling
		button.bagID = item.bagID
		button.slotID = item.slotID
		button.itemLink = item.link
		button.isBank = methlBags_showingBank
		button.isCached = methlBags_showingBank and not methlBags_atBank

		-- Set texture
		SetItemButtonTexture(button, item.texture)
		SetItemButtonCount(button, item.count)

		-- Quality border coloring
		MethlBags_UpdateItemBorder(button, item.link)

		-- Cooldown
		MethlBags_UpdateItemCooldown(button, item.bagID, item.slotID)

		-- Position
		local row = math.floor((i - 1) / cols)
		local col = math.mod(i - 1, cols)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", "MethlBagsFrameItems", "TOPLEFT",
			col * (ITEM_SIZE + space),
			-row * (ITEM_SIZE + space))
		button:Show()
	end

	-- Hide unused buttons
	local idx = totalItems + 1
	while getglobal("MethlBagsItem" .. idx) do
		getglobal("MethlBagsItem" .. idx):Hide()
		idx = idx + 1
	end

	-- Resize frame
	local rows = math.ceil(totalItems / cols)
	if rows < 1 then rows = 1 end
	local frameWidth = cols * (ITEM_SIZE + space) - space + 20
	local frameHeight = rows * (ITEM_SIZE + space) - space + 80  -- room for title bar and bottom buttons

	MethlBagsFrame:SetWidth(frameWidth)
	MethlBagsFrame:SetHeight(frameHeight)

	-- Update money
	MethlBags_UpdateMoney()
end

--[[ ==================== ]]--
--[[ Item Button Creation   ]]--
--[[ ==================== ]]--

function MethlBags_CreateItemButton(index)
	local button = CreateFrame("Button", "MethlBagsItem" .. index, MethlBagsFrameItems, "MethlBagsItemTemplate")
	button:SetID(index)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	-- SplitStack support for shift-click splitting
	button.SplitStack = function(btn, split)
		if btn.bagID and btn.slotID and not btn.isCached then
			SplitContainerItem(btn.bagID, btn.slotID, split)
		end
	end

	button:SetScript("OnClick", MethlBags_ItemOnClick)
	button:SetScript("OnEnter", MethlBags_ItemOnEnter)
	button:SetScript("OnLeave", MethlBags_ItemOnLeave)
	button:SetScript("OnDragStart", MethlBags_ItemOnDragStart)
	button:SetScript("OnReceiveDrag", function() MethlBags_ItemOnClick("LeftButton") end)

	return button
end

--[[ ==================== ]]--
--[[ Item Button Handlers   ]]--
--[[ ==================== ]]--

function MethlBags_ItemOnClick(mouseButton)
	if this.isCached then
		-- Cached items: only allow shift-click to link in chat
		if this.itemLink and IsShiftKeyDown() and mouseButton == "LeftButton" then
			if ChatFrameEditBox:IsVisible() then
				ChatFrameEditBox:Insert(this.itemLink)
			end
		end
		return
	end

	if not (this.bagID and this.slotID) then return end

	if this.isBank and this.bagID == -1 then
		-- Bank main slots use inventory API
		local invSlot = BankButtonIDToInvSlotID(this.slotID)
		if mouseButton == "LeftButton" then
			if IsShiftKeyDown() then
				if ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(GetInventoryItemLink("player", invSlot))
				end
			elseif IsControlKeyDown() then
				DressUpItemLink(GetInventoryItemLink("player", invSlot))
			else
				PickupInventoryItem(invSlot)
			end
		else
			UseInventoryItem(invSlot)
		end
	else
		-- Normal container items
		if mouseButton == "LeftButton" then
			if IsShiftKeyDown() then
				if ChatFrameEditBox:IsVisible() then
					ChatFrameEditBox:Insert(GetContainerItemLink(this.bagID, this.slotID))
				elseif this.itemLink then
					local _, count = GetContainerItemInfo(this.bagID, this.slotID)
					if count and count > 1 then
						OpenStackSplitFrame(count, this, "BOTTOMRIGHT", "TOPRIGHT")
					end
				end
			elseif IsControlKeyDown() then
				DressUpItemLink(GetContainerItemLink(this.bagID, this.slotID))
			else
				PickupContainerItem(this.bagID, this.slotID)
			end
		else
			UseContainerItem(this.bagID, this.slotID)
		end
	end
end

function MethlBags_ItemOnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")

	if this.isCached then
		if this.itemLink then
			GameTooltip:SetHyperlink(this.itemLink)
		end
	elseif this.bagID and this.slotID then
		if this.isBank and this.bagID == -1 then
			GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(this.slotID))
		else
			GameTooltip:SetBagItem(this.bagID, this.slotID)
		end
	end

	GameTooltip:Show()
end

function MethlBags_ItemOnLeave()
	GameTooltip:Hide()
	ResetCursor()
end

function MethlBags_ItemOnDragStart()
	if this.isCached then return end

	if this.isBank and this.bagID == -1 then
		PickupInventoryItem(BankButtonIDToInvSlotID(this.slotID))
	elseif this.bagID and this.slotID then
		PickupContainerItem(this.bagID, this.slotID)
	end
end

--[[ ==================== ]]--
--[[ Item Border Coloring   ]]--
--[[ ==================== ]]--

function MethlBags_UpdateItemBorder(button, link)
	local border = getglobal(button:GetName() .. "Border")
	if not border then return end

	if link then
		local _, _, hexString = string.find(link, "|cff(%x+)|H")
		if hexString then
			local red = tonumber(string.sub(hexString, 1, 2), 16) / 256
			local green = tonumber(string.sub(hexString, 3, 4), 16) / 256
			local blue = tonumber(string.sub(hexString, 5, 6), 16) / 256
			-- Only show colored border for uncommon+ items (not gray/white)
			if red ~= green or red ~= blue then
				border:SetVertexColor(red, green, blue, 0.6)
				border:Show()
				return
			end
		end
	end

	border:Hide()
end

--[[ ==================== ]]--
--[[ Cooldown Updates       ]]--
--[[ ==================== ]]--

function MethlBags_UpdateItemCooldown(button, bagID, slotID)
	local cooldown = getglobal(button:GetName() .. "Cooldown")
	if not cooldown then return end

	if button.isCached or not button.itemLink then
		CooldownFrame_SetTimer(cooldown, 0, 0, 0)
		return
	end

	if bagID == -1 then
		-- No cooldown API for bank main slots in vanilla
		CooldownFrame_SetTimer(cooldown, 0, 0, 0)
	else
		local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
		CooldownFrame_SetTimer(cooldown, start, duration, enable)
	end
end

--[[ ==================== ]]--
--[[ Lock Updates           ]]--
--[[ ==================== ]]--

function MethlBags_UpdateLocks()
	local idx = 1
	local button = getglobal("MethlBagsItem" .. idx)
	while button and button:IsVisible() do
		if not button.isCached and button.bagID and button.slotID then
			if button.isBank and button.bagID == -1 then
				local locked = IsInventoryItemLocked(BankButtonIDToInvSlotID(button.slotID))
				SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
			else
				local _, _, locked = GetContainerItemInfo(button.bagID, button.slotID)
				SetItemButtonDesaturated(button, locked, 0.5, 0.5, 0.5)
			end
		end
		idx = idx + 1
		button = getglobal("MethlBagsItem" .. idx)
	end
end

--[[ ==================== ]]--
--[[ Money Display          ]]--
--[[ ==================== ]]--

function MethlBags_UpdateMoney()
	if MethlBagsMoneyFrame then
		MoneyFrame_Update("MethlBagsMoneyFrame", GetMoney())
	end
end

--[[ ==================== ]]--
--[[ Frame Movement         ]]--
--[[ ==================== ]]--

function MethlBags_StartMoving()
	MethlBagsFrame:StartMoving()
end

function MethlBags_StopMoving()
	MethlBagsFrame:StopMovingOrSizing()
end

--[[ ==================== ]]--
--[[ Slash Commands         ]]--
--[[ ==================== ]]--

SLASH_METHLBAGS1 = "/mb"
SLASH_METHLBAGS2 = "/methlbags"
SlashCmdList["METHLBAGS"] = function(msg)
	if msg == "bank" then
		if not MethlBagsFrame:IsVisible() then
			MethlBags_Show()
		end
		if not methlBags_showingBank then
			MethlBags_ToggleBank()
		end
	elseif msg == "sort" then
		MethlBags_ToggleSort()
	elseif msg == "help" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffMethlBags commands:|r")
		DEFAULT_CHAT_FRAME:AddMessage("  /mb - Toggle inventory")
		DEFAULT_CHAT_FRAME:AddMessage("  /mb bank - Show bank")
		DEFAULT_CHAT_FRAME:AddMessage("  /mb sort - Cycle sort mode")
		DEFAULT_CHAT_FRAME:AddMessage("  /mb help - Show this help")
	else
		MethlBags_Toggle()
	end
end
