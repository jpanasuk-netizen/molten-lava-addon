function (self, unitId, unitFrame, envTable, modTable)
 -- ============================================
 -- BigJ Combo UI - OPTIMIZED VERSION
 -- ============================================
 
 if _G.BigJ_StarBar_Final then
 _G.BigJ_StarBar_Final:Hide()
 _G.BigJ_StarBar_Final:SetScript("OnUpdate", nil)
 _G.BigJ_StarBar_Final = nil
 end
 
 local HOLY_POWER = Enum.PowerType.HolyPower
 local TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
 local lastSoundTime = 0
 local lastUpdate = 0
 local UPDATE_INTERVAL = 1/30
 local currentPlate = nil
 local lastWakeTime = 0
 local lastPower = 0
 
 local sin = math.sin
 local GENERATORS = { [35395]=true, [406647]=true, [406648]=true, [184575]=true, [20271]=true, [24275]=true, [255937]=true, [304971]=true, [383385]=true }
 
 local SOUND_ID = 567455
 
 -- FRAME SETUP
 local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
 bar:SetSize(250, 60)
 bar.blocks = {}
 
 for i = 1, 5 do
 local s = CreateFrame("Frame", nil, bar)
 s:SetSize(30, 30)
 s:SetPoint("LEFT", bar, "LEFT", (i-1) * 38, 0)
 
 local sh = s:CreateTexture(nil, "BACKGROUND")
 sh:SetTexture(TEX)
 sh:SetTexCoord(0, 0.25, 0, 0.25)
 sh:SetAllPoints(s)
 
 local co = s:CreateTexture(nil, "ARTWORK")
 co:SetTexture(TEX)
 co:SetTexCoord(0, 0.25, 0, 0.25)
 co:SetAllPoints(s)
 
 local gl = s:CreateTexture(nil, "OVERLAY")
 gl:SetTexture(TEX)
 gl:SetTexCoord(0, 0.25, 0, 0.25)
 gl:SetBlendMode("ADD")
 gl:SetAllPoints(s)
 
 s.sh, s.co, s.gl = sh, co, gl
 bar.blocks[i] = s
 end
 
 -- EVENT HANDLING
 local eventFrame = CreateFrame("Frame")
 eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
 eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
 eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
 
 eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
 if event == "PLAYER_TARGET_CHANGED" then
 currentPlate = C_NamePlate.GetNamePlateForUnit("target")
 if currentPlate then
 bar:SetParent(currentPlate)
 bar:ClearAllPoints()
 bar:SetPoint("BOTTOM", currentPlate, "TOP", 0, 10)
 else
 bar:SetParent(UIParent)
 bar:ClearAllPoints()
 bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
 end
 return
 end
 
 if arg1 ~= "player" then return end
 local now = GetTime()
 
 if event == "UNIT_SPELLCAST_SUCCEEDED" and arg3 == 255937 then
 lastWakeTime = now
 end
 
 if UnitPower("player", HOLY_POWER) == 5 and (now - lastSoundTime > 0.7) then
 if event == "UNIT_POWER_UPDATE" and arg2 == "HOLY_POWER" then
 PlaySoundFile(SOUND_ID, "SFX")
 lastSoundTime = now
 elseif event == "UNIT_SPELLCAST_SUCCEEDED" and GENERATORS[arg3] then
 PlaySoundFile(SOUND_ID, "SFX")
 lastSoundTime = now
 end
 end
 end)
 
 -- Initial anchor
 currentPlate = C_NamePlate.GetNamePlateForUnit("target")
 if currentPlate then
 bar:SetParent(currentPlate)
 bar:SetPoint("BOTTOM", currentPlate, "TOP", 0, 10)
 else
 bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
 end
 
 -- PERFORMANCE LOOP (Optimized)
 bar:SetScript("OnUpdate", function(_, elapsed)
 lastUpdate = lastUpdate + elapsed
 if lastUpdate < UPDATE_INTERVAL then return end
 lastUpdate = 0
 
 local power = UnitPower("player", HOLY_POWER) or 0
 local now = GetTime()
 local inBurst = (now - lastWakeTime) < 35
 
 -- Pre-calculate time values
 local t1 = now * 3
 local t2 = now * 11
 local t3 = now * 2.2
 local t4 = now * 4.5
 
 local baseScale = (power >= 5 and 1.58) or (power >= 3 and 1.25) or 1
 local scale = baseScale + (sin(t1) * 0.09)
 
 -- Gain feedback
 local gainPop = (power > lastPower) and 0.22 or 0
 lastPower = power
 
 for i = 1, 5 do
 local b = bar.blocks[i]
 local active = i <= power
 local depth = sin(t1 + (i * 0.75)) * 0.12
 
 local finalScale = scale + depth
 if active and i == power and gainPop > 0 then
 finalScale = finalScale + gainPop
 end
 
 b:SetScale(finalScale)
 
 if active then
 if power >= 5 then
 local burstMult = inBurst and 1.2 or 1
 b.co:SetRotation(t4 + (i * 0.25))
 b.co:SetVertexColor(0.72, 0.90, 1)
 
 -- Subtle Shine Sweep
 local shine = sin((now * 5.8) + (i * 1.15)) * 0.42 + 0.58
 b.gl:SetAlpha((0.36 + (sin(t2 + (i * 0.5)) * 0.52)) * burstMult * shine)
 b.sh:SetAlpha(0.38)
 b.gl:SetVertexColor(1, 1, 1)
 else
 local progress = i / 5
 b.co:SetRotation(sin(t3 + (i * 0.6)) * 0.6)
 b.co:SetVertexColor(0.1 + (progress * 0.1), 0.58 + (progress * 0.22), 1)
 b.gl:SetAlpha(0.6)
 b.sh:SetAlpha(0.28)
 b.gl:SetVertexColor(1, 1, 1)
 end
 else
 b.sh:SetAlpha(0.06)
 b.co:SetVertexColor(0.15, 0.15, 0.15)
 b.gl:SetAlpha(0)
 end
 end
 end)
end
