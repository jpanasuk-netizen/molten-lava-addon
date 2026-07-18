function (self, unitId, unitFrame, envTable, modTable)
    -- One-time-build guard
    if _G.BigJ_StarBar_Final then return end

    print("[StarBar VERSION] v13.1 (build 25) -- MAX PERFORMANCE: Converted all object states, frame textures, and properties into flat local closure arrays. Zero hash-table overhead remaining.")

    --------------------------------------------------------------------
    -- Localize APIs (Blazing Fast Environment Upvalues)
    --------------------------------------------------------------------
    local GetTime             = GetTime
    local UnitPower           = UnitPower
    local GetNamePlateForUnit = C_NamePlate.GetNamePlateForUnit
    local PlaySound           = PlaySound
    local CreateFrame         = CreateFrame
    local UIParent            = UIParent

    --------------------------------------------------------------------
    -- Config
    --------------------------------------------------------------------
    local STAR_TEX  = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX = "Interface\\Cooldown\\star4"          
    local SOLID     = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower

    local DEBUG    = false      
    local SOUND_ON = true       
    local SND_FIVE = 162888

    local GENERATORS = {
        [35395]   = true, 
        [1227637] = true, 
        [20271]   = true, 
        [275779]  = true, 
        [184575]  = true, 
        [24275]   = true, 
        [1241288] = true, 
        [407480]  = true, 
        [198036]  = true, 
        [406647]  = true, 
    }

    local WAKE_OF_ASHES = 255937
    local AVENGING_WRATH_DURATION = 20   
    local DAWNLIGHTS_WINDOW = 12          
    local SPENDERS = {
        [85256]  = true, 
        [336872] = true, 
        [383328] = true, 
        [224239] = true, 
        [215661] = true, 
        [53600]  = true, 
        [85673]  = true, 
    }

    -- Hoisted math
    local sin, min, max = math.sin, math.min, math.max

    local BLOCK = 40
    local STEP  = 47
    local NUM   = 5
    local BAR_W = 250
    local STARTX = (BAR_W - (NUM - 1) * STEP) * 0.5

    local AVENGING_WRATH_ID = 31884
    local CRUSADE_ID = 231895   

    local SOUND_DEBUG = false   

    local function SafePlaySound(kit)
        if SOUND_ON and kit then
            local willPlay, handle = PlaySound(kit, "Master", false)
            if SOUND_DEBUG then
                print("[StarBar SOUND] PlaySound(" .. tostring(kit) .. ", Master, false) -> willPlay=" .. tostring(willPlay) .. " handle=" .. tostring(handle))
            end
        elseif SOUND_DEBUG then
            print("[StarBar SOUND] SafePlaySound skipped -- SOUND_ON=" .. tostring(SOUND_ON) .. " kit=" .. tostring(kit))
        end
    end

    --------------------------------------------------------------------
    -- Flat Upvalued State Registers (Zero Table Reading on Self/Bar)
    --------------------------------------------------------------------
    local state_dawnlightsLeft       = 0
    local state_dawnlightsExpire     = 0
    local state_wingsUntil           = 0
    local state_lastPower            = -1
    local state_pendingGeneratorPing = false
    local state_popImpulse           = 0
    local state_lastUpdate           = 0
    local state_lastDecrement        = 0
    local state_flash                = 0
    local state_gR, state_gG, state_gB = 1, 0.6, 0.2
    local state_auraA                = 0.10

    --------------------------------------------------------------------
    -- Parallel Structure Visual Arrays (Zero Object Lookups inside Loops)
    --------------------------------------------------------------------
    local block_frames  = {}
    local tex_bp        = {}
    local tex_ho        = {}
    local tex_hi        = {}
    local tex_co        = {}
    local tex_hot       = {}
    local tex_sp        = {}
    
    local prop_o7       = {}
    local prop_o9       = {}
    local prop_pp       = {}
    local prop_spin     = {0, 0, 0, 0, 0}
    local prop_curScale = {1, 1, 1, 1, 1}
    local prop_cR       = {1, 1, 1, 1, 1}
    local prop_cG       = {0.5, 0.5, 0.5, 0.5, 0.5}
    local prop_cB       = {0.1, 0.1, 0.1, 0.1, 0.1}
    local prop_hoA      = {0, 0, 0, 0, 0}
    local prop_hiA      = {0, 0, 0, 0, 0}
    local prop_hotA     = {0, 0, 0, 0, 0}
    local prop_spA      = {0, 0, 0, 0, 0}
    local prop_bpA      = {0.45, 0.45, 0.45, 0.45, 0.45}

    -- Instantiate Base Component
    local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
    bar:SetSize(BAR_W, 70)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel(100)
    bar.blocks = {} -- Kept clean for external API reflection only
    
    bar:Show()
    bar:SetAlpha(0)

    --------------------------------------------------------------------
    -- Backdrop Layering
    --------------------------------------------------------------------
    local bar_aura = bar:CreateTexture(nil, "BACKGROUND")
    bar_aura:SetTexture(SOLID)
    bar_aura:SetBlendMode("ADD")
    bar_aura:SetSize(BAR_W - 6, 26)
    bar_aura:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar_aura:SetVertexColor(state_gR, state_gG, state_gB)
    bar_aura:SetAlpha(0.06)

    local bar_spine = bar:CreateTexture(nil, "ARTWORK")
    bar_spine:SetTexture(SOLID)
    bar_spine:SetSize((NUM - 1) * STEP + BLOCK * 0.7, 3)
    bar_spine:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar_spine:SetVertexColor(state_gR, state_gG, state_gB)
    bar_spine:SetAlpha(0.22)

    --------------------------------------------------------------------
    -- Allocation & Array Linking Phase
    --------------------------------------------------------------------
    for i = 1, NUM do
        local s = CreateFrame("Frame", nil, bar)
        s:SetFrameLevel(bar:GetFrameLevel() + 2)
        s:SetSize(BLOCK, BLOCK)
        s:SetPoint("CENTER", bar, "LEFT", STARTX + (i - 1) * STEP, 0)

        prop_o7[i] = i * 0.7
        prop_o9[i] = i * 0.9
        prop_pp[i] = i / NUM

        local bp = s:CreateTexture(nil, "BACKGROUND")
        bp:SetTexture(STAR_TEX)
        bp:SetTexCoord(0, 0.25, 0, 0.25)
        bp:SetSize(BLOCK * 1.45, BLOCK * 1.45)
        bp:SetPoint("CENTER", s, "CENTER", 0, 0)
        bp:SetVertexColor(0.05, 0.04, 0.03)
        bp:SetAlpha(0.45)

        local ho = s:CreateTexture(nil, "BORDER")
        ho:SetTexture(STAR_TEX)
        ho:SetTexCoord(0, 0.25, 0, 0.25)
        ho:SetBlendMode("ADD")
        ho:SetSize(BLOCK * 1.95, BLOCK * 1.95)
        ho:SetPoint("CENTER", s, "CENTER", 0, 0)
        ho:SetAlpha(0)

        local hi = s:CreateTexture(nil, "ARTWORK")
        hi:SetTexture(STAR_TEX)
        hi:SetTexCoord(0, 0.25, 0, 0.25)
        hi:SetBlendMode("ADD")
        hi:SetSize(BLOCK * 1.3, BLOCK * 1.3)
        hi:SetPoint("CENTER", s, "CENTER", 0, 0)
        hi:SetAlpha(0)

        local co = s:CreateTexture(nil, "ARTWORK")
        co:SetTexture(STAR_TEX)
        co:SetTexCoord(0, 0.25, 0, 0.25)
        co:SetSize(BLOCK, BLOCK)
        co:SetPoint("CENTER", s, "CENTER", 0, 0)
        co:SetVertexColor(1, 0.5, 0.1)

        local hot = s:CreateTexture(nil, "OVERLAY")
        hot:SetTexture(STAR_TEX)
        hot:SetTexCoord(0, 0.25, 0, 0.25)
        hot:SetBlendMode("ADD")
        hot:SetSize(BLOCK * 0.55, BLOCK * 0.55)
        hot:SetPoint("CENTER", s, "CENTER", 0, 0)
        hot:SetVertexColor(1, 0.95, 0.65)
        hot:SetAlpha(0)

        local sp = s:CreateTexture(nil, "OVERLAY")
        sp:SetTexture(SPARK_TEX)
        sp:SetBlendMode("ADD")
        sp:SetSize(BLOCK * 1.25, BLOCK * 1.25)
        sp:SetPoint("CENTER", s, "CENTER", 0, 0)
        sp:SetVertexColor(1, 0.95, 0.8)
        sp:SetAlpha(0)

        block_frames[i] = s
        tex_bp[i], tex_ho[i], tex_hi[i], tex_co[i], tex_hot[i], tex_sp[i] = bp, ho, hi, co, hot, sp
        bar.blocks[i] = s
    end

    --------------------------------------------------------------------
    -- High-Performance Event Registration (Direct Register Access)
    --------------------------------------------------------------------
    local ef = CreateFrame("Frame", "BigJ_StarBar_EventFrame")
    ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if unit ~= "player" then return end
        local now = GetTime()

        if spellID == AVENGING_WRATH_ID or spellID == CRUSADE_ID then
            state_wingsUntil = now + AVENGING_WRATH_DURATION
        elseif spellID == WAKE_OF_ASHES then
            state_dawnlightsLeft = 3
            state_lastDecrement = now
            state_dawnlightsExpire = now + DAWNLIGHTS_WINDOW
        elseif SPENDERS[spellID] then
            if state_dawnlightsLeft > 0 and (now - state_lastDecrement) > 0.5 then
                state_dawnlightsLeft = state_dawnlightsLeft - 1
                state_lastDecrement = now
            end
        elseif GENERATORS[spellID] then
            state_pendingGeneratorPing = true
        end
    end)

    --------------------------------------------------------------------
    -- Zero-Overhead OnUpdate Tick Loop
    --------------------------------------------------------------------
    bar:SetScript("OnUpdate", function(self, elapsed)
        state_lastUpdate = state_lastUpdate + elapsed
        if state_lastUpdate < 0.03333 then return end 
        local dt = state_lastUpdate
        state_lastUpdate = 0

        local plate = GetNamePlateForUnit("target")
        if plate then
            self:ClearAllPoints()
            self:SetPoint("BOTTOM", plate, "TOP", 0, 18)
            self:SetAlpha(1)   
        else
            self:SetAlpha(0)   
            state_lastPower = -1        
            return
        end

        local power = UnitPower("player", HOLY_POWER) or 0
        local now = GetTime()

        if state_pendingGeneratorPing then
            state_pendingGeneratorPing = false
            if power >= 5 then
                SafePlaySound(SND_FIVE)
            end
        end

        local hasWings = state_wingsUntil and (now < state_wingsUntil)

        if state_dawnlightsLeft > 0 and state_dawnlightsExpire and now > state_dawnlightsExpire then
            state_dawnlightsLeft = 0
        end

        if power < state_lastPower and (state_lastPower - power) >= 3 then
            if state_dawnlightsLeft > 0 and (now - state_lastDecrement) > 0.5 then
                state_dawnlightsLeft = state_dawnlightsLeft - 1
                state_lastDecrement = now
            end
        end

        local inAnshe = state_dawnlightsLeft > 0

        if power > state_lastPower then
            state_popImpulse = 0.26
            state_flash = 0.8
        elseif power < state_lastPower then
            state_popImpulse = -0.16
        end
        state_lastPower = power

        state_popImpulse = state_popImpulse > 0
            and max(0, state_popImpulse - dt * 8)
            or  min(0, state_popImpulse + dt * 8)
        state_flash = max(0, state_flash - dt * 4)

        local t = now * 3
        local k = min(1, dt * 12)

        ----------------------------------------------------------------
        -- Mode Easing Targets
        ----------------------------------------------------------------
        local mode = "normal"
        local baseScale, spinSpeed = 1.0, 3.0
        local coR, coG, coB = 1, 0.5, 0.1     
        local gR, gG, gB = 1, 0.6, 0.2        
        local haloA, glowA = 0.18, 0.45       
        local spineA, auraA = 0.22, 0.06
        local sparkleOn = false

        if inAnshe and hasWings then
            mode = "both"
            baseScale, spinSpeed = 1.42, 4.2
            local p = (sin(now * 9.0) + 1) * 0.5
            coR, coG, coB = 1, 0.97*(1-p)+0.80*p, 0.86*(1-p)+0.42*p
            gR, gG, gB = 1, 0.96, 0.62
            haloA, glowA = 0.38, 0.74
            spineA, auraA = 0.44, 0.16
            sparkleOn = true
        elseif inAnshe then
            mode = "anshe"
            baseScale, spinSpeed = 1.14, 2.9
            local p = (sin(now * 7.5) + 1) * 0.5
            coR, coG, coB = 1, 0.96*(1-p)+0.55*p, 0.86*(1-p)+0.06*p
            gR, gG, gB = 1, 0.90, 0.50
            haloA, glowA = 0.27, 0.59
            spineA, auraA = 0.32, 0.10
            sparkleOn = true
        elseif hasWings then
            mode = "wings"
            baseScale, spinSpeed = 1.28, 3.3
            local p = (sin(now * 6.3) + 1) * 0.5
            coR, coG, coB = 1, 0.85*(1-p)+0.95*p, 0.55*(1-p)+0.72*p
            gR, gG, gB = 1, 0.88, 0.60
            haloA, glowA = 0.30, 0.58
            spineA, auraA = 0.36, 0.12
            sparkleOn = true
        else
            baseScale = (power >= 5 and 1.40) or (power >= 3 and 1.16) or 0.90
            baseScale = baseScale + sin(t) * 0.04
        end

        local flashMix = state_flash * 0.45
        local fR = coR*(1-flashMix) + 1*flashMix
        local fG = coG*(1-flashMix) + 0.97*flashMix
        local fB = coB*(1-flashMix) + 0.85*flashMix
        local hotBoost = state_flash * 0.5

        state_gR = state_gR + (gR - state_gR) * k
        state_gG = state_gG + (gG - state_gG) * k
        state_gB = state_gB + (gB - state_gB) * k
        state_auraA = state_auraA + (auraA - state_auraA) * k
        
        -- Store colors locally to speed up iterations
        local current_gR, current_gG, current_gB = state_gR, state_gG, state_gB
        local impulse = state_popImpulse

        bar_spine:SetVertexColor(current_gR, current_gG, current_gB)
        bar_spine:SetAlpha(spineA)
        bar_aura:SetVertexColor(current_gR, current_gG, current_gB)
        bar_aura:SetAlpha(state_auraA)

        ----------------------------------------------------------------
        -- Render Stars (Optimized Parallel Processing)
        ----------------------------------------------------------------
        for i = 1, NUM do
            local active = i <= power
            local psh = (sin(t + prop_o9[i]) + 1) * 0.5

            local tScale, tcoR, tcoG, tcoB
            local tHoA, tHiA, tHotA, tSpA, tBpA
            local tSpin

            if mode == "normal" then
                if active then
                    tScale = baseScale + sin(t + prop_o7[i]) * 0.05
                    if power >= 5 then
                        tcoR, tcoG, tcoB = 1, 0.60, 0.16
                        tHoA, tHiA = 0.17, 0.44
                    else
                        tcoR, tcoG, tcoB = 0.72 + prop_pp[i]*0.28, 0.26 + prop_pp[i]*0.22, 0.05
                        tHoA, tHiA = 0.13 + psh*0.05, 0.34
                    end
                    tHotA = 0.28 + psh*0.10
                    tSpA = (power >= 5) and (0.10 + psh*0.08) or 0
                    tBpA = 0.5
                    tSpin = 3.0
                else
                    tScale = 0.80 + sin(t + prop_o7[i]) * 0.03
                    tcoR, tcoG, tcoB = 0.16, 0.11, 0.07
                    tHoA, tHiA, tHotA, tSpA = 0.03, 0.03, 0, 0
                    tBpA = 0.32
                    tSpin = 0
                end
            else
                if active then
                    tScale = baseScale + sin(t + prop_o7[i]) * 0.06
                    tcoR, tcoG, tcoB = fR, fG, fB
                    tHoA = haloA * (0.85 + psh*0.15)
                    tHiA = glowA * (0.85 + psh*0.15)
                    tHotA = 0.45 + psh*0.15 + hotBoost
                    tSpA = sparkleOn and (0.18 + psh*0.14) or 0
                    tBpA = 0.5
                    tSpin = spinSpeed
                else
                    tScale = (baseScale * 0.82) + sin(t + prop_o7[i]) * 0.03
                    tcoR, tcoG, tcoB = coR*0.20, coG*0.20, coB*0.20
                    tHoA, tHiA = 0.04, 0.05
                    tHotA, tSpA = 0, 0
                    tBpA = 0.34
                    tSpin = spinSpeed * 0.4
                end
            end

            if active and i == power and impulse > 0.05 then
                tScale = tScale + impulse * 0.5
                tHotA = tHotA + impulse * 0.4
            end

            -- Update values using flat data registers directly
            local currentScale = prop_curScale[i] + (tScale - prop_curScale[i]) * k
            prop_curScale[i] = currentScale
            
            prop_cR[i] = prop_cR[i] + (tcoR - prop_cR[i]) * k
            prop_cG[i] = prop_cG[i] + (tcoG - prop_cG[i]) * k
            prop_cB[i] = prop_cB[i] + (tcoB - prop_cB[i]) * k
            
            local currentHoA = prop_hoA[i] + (tHoA - prop_hoA[i]) * k
            prop_hoA[i] = currentHoA
            
            local currentHiA = prop_hiA[i] + (tHiA - prop_hiA[i]) * k
            prop_hiA[i] = currentHiA
            
            local currentHotA = prop_hotA[i] + (tHotA - prop_hotA[i]) * k
            prop_hotA[i] = currentHotA
            
            local currentSpA = prop_spA[i] + (tSpA - prop_spA[i]) * k
            prop_spA[i] = currentSpA
            
            local currentBpA = prop_bpA[i] + (tBpA - prop_bpA[i]) * k
            prop_bpA[i] = currentBpA

            local currentSpin = prop_spin[i] + dt * tSpin
            prop_spin[i] = currentSpin

            -- Render directly to objects through indexed memory pipelines
            block_frames[i]:SetScale(currentScale)
            
            local bpObj = tex_bp[i]
            bpObj:SetAlpha(currentBpA)
            bpObj:SetRotation(currentSpin * 0.25)

            local hoObj = tex_ho[i]
            hoObj:SetVertexColor(current_gR, current_gG, current_gB)
            hoObj:SetAlpha(currentHoA)
            hoObj:SetRotation(-currentSpin * 0.6)

            local hiObj = tex_hi[i]
            hiObj:SetVertexColor(current_gR, current_gG, current_gB)
            hiObj:SetAlpha(currentHiA)
            hiObj:SetRotation(currentSpin * 0.9)

            local coObj = tex_co[i]
            coObj:SetVertexColor(prop_cR[i], prop_cG[i], prop_cB[i])
            coObj:SetAlpha(active and 1 or 0.85)
            coObj:SetRotation(currentSpin * 0.18)

            local hotObj = tex_hot[i]
            hotObj:SetAlpha(currentHotA)
            hotObj:SetRotation(-currentSpin * 1.6)

            local spObj = tex_sp[i]
            spObj:SetAlpha(currentSpA)
            spObj:SetRotation(-currentSpin * 1.1 + i * 0.5)
        end
    end)

    _G.BigJ_StarBar_Final = bar
    print("[StarBar] construction succeeded, bar created.")
end