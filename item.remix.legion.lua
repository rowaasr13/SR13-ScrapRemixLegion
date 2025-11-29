local a_name, a_env = ...
if not a_env.load_this then return end

local lazy_table = a_env.lazy_table

local CACHE_ALL = lazy_table.constants.CACHE.ALL
local lazy_item_template = a_env.lazy_item_template
local MixInLazyItem = a_env.MixInLazyItem
local CreateLazyItemFromBagAndSlot = a_env.CreateLazyItemFromBagAndSlot

-- /run TESTITEM=CreateLazyItemFromBagAndSlot(0, 1); print(TESTITEM.RemixLegionDuplicateKey)

local is_accessory = {
   INVTYPE_NECK = true,
   INVTYPE_FINGER = true,
   INVTYPE_TRINKET = true,
}
local is_cosmetic = {
   INVTYPE_BODY = true, -- Shirt
   INVTYPE_TABARD = true,
}
local possible_stats = {
   "STAT_CRITICAL_STRIKE",
   "STAT_MASTERY",
   "STAT_HASTE",
   "STAT_AVOIDANCE",
   "STAT_SPEED",
   "STAT_LIFESTEAL", -- Leech
}
local found_stats = {}
lazy_item_template.RemixLegionDuplicateKey = function(tbl, key)
   local itemEquipLoc = tbl.itemEquipLocNormalized

   if is_cosmetic[itemEquipLoc] then return CACHE_ALL, false end

   if is_accessory[itemEquipLoc] then
      return CACHE_ALL,
         itemEquipLoc .. ',' ..
         tbl["C_Item.GetDetailedItemLevelInfo|actualItemLevel"] .. ',' ..
         tbl[tbl.GetItemID]
   end

   local classID = tbl["C_Item.GetItemInfoInstant|classID"]
   if classID == Enum.ItemClass.Armor then
      local lines = tbl.tooltipData.lines
      wipe(found_stats)
      for idx = 2, #lines do
         local line = lines[idx]
         if line.type == 0 then
            for stat_idx = 1, #possible_stats do repeat
               local stat = possible_stats[stat_idx]
               if line.leftText and string.find(line.leftText, _G[stat]) then
                  found_stats[#found_stats + 1] = stat
                  break
               end
            until true end
         end
      end

      return CACHE_ALL,
         itemEquipLoc .. ',' ..
         tbl["C_Item.GetDetailedItemLevelInfo|actualItemLevel"] .. ',' ..
         table.concat(found_stats, ',')
   end

   return CACHE_ALL, false
end

local max_ilevel = {}
_GGmax_ilevel = max_ilevel
local function RememberAcessoryMaxLevel(tbl, key)
   local itemEquipLoc = tbl.itemEquipLocNormalized
   if not is_accessory[itemEquipLoc] then return CACHE_ALL, false end

   local key = tbl[tbl.GetItemID]
   local current_level = (max_ilevel[key] or 0)
   local new_level = tbl["C_Item.GetDetailedItemLevelInfo|actualItemLevel"]

   if new_level > current_level then
      max_ilevel[key] = new_level
      return nil, new_level
   else
      return nil, current_level
   end
end

local function RememberArmorMaxLevel(tbl, key)
   local itemEquipLoc = tbl.itemEquipLocNormalized
   if is_accessory[itemEquipLoc] then return CACHE_ALL, false end
   if tbl["C_Item.GetItemInfoInstant|classID"] ~= Enum.ItemClass.Armor then return CACHE_ALL, false end

   local key = itemEquipLoc
   local current_level = (max_ilevel[key] or 0)
   local new_level = tbl["C_Item.GetDetailedItemLevelInfo|actualItemLevel"]

   if tbl.debug_print then print("key, current_level, new_level", key, current_level, new_level) end

   if new_level > current_level then
      max_ilevel[key] = new_level
      return nil, new_level
   else
      return nil, current_level
   end
end

local function equal_prop(tbl1, tbl2, prop)
   if not tbl1 then return end
   if not tbl2 then return end
   return tbl1[prop] == tbl2[prop]
end

local SPELL_ID_UNRAVELING_SANDS = 436524 -- It changes for some reason? By zone? Find Zone Ability that has same name or icon.
local function GetCurrentUnravelingSandsSpellID()
   -- name
   local unraveling_info = C_Spell.GetSpellInfo(SPELL_ID_UNRAVELING_SANDS)
   if not unraveling_info then return end

   local zone_abilities = C_ZoneAbility.GetActiveAbilities()
   if not zone_abilities then return end

   for idx = 1, #zone_abilities do repeat
      local zone_ability_spell_id = zone_abilities[idx].spellID
      if not zone_ability_spell_id then break end

      local zone_ability_spell_info = C_Spell.GetSpellInfo(zone_ability_spell_id)
      if not zone_ability_spell_info then break end

      if equal_prop(unraveling_info, zone_ability_spell_info, 'name') then return zone_ability_spell_id end
      if equal_prop(unraveling_info, zone_ability_spell_info, 'iconID') then return zone_ability_spell_id end
   until true end
end

local function ClickMachineScrap(added_scrap)
   if added_scrap > 0 and OOCDo then return OOCDo.ClickButton(ScrappingMachineFrame.ScrapButton) end
end

local function NoOp() end

-- /run _G["SR13-LazyDataCache"].ScrapRemixLegion({ debug_print = true, debug_itemid = { [246205] = true }, })
-- /run _G["SR13-ScrapRemixLegion"].ScrapRemixLegion({ debug_print = true })
local uniq_keys = {}
local items = {}
local function ScrapRemixLegion(args)
   local debug_print = args and args.debug_print
   local reverse = args and args.reverse
   local scrap = args and args.scrap
   local reverse = args and args.reverse

   -- defaults
   if scrap == nil then scrap = true end

   local scrap_action
   if scrap then scrap_action = ClickMachineScrap else scrap_action = NoOp end

   if not (ItemButtonUtil.GetItemContext() == ItemButtonUtil.ItemContextEnum.Scrapping) then
      if OOCDo then
         local speed = GetUnitSpeed("player")
         if speed ~= 0 then return end

         local spell_id = GetCurrentUnravelingSandsSpellID()
         if not spell_id then return end

         local cd = C_Spell.GetSpellCooldown(spell_id)
         if (not (cd and cd.startTime == 0)) then return end

         OOCDo.CastByID(spell_id)
      end

      return
   end

   local scrap_buttons = ScrappingMachineFrame.ItemSlots.scrapButtons
   if C_ScrappingMachineUI.HasScrappableItems() then
      for scrap_button in scrap_buttons:EnumerateActive() do
         C_ScrappingMachineUI.RemoveItemToScrap(scrap_button.SlotNumber)
      end
   end
   local scrap_buttons_num = scrap_buttons:GetNumActive()
   local added_scrap = 0

   wipe(uniq_keys)
   wipe(max_ilevel)
   wipe(items)

   -- Remember equipment
   for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
      local item = MixInLazyItem(Item:CreateFromEquipmentSlot(slot))
      local key = item.RemixLegionDuplicateKey
      local max_level = item[RememberAcessoryMaxLevel]
      local max_level = item[RememberArmorMaxLevel]
      uniq_keys[key] = 'eq,' .. slot
      if debug_print then print("eq (slot, key)", slot, key, item[RememberArmorMaxLevel]) end
   end

   -- Remember max ilevels from all bags in advance
   local bag_first, bag_last, bag_inc = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES, 1
   if reverse then bag_first, bag_last, bag_inc = bag_last, bag_first, -1 end
   for bag = bag_first, bag_last, bag_inc do
      local slot_first, slot_last, slot_inc = 1, ContainerFrame_GetContainerNumSlots(bag), 1
      if reverse then slot_first, slot_last, slot_inc = slot_last, slot_first, -1 end
      for slot = slot_first, slot_last, slot_inc do
         local item = CreateLazyItemFromBagAndSlot(bag, slot)
         local max_level = item[RememberAcessoryMaxLevel]
         local max_level = item[RememberArmorMaxLevel]
         items[bag .. ',' .. slot] = item
      end
   end

   -- Scan for scrap
   for bag = bag_first, bag_last, bag_inc do
      local slot_first, slot_last, slot_inc = 1, ContainerFrame_GetContainerNumSlots(bag), 1
      if reverse then slot_first, slot_last, slot_inc = slot_last, slot_first, -1 end
      for slot = slot_first, slot_last, slot_inc do
         local item = items[bag .. ',' .. slot] -- reuse what we already got in previous scans
         local key = item.RemixLegionDuplicateKey
         if debug_print then if bag == 0 and (slot == 1 or slot == 2) then
            item.debug_print = true
            print("compare_debug", bag, slot, item[ItemMixin.GetItemLink], key)
            local max_level = item[RememberAcessoryMaxLevel] or item[RememberArmorMaxLevel]
            local current_item_level = item["C_Item.GetDetailedItemLevelInfo|actualItemLevel"]
            print("max, current", max_level, current_item_level)
         end end
         if debug_print then
            if (args and args.debug_itemid and args.debug_itemid[item[item.GetItemID]]) then print("debug_true", item[item.GetItemID]) item.debug_print = true end
         end
         if key then
            if uniq_keys[key] then
               if debug_print then print("dup", bag, slot, item[ItemMixin.GetItemLink], "was", uniq_keys[key]) end
               C_Container.UseContainerItem(bag, slot)
               added_scrap = added_scrap + 1
            else
               uniq_keys[key] = bag .. ',' .. slot
            end
         end

         local max_level = item[RememberAcessoryMaxLevel] or item[RememberArmorMaxLevel]
         local current_item_level = item["C_Item.GetDetailedItemLevelInfo|actualItemLevel"]
         if current_item_level and max_level and (current_item_level < max_level) then
            if debug_print then print("lowilvl", bag, slot, item[ItemMixin.GetItemLink], "bestilvl", max_level) end
            C_Container.UseContainerItem(bag, slot)
            added_scrap = added_scrap + 1
         end

         if added_scrap >= scrap_buttons_num then return scrap_action(added_scrap) end
      end
   end
   return scrap_action(added_scrap)
end
_G[a_name] = _G[a_name] or {} _G[a_name].ScrapRemixLegion = ScrapRemixLegion

--[[
   self.macroBase = 0;
   self.macroMax = MAX_ACCOUNT_MACROS;
   self.macroBase = MAX_ACCOUNT_MACROS;
   self.macroMax = MAX_CHARACTER_MACROS;
]]

local function FindOurMacro()
   for idx = 0, MAX_CHARACTER_MACROS do -- search both global and character
      local name, icon, body = GetMacroInfo(macro)
      if body then
         if string.match(body, 'ScrapRemixLegion') then return idx end
      end
   end
end

-- /run _G["SR13-ScrapRemixLegion"].CreateMacro()
local function CreateOurMacro()
   if FindOurMacro() then return end

   local name = "ScrapRemixLegion"
   local spell_info = C_Spell.GetSpellInfo(SPELL_ID_UNRAVELING_SANDS)
   local icon = spell_info.iconID
   local body =
      ("/run _G[%q].ScrapRemixLegion({})"):format(a_name) .. '\n/click OOCDo LeftButton 1\n/stopmacro\n/run --KEEP THIS LINE\n/cast ' .. spell_info.name
   local per_character = false
   CreateMacro(name, icon, body, per_character)
end
_G[a_name] = _G[a_name] or {} _G[a_name].CreateMacro = CreateOurMacro
