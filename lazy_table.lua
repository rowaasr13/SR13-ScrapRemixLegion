local a_name, a_env = ...

local constants = {
   TEMPLATE = {},
   CACHE_STRATEGY = {},
   CACHE = {
      ALL = {}, -- except nil, obviously
      TRUTHY = {}, -- Lua definiteon of truthy
      FALSY = {},
      NON_EMPRY_STR = {}, -- something that is not nil and not ''
   },
}

local TEMPLATE = constants.TEMPLATE
local CACHE = constants.CACHE
local CACHE_STRATEGY = constants.CACHE_STRATEGY
local ALL = CACHE.ALL
local TRUTHY = CACHE.TRUTHY
local FALSY = CACHE.FALSY
local NON_EMPRY_STR = CACHE.NON_EMPRY_STR
local CACHE_ALL = ALL

local function lazy_table_get(tbl, key)
   local template = tbl[TEMPLATE]
   local debug_logger
   if template then debug_logger = template.debug_logger end
   if debug_logger then debug_logger:print("lazy_table_get: (tbl, key)", tbl, key) end
   if debug_logger then debug_logger:print("lazy_table_get: TEMPLATE found") end
   local getter, key2
   local key_type = type(key)
   if key_type == "function" then
      getter = key
   else
      if template then
         getter = template[key]
         key_type = type(getter)
         if debug_logger then debug_logger:print("lazy_table_get: key in TEMPLATE", getter, key_type) end
         if key_type == "function" then
            key2 = getter
         end
      end
   end

   -- Neither meta.__index key nor template key were functions:
   -- just copy value into table verbatim and return it.
   if key_type ~= "function" then
      if getter then rawset(tbl, key, getter) end
      return getter
   end

   local cache_strategy, new_val = getter(tbl, key)
   -- getter returned only single value
   if not CACHE[cache_strategy] then
      if new_val == nil then
         new_val = cache_strategy
      end

      -- Is there default cache stategy for this (possible 3rd party) getter?
      local cache_strategies = template and template[CACHE_STRATEGY]
      cache_strategy = cache_strategies and cache_strategies[getter]
   end

   -- Write value to be cached to table according to cache strategy
   local cache_approved
   if (cache_strategy == ALL) and (new_val ~= nil) then
      cache_approved = true
   elseif (cache_strategy == TRUTHY) and (val) then
      cache_approved = true
   elseif (cache_strategy == FALSY) and (not val) then
      cache_approved = true
   elseif (cache_strategy == NON_EMPRY_STR) and (val ~= nil and val ~= '') then
      cache_approved = true
   end
   if cache_approved then
      rawset(tbl, key, new_val)
      if key2 ~= nil then rawset(tbl, key2, new_val) end
   end

   return new_val
end

-- If the VALUE written to table is a function, write it into TEMPLATE storage for KEY instead
local function lazy_table_set_func_to_getter(tbl, key, val)
   -- print("__newindex", tbl, key, val)
   if type(val) ~= "function" then
      return rawset(tbl, key, val)
   end

   local template = tbl[TEMPLATE]
   if not template then template = {} tbl[TEMPLATE] = template end
   template[key] = val
end

-- W/o magical convertion of functions to getters
local lazy_table_meta_only_getter = {
   __index = lazy_table_get,
}

local function lazy_table_vivify_all(tbl)
   local template = tbl[TEMPLATE]
   if not template then return end

   for key in pairs(template) do local vivified = tbl[key] end
end

local export = {
   constants = constants,
   lazy_table_meta_only_getter = lazy_table_meta_only_getter,
   lazy_table_vivify_all = lazy_table_vivify_all,
}

local function export_to(tbl, export)
  if not tbl.lazy_table then tbl.lazy_table = {} end
  for key, val in pairs(export) do tbl.lazy_table[key] = val end
end

if a_env and a_env.export then export_to(a_env.export, export) end
if a_env and a_env.export_internal then export_to(a_env.export_internal, export) end
return export
