local a_name, a_env = ...
if not a_env.load_this then return end

local lazy_table = (a_env.internal_export and a_env.internal_export.lazy_table) or _G["SR13-Lib"].lazy_table
a_env.lazy_table = lazy_table

local CACHE_ALL = lazy_table.constants.CACHE.ALL
local CACHE_NON_EMPRY_STR = lazy_table.constants.CACHE.NON_EMPRY_STR
local TEMPLATE = lazy_table.constants.TEMPLATE
local CACHE_STRATEGY = lazy_table.constants.CACHE_STRATEGY
local lazy_table_meta_only_getter = lazy_table.lazy_table_meta_only_getter
lazy_table_vivify_all = lazy_table.lazy_table_vivify_all

-- Reuses infrastructure from Item/ItemLocation mixins
-- Interface\AddOns\Blizzard_ObjectAPI\Mainline\Item.lua
-- Interface\AddOns\Blizzard_ObjectAPI\Mainline\ItemLocation.lua
--[[
   self.itemLocation = {
      self.bagID = nil;
      self.slotIndex = nil;
      self.equipmentSlotIndex = nil;
   }
   self.itemLink = nil;
   self.itemID = nil;
   self.itemGUID = nil;
]]
-- C_Item.GetItemGUID({ bagID = 1, slotIndex = 1 })
-- C_Item.IsCosmeticItem(
-- C_Item.IsItemBindToAccountUntilEquip
-- C_Item.IsItemGUIDInInventory
-- Item:CreateFromBagAndSlot(0, 1):GetItemLink() -- first item in backpack, top-left in Bagnon
-- /run TESTITEM=Item:CreateFromBagAndSlot(0, 1)
-- /run TESTITEM=Item:CreateFromBagAndSlot(0, 1); print(TEST_SELLPRICE(TESTITEM))

local lazy_item_template = {
   [CACHE_STRATEGY] = {
      [ItemMixin.GetItemLink] = CACHE_NON_EMPRY_STR,
      [ItemMixin.GetItemGUID] = CACHE_NON_EMPRY_STR,
      [ItemMixin.GetItemID] = CACHE_ALL,
   }
}
a_env.lazy_item_template = lazy_item_template

local function MixInLazyItem(mixed_item)
   mixed_item[TEMPLATE] = lazy_item_template
   return setmetatable(mixed_item, lazy_table_meta_only_getter)
end
a_env.MixInLazyItem = MixInLazyItem

local function CreateLazyItemFromBagAndSlot(bag, slot)
   return MixInLazyItem(Item:CreateFromBagAndSlot(bag, slot))
end
a_env.CreateLazyItemFromBagAndSlot = CreateLazyItemFromBagAndSlot

local function CreateLazyItemFromItemID(item_id)
   return MixInLazyItem(Item:CreateFromItemID(item_id))
end

local function MakeMixedItemToItemLinkAdapter(target_function)
   return function(mixed_item)
      local item_link = mixed_item[mixed_item.GetItemLink]
      if item_link then return target_function(item_link) end
   end
end

local function InstallAPIFunctionToTemplate(namespace, func_name, adapter_type, template)
   local api_func = _G[namespace][func_name]

   local adapter = api_func
   if adapter_type == "item_link" then
      adapter = MakeMixedItemToItemLinkAdapter(api_func)
   end

   local returns = a_env.GetFunctionFromAPIDocumentation(namespace, func_name).Returns
   local symbolic_name = namespace .. '.' .. func_name
   return a_env.MakeGettersFromMultiReturnFunction(adapter, symbolic_name, returns, template)
end

InstallAPIFunctionToTemplate("C_Item", "GetItemInfo", "item_link", lazy_item_template)
InstallAPIFunctionToTemplate("C_Item", "GetItemInfoInstant", "item_link", lazy_item_template)
InstallAPIFunctionToTemplate("C_Item", "GetDetailedItemLevelInfo", "item_link", lazy_item_template)

-- like GetItemInfoInstant|itemEquipLoc
-- but with some values normalized into one
local itemEquipLoc_normalization = {
   INVTYPE_ROBE = "INVTYPE_CHEST",
}
lazy_item_template.itemEquipLocNormalized = function(tbl)
   local itemEquipLoc = tbl["C_Item.GetItemInfoInstant|itemEquipLoc"]
   local normalized = itemEquipLoc_normalization[itemEquipLoc]
   return normalized or itemEquipLoc
end

lazy_item_template.tooltipData = function(tbl)
   local item_guid = tbl[tbl.GetItemGUID]
   if not item_guid then return end

   return CACHE_ALL, C_TooltipInfo.GetItemByGUID(item_guid)
end

-- Returns true if item is something that has visible appearance.
-- I.e. it is a Weapon or Armor, but is NOT NECK/FINGER/TRINKET
local INVTYPE_not_visible = {
   INVTYPE_NON_EQUIP_IGNORE = true,
   INVTYPE_NECK = true,
   INVTYPE_FINGER = true,
   INVTYPE_TRINKET = true,
}
lazy_item_template.IsVisibleEquipment = function(tbl, key)
   local classID = tbl["C_Item.GetItemInfoInstant|classID"]
   local is_wearable_equipment = (classID == Enum.ItemClass.Weapon) or (classID == Enum.ItemClass.Armor)
   if not is_wearable_equipment then return CACHE_ALL, false end

   local itemEquipLoc = tbl["C_Item.GetItemInfoInstant|itemEquipLoc"]
   if INVTYPE_not_visible[itemEquipLoc] then return CACHE_ALL, false end

   return CACHE_ALL, true
end

local function text_to_pattern(text)
   local pattern = string.gsub(text, '([()[%]%.])', '%%%1')
   return string.gsub(pattern, '%%s', '.-')
end

-- Returns true if item has "You may trade this item with players that were also eligible to loot..." timer
local BIND_TRADE_TIME_REMAINING_pattern = '^' .. text_to_pattern(BIND_TRADE_TIME_REMAINING)
lazy_item_template.HasTradeTimer = function(tbl, key)
   -- TODO: can EVER be true only for container item,
   -- return early or set in advance for non-container item
   local lines = tbl.tooltipData.lines
   local has = false

   for idx = 2, #lines do
      local line = lines[idx]
      local left_text = line.leftText
      if string.match(left_text, BIND_TRADE_TIME_REMAINING_pattern) then
         has = true
      end
   end

   tbl.HasTradeTimer = has
   return has
end

-- /run TESTITEM=_G["SR13-Lib"]["SR13-LazyDataCache"]["item"].CreateLazyItemFromBagAndSlot(0, 1); lazy_table_vivify_all(TESTITEM)
-- /run TESTITEM=_G["SR13-Lib"]["SR13-LazyDataCache"]["item"].CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM.HasTradeTimer)
-- /run TESTITEM.tooltipData.lines[14].leftColor = nil
-- /dump TESTITEM.tooltipData.lines[14]
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM["C_Item.GetItemInfo\124sellPrice"]); print(TESTITEM["C_Item.GetItemInfoInstant\124itemID"])
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM["C_Item.GetItemInfo\124sellPrice"]); print(TESTITEM["C_Item.GetItemInfoInstant\124classID"])
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM["C_Item.GetItemInfo\124sellPrice"]); print(TESTITEM["C_Item.GetItemInfoInstant\124itemEquipLoc"])
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM["C_Item.GetItemInfo\124sellPrice"]); print(TESTITEM.IsVisibleEquipment)
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM.itemGUID)
-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM.tooltipData)
-- /dump TESTITEM.tooltipData

-- /dump C_TooltipInfo.GetItemByGUID(TESTITEM.itemGUID)
-- /dump TESTITEM
-- /dump C_TooltipInfo.GetBagItem(0, 1)
-- local keys = {} for key in pairs(TESTITEM)



--[[
"C_Item.GetItemInfo|11"
"C_Item.GetItemInfo|sellPrice"
"function..addr|11"
"function..addr|sellPrice"
]]

-- Item:CreateFromBagAndSlot(0, 1):GetMultiReturn(adaptor_C_Item_GetItemInfo, "C_Item.GetItemInfo", 
-- ItemUtil.IteratePlayerInventoryAndEquipment
-- ItemUtil.IteratePlayerInventory(callback);
-- ItemUtil.IterateInventorySlots(INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED, callback);

local module_name = 'item'
local export = {
   lazy_item_template           = lazy_item_template,
   MixInLazyItem                = MixInLazyItem,
   CreateLazyItemFromBagAndSlot = CreateLazyItemFromBagAndSlot,
   CreateLazyItemFromItemID     = CreateLazyItemFromItemID,
}

if not _G["SR13-Lib"] then _G["SR13-Lib"] = {} end
if not _G["SR13-Lib"][a_name] then _G["SR13-Lib"][a_name] = {} end
if not _G["SR13-Lib"][a_name][module_name] then _G["SR13-Lib"][a_name][module_name] = {} end

local target = _G["SR13-Lib"][a_name][module_name]
for key, val in pairs(export) do
   target[key] = val
end
