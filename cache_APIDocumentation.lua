local a_name, a_env = ...
if not a_env.load_this then return end

local current_build = select(4, GetBuildInfo())

local function find_val(where, subkey, subval)
   for key, val in pairs(where) do
      if val[subkey] == subval then return(val) end
   end
end

function a_env.GetFunctionFromAPIDocumentation(system_namespace, function_name)
   local data_key = system_namespace .. '.' .. function_name
   SV_SR13LazyDataCache = SV_SR13LazyDataCache or {}
   local cache_api_doc = SV_SR13LazyDataCache and SV_SR13LazyDataCache.APIDocumentation
   if not cache_api_doc then
      cache_api_doc = {}
      SV_SR13LazyDataCache.APIDocumentation = cache_api_doc
   end
   if cache_api_doc.cache_build ~= current_build then
      wipe(cache_api_doc)
      cache_api_doc.cache_build = current_build
   end

   local function_data = cache_api_doc[data_key]
   if function_data then return function_data end

   C_AddOns.LoadAddOn("Blizzard_APIDocumentationGenerated")

   local system_data = find_val(APIDocumentation.systems, "Namespace", system_namespace)
   function_data = find_val(system_data.Functions, "Name", function_name)
   cache_api_doc[data_key] = function_data
   return function_data
end

-- TODO: make sure that cache loads in time - or save it to static file
-- /dump GetFunctionFromAPIDocumentation("C_Item", "GetItemInfo")
