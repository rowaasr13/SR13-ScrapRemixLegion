local a_name, a_env = ...
if not a_env then a_env = { load_this = true } end -- for testing outside WoW
if not a_env.load_this then return end

-- TODO: get it from -Lib
local function array_add(array_dest, array2)
   local array_size = #array_dest
   for idx = 1, #array2 do
      array_dest[array_size + idx] = array2[idx]
   end

   return array_dest
end

function a_env.MakeGettersFromMultiReturnFunction(function_or_adapter, symbolic_key, returns, template)
   local func_uniq_token = tostring(function_or_adapter) -- depends on tostring returning uniq address
   local returns_list = {}
   local cache_keys_list = {}
   for idx = 1, #returns do
      returns_list[idx] = returns[idx].Name
      cache_keys_list[idx] = {
         symbolic_key ..    '|' .. idx,
         symbolic_key ..    '|' .. returns_list[idx],
         func_uniq_token .. '|' .. idx,
         func_uniq_token .. '|' .. returns_list[idx],
      }
   end

   local code_pieces = {
      'local function_or_adapter = ...\n',
      'return function(obj)\n',
      'local ', table.concat(returns_list, ', '), " = function_or_adapter(obj)\n",
   }

   for idx = 1, #returns_list do
      for key_idx = 1, #cache_keys_list[idx] do
         code_pieces[#code_pieces+1] = 'obj["' .. cache_keys_list[idx][key_idx] .. '"] = ' .. returns_list[idx] .. "\n"
      end
   end

   code_pieces[#code_pieces+1] = 'obj["'.. func_uniq_token ..'|call_completed"] = true\n'

   code_pieces[#code_pieces+1] = "return "
   code_pieces[#code_pieces+1] = "<PLACEHOLDER FOR RETURN VALUE>"
   local idx_return_value_placeholder = #code_pieces
   code_pieces[#code_pieces+1] = "\n"

   code_pieces[#code_pieces+1] = "end\n"

   for idx = 1, #returns_list do
      code_pieces[idx_return_value_placeholder] = returns_list[idx]
      local code =  table.concat(code_pieces, '')
      -- print("code start", idx) print(code) print("code end", idx)
      local getter = loadstring(code)(function_or_adapter)
      for key_idx = 1, #cache_keys_list[idx] do
         template[cache_keys_list[idx][key_idx]] = getter
      end
   end
end

return a_env
