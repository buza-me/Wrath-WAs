local function getCIDFromGUID(guid)
  return guid and tonumber(guid:sub(8, 12), 16) or 0
end
