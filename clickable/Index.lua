function Init()
  local env = aura_env
  local tooltipAnchors = {
    "ANCHOR_TOP",
    "ANCHOR_BOTTOM",
    "ANCHOR_RIGHT",
    "ANCHOR_LEFT",
    "ANCHOR_TOPRIGHT",
    "ANCHOR_TOPLEFT",
    "ANCHOR_BOTTOMRIGHT",
    "ANCHOR_BOTTOMLEFT",
  }
  local tooltipAnchor = tooltipAnchors[env.config.tooltipAnchor]


  local function ParseMacroNameAndRank(macroSpellFormat)
    local name, rank = macroSpellFormat:match("^([^%(]+)%(([^%)]+)%)$")
    if not name then
      name = macroSpellFormat
      rank = nil
    end
    return name:trim(), rank
  end

  local function GetSpellBookIndex(macroSpellFormat)
    local macroName, macroRank = ParseMacroNameAndRank(macroSpellFormat)

    for bookIndex = 1, MAX_SPELLS do
      local name, rank = GetSpellName(bookIndex, BOOKTYPE_SPELL)

      if not name then
        break
      end

      if name == macroName and (not macroRank or rank == macroRank) then
        return bookIndex
      end
    end
    return nil
  end

  local function GetItemIDByName(itemName)
    local itemID = nil

    for bag = 0, 4 do
      for slot = 1, GetContainerNumSlots(bag) do
        local link = GetContainerItemLink(bag, slot)

        if link then
          local id = tonumber(link:match("item:(%d+)"))

          if id and GetItemInfo(id) == itemName then
            itemID = id

            break
          end
        end
      end

      if itemID then
        break
      end
    end

    return itemID
  end

  local function IsItemID(input)
    return input:match("^item:%d+$") ~= nil
  end

  function env.UpdateButtonAndTexturePath(button)
    local macrotext = button:GetAttribute("macrotext")
    if not macrotext then return end

    local tooltipText = macrotext:match("#showtooltip%s+([^\n;]+)")
    if not tooltipText then
      button.spellOrItemName = nil
      return
    end

    local itemID

    if IsItemID(tooltipText) then
      itemID = tonumber(tooltipText:match("item:(%d+)"))
    else
      itemID = GetItemIDByName(tooltipText)
    end

    if itemID then
      local itemTexture = GetItemIcon("item:" .. itemID)

      env.texturePath = itemTexture
      button.spellOrItemName = itemID
      button.isItem = true

      return
    end

    local spellID = GetSpellBookIndex(tooltipText)
    local spellTexture = GetSpellTexture(tooltipText)

    if spellTexture and spellID then
      env.texturePath = spellTexture
      button.spellOrItemName = spellID
      button.isItem = false
      return
    end

    button.spellOrItemName = nil
    env.texturePath = "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  local button = env.clickableFrame

  if not button then
    button = CreateFrame(
      "Button",
      "SoltiClickableButton" .. env.id,
      env.region,
      "SecureActionButtonTemplate"
    )

    button:SetAllPoints()
    button:SetAttribute("type", "macro")

    button:SetScript(
      "OnEnter",
      function(self)
        if self.spellOrItemName then
          GameTooltip:SetOwner(self, tooltipAnchor)

          if self.isItem then
            GameTooltip:SetHyperlink("item:" .. self.spellOrItemName)
          else
            GameTooltip:SetSpell(self.spellOrItemName, BOOKTYPE_SPELL)
          end

          GameTooltip:Show()
        end
      end
    )

    button:SetScript(
      "OnLeave",
      function(self)
        GameTooltip:Hide()
      end
    )

    button:SetScript(
      "PostClick",
      function(self)
        env.UpdateButtonAndTexturePath(self)
      end
    )

    env.clickableFrame = button
  end

  local macroText = env.config.macrotext
  button:SetAttribute("macrotext", macroText)

  env.UpdateButtonAndTexturePath(button)
end

Init()
