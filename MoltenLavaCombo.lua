function (self, unitId, unitFrame, envTable, modTable)
    if _G.BigJ_StarBar_Final then return end

    print("[StarBar VERSION] v14.4 (build 28) -- SUBTLER SOLO STATES + STRONGER COMBO POP: AW, WoA, and 5 HP are calmer; AW+WoA stands out more through depth, color shift, and hot-core emphasis.")

    --------------------------------------------------------------------
    -- Config
    --------------------------------------------------------------------
    local STAR_TEX   = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX  = "Interface\\Cooldown\\star4"
    local SOLID      = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower

    local DEBUG       = false
    local SOUND_ON    = true
    local SOUND_DEBUG = false
    local SND_FIVE    = 162888

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

    local WAKE_OF_ASHES           = 255937
    local AVENGING_WRATH_ID       = 31884
    local CRUSADE_ID              = 231895
    local AVENGING_WRATH_DURATION = 20
    local DAWNLIGHTS_WINDOW       = 12

    local SPENDERS = {
        [85256]  = true,
        [336872] = true,
        [383328] = true,
        [224239] = true,
        [215661] = true,
        [53600]  = true,
        [85673]  = true,
    }

    local sin, min, max = math.sin, math.min, math.max
    local GetTime = GetTime
    local UnitPower = UnitPower
    local PlaySound = PlaySound
    local GetPlate = C_NamePlate and C_NamePlate.GetNamePlateForUnit

    local BLOCK  = 40
    local STEP   = 47
    local NUM    = 5
    local BAR_W  = 250
    local BAR_H  = 70
    local STARTX = (BAR_W - (NUM - 1) * STEP) / 2

    local UPDATE_INTERVAL = 1 / 20

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

    local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel(100)

    bar.blocks = {}
    bar.dawnlightsLeft = 0
    bar.dawnlightsExpire = 0
    bar.wingsUntil = 0
    bar.lastPower = -1
    bar.pendingGeneratorPing = false
    bar.popImpulse = 0
    bar.lastUpdate = 0
    bar.lastDecrement = 0
    bar.flash = 0

    bar.gR, bar.gG, bar.gB = 1, 0.6, 0.2
    bar.auraA = 0.10

    bar.lastPlate = nil
    bar.currentAlpha = -1

    bar:Show()
    bar:SetAlpha(0)

    --------------------------------------------------------------------
    -- Backdrop
    --------------------------------------------------------------------
    bar.aura = bar:CreateTexture(nil, "BACKGROUND")
    bar.aura:SetTexture(SOLID)
    bar.aura:SetBlendMode("ADD")
    bar.aura:SetSize(BAR_W - 6, 26)
    bar.aura:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.aura:SetVertexColor(bar.gR, bar.gG, bar.gB)
    bar.aura:SetAlpha(0.06)

    bar.spine = bar:CreateTexture(nil, "ARTWORK")
    bar.spine:SetTexture(SOLID)
    bar.spine:SetSize((NUM - 1) * STEP + BLOCK * 0.7, 3)
    bar.spine:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.spine:SetVertexColor(bar.gR, bar.gG, bar.gB)
    bar.spine:SetAlpha(0.22)

    --------------------------------------------------------------------
    -- Star blocks
    --------------------------------------------------------------------
    for i = 1, NUM do
        local s = CreateFrame("Frame", nil, bar)
        s:SetFrameLevel(bar:GetFrameLevel() + 2)
        s:SetSize(BLOCK, BLOCK)
        s.baseX = STARTX + (i - 1) * STEP
        s:SetPoint("CENTER", bar, "LEFT", s.baseX, 0)

        s.o7 = i * 0.7
        s.o9 = i * 0.9
        s.pp = i / NUM
        s.curY = 0

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

        s.bp, s.ho, s.hi, s.co, s.hot, s.sp = bp, ho, hi, co, hot, sp
        s.spin = 0
        s.curScale = 1
        s.cR, s.cG, s.cB = 1, 0.5, 0.1
        s.hoA, s.hiA, s.hotA, s.spA, s.bpA = 0, 0, 0, 0, 0.45

        bar.blocks[i] = s
    end

    --------------------------------------------------------------------
    -- Events
    --------------------------------------------------------------------
    local ef = CreateFrame("Frame", "BigJ_StarBar_EventFrame", UIParent)
    ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if unit ~= "player" then return end
        local now = GetTime()

        if DEBUG then
            local sName = nil
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellID)
                sName = info and info.name
            elseif GetSpellInfo then
                sName = GetSpellInfo(spellID)
            end
            local power = UnitPower("player", HOLY_POWER) or 0
            print("[StarBar CAST] spellID=" .. tostring(spellID) .. " name=" .. tostring(sName) .. " power=" .. tostring(power))
        end

        if spellID == AVENGING_WRATH_ID or spellID == CRUSADE_ID then
            bar.wingsUntil = now + AVENGING_WRATH_DURATION
            if DEBUG then print("[StarBar] wings armed for", AVENGING_WRATH_DURATION, "sec") end

        elseif spellID == WAKE_OF_ASHES then
            bar.dawnlightsLeft = 3
            bar.lastDecrement = now
            bar.dawnlightsExpire = now + DAWNLIGHTS_WINDOW

        elseif SPENDERS[spellID] then
            if bar.dawnlightsLeft > 0 and (now - bar.lastDecrement) > 0.5 then
                bar.dawnlightsLeft = bar.dawnlightsLeft - 1
                bar.lastDecrement = now
                if DEBUG then print("[StarBar] spender", spellID, "-> dawnlights", bar.dawnlightsLeft) end
            end

        elseif GENERATORS[spellID] then
            bar.pendingGeneratorPing = true
            if DEBUG then print("[StarBar] generator", spellID, "cast -- will check power next tick") end
        end
    end)

    --------------------------------------------------------------------
    -- Per-frame update
    --------------------------------------------------------------------
    bar:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate < UPDATE_INTERVAL then return end

        local dt = self.lastUpdate
        self.lastUpdate = 0

        local plate = GetPlate and GetPlate("target") or nil
        if not plate then
            if self.currentAlpha ~= 0 then
                self.currentAlpha = 0
                self:SetAlpha(0)
            end
            self.lastPlate = nil
            self.lastPower = -1
            return
        end

        if plate ~= self.lastPlate then
            self.lastPlate = plate
            self:ClearAllPoints()
            self:SetPoint("BOTTOM", plate, "TOP", 0, 18)
        end

        if self.currentAlpha ~= 1 then
            self.currentAlpha = 1
            self:SetAlpha(1)
        end

        local power = UnitPower("player", HOLY_POWER) or 0
        local now = GetTime()

        if self.pendingGeneratorPing then
            self.pendingGeneratorPing = false
            if power >= 5 then
                SafePlaySound(SND_FIVE)
                if DEBUG then print("[StarBar] generator used at cap (power=" .. power .. ") -- ding") end
            end
        end

        if self.dawnlightsLeft > 0 and self.dawnlightsExpire and now > self.dawnlightsExpire then
            self.dawnlightsLeft = 0
            if DEBUG then print("[StarBar] dawnlights window expired, reverting to normal") end
        end

        if power < self.lastPower and (self.lastPower - power) >= 3 then
            if self.dawnlightsLeft > 0 and (now - self.lastDecrement) > 0.5 then
                self.dawnlightsLeft = self.dawnlightsLeft - 1
                self.lastDecrement = now
                if DEBUG then print("[StarBar] power-drop spender -> dawnlights", self.dawnlightsLeft) end
            end
        end

        local hasWings = self.wingsUntil and (now < self.wingsUntil)
        local inAnshe = self.dawnlightsLeft > 0

        if DEBUG and (inAnshe or hasWings) then
            print("[StarBar] dawnlights", self.dawnlightsLeft, "wings", hasWings)
        end

        if power > self.lastPower then
            self.popImpulse = 0.22
            self.flash = 0.70
        elseif power < self.lastPower then
            self.popImpulse = -0.12
        end
        self.lastPower = power

        if self.popImpulse > 0 then
            self.popImpulse = max(0, self.popImpulse - dt * 7)
        else
            self.popImpulse = min(0, self.popImpulse + dt * 7)
        end
        self.flash = max(0, self.flash - dt * 3.2)

        local t = now * 3
        local k = min(1, dt * 10)

        ----------------------------------------------------------------
        -- Mode targets
        ----------------------------------------------------------------
        local mode = 0
        local baseScale = 1.0
        local spinSpeed = 0
        local coR, coG, coB = 1, 0.5, 0.1
        local gR, gG, gB = 1, 0.6, 0.2
        local haloA, glowA = 0.18, 0.45
        local spineA, auraA = 0.22, 0.06
        local sparkleOn = false

        if inAnshe and hasWings then
            mode = 3
            baseScale, spinSpeed = 1.30, 4.2
            local p = (sin(now * 7.5) + 1) * 0.5
            coR, coG, coB = 1, 0.93 * (1 - p) + 0.82 * p, 0.78 * (1 - p) + 0.52 * p
            gR, gG, gB = 1, 0.90, 0.62
            haloA, glowA = 0.24, 0.46
            spineA, auraA = 0.28, 0.08
            sparkleOn = true

        elseif inAnshe then
            mode = 2
            baseScale, spinSpeed = 1.10, 3.2
            local p = (sin(now * 6.5) + 1) * 0.5
            coR, coG, coB = 1, 0.92 * (1 - p) + 0.68 * p, 0.82 * (1 - p) + 0.18 * p
            gR, gG, gB = 1, 0.86, 0.46
            haloA, glowA = 0.18, 0.36
            spineA, auraA = 0.22, 0.05
            sparkleOn = true

        elseif hasWings then
            mode = 1
            baseScale, spinSpeed = 1.16, 3.5
            local p = (sin(now * 5.7) + 1) * 0.5
            coR, coG, coB = 1, 0.88 * (1 - p) + 0.95 * p, 0.66 * (1 - p) + 0.76 * p
            gR, gG, gB = 1, 0.86, 0.58
            haloA, glowA = 0.20, 0.38
            spineA, auraA = 0.24, 0.06
            sparkleOn = true
        else
            mode = 0
            baseScale = (power >= 5 and 1.24) or (power >= 3 and 1.10) or 0.92
            baseScale = baseScale + sin(t) * 0.045
        end

        local flashMix = self.flash * 0.40
        local fR = coR * (1 - flashMix) + 1 * flashMix
        local fG = coG * (1 - flashMix) + 0.97 * flashMix
        local fB = coB * (1 - flashMix) + 0.85 * flashMix
        local hotBoost = self.flash * 0.35

        self.gR = self.gR + (gR - self.gR) * k
        self.gG = self.gG + (gG - self.gG) * k
        self.gB = self.gB + (gB - self.gB) * k
        self.auraA = self.auraA + (auraA - self.auraA) * k

        self.spine:SetVertexColor(self.gR, self.gG, self.gB)
        self.spine:SetAlpha(spineA)
        self.aura:SetVertexColor(self.gR, self.gG, self.gB)
        self.aura:SetAlpha(self.auraA)

        ----------------------------------------------------------------
        -- Render stars
        ----------------------------------------------------------------
        for i = 1, NUM do
            local b = self.blocks[i]
            local active = i <= power
            local psh = (sin(t + b.o9) + 1) * 0.5
            local depth = (sin(t * 1.8 + b.o7) + 1) * 0.5
            local depthOut = depth * 2 - 1

            local coolMix = depth
            local coolR, coolG, coolB = 0.40, 0.90, 1.00

            local depthScaleBoost = 0.06
            local depthHaloBoost  = 0.05
            local depthGlowBoost  = 0.08
            local depthHotBoost   = 0.07
            local depthBackFade   = 0.04
            local coolCoreMix     = 0.22
            local coolHaloMix     = 0.18
            local yAmp            = 2.0

            if mode == 1 then
                depthScaleBoost = 0.07
                depthHaloBoost  = 0.05
                depthGlowBoost  = 0.08
                depthHotBoost   = 0.08
                depthBackFade   = 0.04
                coolCoreMix     = 0.20
                coolHaloMix     = 0.16
                yAmp            = 2.2
            elseif mode == 2 then
                depthScaleBoost = 0.06
                depthHaloBoost  = 0.05
                depthGlowBoost  = 0.08
                depthHotBoost   = 0.07
                depthBackFade   = 0.04
                coolCoreMix     = 0.22
                coolHaloMix     = 0.18
                yAmp            = 2.4
            elseif mode == 3 then
                depthScaleBoost = 0.11
                depthHaloBoost  = 0.08
                depthGlowBoost  = 0.13
                depthHotBoost   = 0.12
                depthBackFade   = 0.06
                coolCoreMix     = 0.34
                coolHaloMix     = 0.28
                yAmp            = 4.0
            end

            local tScale, tcoR, tcoG, tcoB
            local tHoA, tHiA, tHotA, tSpA, tBpA
            local tSpin = 0
            local targetY = 0

            if mode == 0 then
                if active then
                    tScale = baseScale + sin(t + b.o7) * 0.04
                    if power >= 5 then
                        tcoR, tcoG, tcoB = 1, 0.57, 0.15
                        tHoA, tHiA = 0.14, 0.34
                    else
                        tcoR, tcoG, tcoB = 0.72 + b.pp * 0.28, 0.26 + b.pp * 0.22, 0.05
                        tHoA, tHiA = 0.11 + psh * 0.04, 0.28
                    end
                    tHotA = 0.24 + psh * 0.08
                    tSpA = (power >= 5) and (0.06 + psh * 0.05) or 0.02
                    tBpA = 0.50
                    tSpin = 3.6
                    targetY = depthOut * yAmp
                else
                    tScale = 0.82 + sin(t + b.o7) * 0.03
                    tcoR, tcoG, tcoB = 0.16, 0.11, 0.07
                    tHoA, tHiA, tHotA, tSpA = 0.03, 0.03, 0, 0
                    tBpA = 0.34
                    tSpin = 0.8
                    targetY = depthOut * 0.8
                end
            else
                if active then
                    tScale = baseScale + sin(t + b.o7) * 0.05
                    tcoR, tcoG, tcoB = fR, fG, fB
                    tHoA = haloA * (0.88 + psh * 0.12)
                    tHiA = glowA * (0.88 + psh * 0.12)
                    tHotA = 0.30 + psh * 0.10 + hotBoost
                    tSpA = sparkleOn and (0.07 + psh * 0.06) or 0
                    tBpA = 0.48
                    tSpin = spinSpeed
                    targetY = depthOut * yAmp
                else
                    tScale = (baseScale * 0.86) + sin(t + b.o7) * 0.03
                    tcoR, tcoG, tcoB = coR * 0.20, coG * 0.20, coB * 0.20
                    tHoA, tHiA = 0.03, 0.04
                    tHotA, tSpA = 0, 0
                    tBpA = 0.34
                    tSpin = spinSpeed * 0.30
                    targetY = depthOut * 0.9
                end
            end

            if active then
                tScale = tScale + depthOut * depthScaleBoost
                tHoA = tHoA + depth * depthHaloBoost
                tHiA = tHiA + depth * depthGlowBoost
                tHotA = tHotA + depth * depthHotBoost
                tBpA = tBpA - depth * depthBackFade

                tcoR = tcoR * (1 - coolMix * coolCoreMix) + coolR * (coolMix * coolCoreMix)
                tcoG = tcoG * (1 - coolMix * coolCoreMix) + coolG * (coolMix * coolCoreMix)
                tcoB = tcoB * (1 - coolMix * coolCoreMix) + coolB * (coolMix * coolCoreMix)
            else
                tScale = tScale + depthOut * 0.02
                tHoA = tHoA + depth * 0.01
                tHiA = tHiA + depth * 0.02
                tBpA = tBpA - depth * 0.01
            end

            if active and i == power and self.popImpulse > 0.05 then
                local popScale = (mode == 3) and 0.58 or 0.42
                local popHot   = (mode == 3) and 0.46 or 0.30
                local popY     = (mode == 3) and 6.5 or 4.0
                tScale = tScale + self.popImpulse * popScale
                tHotA = tHotA + self.popImpulse * popHot
                targetY = targetY + self.popImpulse * popY
            end

            b.curScale = b.curScale + (tScale - b.curScale) * k
            b.cR = b.cR + (tcoR - b.cR) * k
            b.cG = b.cG + (tcoG - b.cG) * k
            b.cB = b.cB + (tcoB - b.cB) * k
            b.hoA = b.hoA + (tHoA - b.hoA) * k
            b.hiA = b.hiA + (tHiA - b.hiA) * k
            b.hotA = b.hotA + (tHotA - b.hotA) * k
            b.spA = b.spA + (tSpA - b.spA) * k
            b.bpA = b.bpA + (tBpA - b.bpA) * k
            b.curY = b.curY + (targetY - b.curY) * k

            b.spin = b.spin + dt * tSpin

            b:ClearAllPoints()
            b:SetPoint("CENTER", self, "LEFT", b.baseX, b.curY)

            local hgR = self.gR
            local hgG = self.gG
            local hgB = self.gB
            if active then
                hgR = self.gR * (1 - coolMix * coolHaloMix) + coolR * (coolMix * coolHaloMix)
                hgG = self.gG * (1 - coolMix * coolHaloMix) + coolG * (coolMix * coolHaloMix)
                hgB = self.gB * (1 - coolMix * coolHaloMix) + coolB * (coolMix * coolHaloMix)
            end

            b:SetScale(b.curScale)
            b.bp:SetAlpha(b.bpA)
            b.bp:SetRotation(b.spin * 0.22)

            b.ho:SetVertexColor(hgR, hgG, hgB)
            b.ho:SetAlpha(b.hoA)
            b.ho:SetRotation(-b.spin * 0.58)

            b.hi:SetVertexColor(hgR, hgG, hgB)
            b.hi:SetAlpha(b.hiA)
            b.hi:SetRotation(b.spin * 0.88)

            b.co:SetVertexColor(b.cR, b.cG, b.cB)
            b.co:SetAlpha(active and 1 or 0.85)
            b.co:SetRotation(b.spin * 0.16)

            b.hot:SetAlpha(b.hotA)
            b.hot:SetRotation(-b.spin * 1.45)

            b.sp:SetAlpha(b.spA)
            b.sp:SetRotation(-b.spin * 1.0 + i * 0.5)
        end
    end)

    _G.BigJ_StarBar_Final = bar
    print("[StarBar] construction succeeded, bar created.")
end