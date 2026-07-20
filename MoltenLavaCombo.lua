function (self, unitId, unitFrame, envTable, modTable)
    -- Only build once
    if _G.BigJ_StarBar_Final then return end

    print("|cff00ff00[StarBar]|r v13.7 (build 29) loading...")

    local STAR_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX = "Interface\\Cooldown\\star4"
    local SOLID = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower

    local DEBUG = false
    local SOUND_ON = true
    local SND_FIVE = 162888

    local GENERATORS = {
        [35395] = true, [1227637] = true, [20271] = true, [275779] = true,
        [184575] = true, [24275] = true, [1241288] = true, [407480] = true,
        [198036] = true, [406647] = true,
    }

    local WAKE_OF_ASHES = 255937
    local AVENGING_WRATH_DURATION = 20
    local SPENDERS = {
        [85256] = true, [336872] = true, [383328] = true,
        [53385] = true, [224239] = true, [215661] = true,
        [53600] = true, [85673] = true,
    }

    local sin, min, max = math.sin, math.min, math.max

    local BLOCK = 40
    local STEP = 47
    local NUM = 5
    local BAR_W = 250
    local STARTX = (BAR_W - (NUM - 1) * STEP) / 2

    local NUM_DAWNLIGHT = 3
    local DL_STEP = 28
    local DL_SIZE = 20
    local DL_STARTX = (BAR_W - (NUM_DAWNLIGHT - 1) * DL_STEP) / 2

    local AVENGING_WRATH_ID = 31884
    local CRUSADE_ID = 231895

    local function SafePlaySound(kit)
        if SOUND_ON and kit then
            PlaySound(kit, "Master", false)
        end
    end

    local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
    bar:SetSize(BAR_W, 70)
    bar:SetFrameStrata("HIGH")
    bar:SetFrameLevel(100)
    bar.blocks = {}
    bar.dawnlightsLeft = 0
    bar.wingsUntil = 0
    bar.lastPower = -1
    bar.pendingGeneratorPing = false
    bar.popImpulse = 0
    bar.lastUpdate = 0
    bar.lastDecrement = 0
    bar.flash = 0
    bar.gR, bar.gG, bar.gB = 1, 0.6, 0.2
    bar.auraA = 0.10

    bar:Show()
    bar:SetAlpha(0)

    -- Backdrop
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

    -- Holy Power stars
    for i = 1, NUM do
        local s = CreateFrame("Frame", nil, bar)
        s:SetFrameLevel(bar:GetFrameLevel() + 2)
        s:SetSize(BLOCK, BLOCK)
        s:SetPoint("CENTER", bar, "LEFT", STARTX + (i - 1) * STEP, 0)

        s.o7 = i * 0.7
        s.o9 = i * 0.9
        s.pp = i / NUM

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

    -- Dawnlight pips
    bar.dawnlightPips = {}
    for i = 1, NUM_DAWNLIGHT do
        local p = CreateFrame("Frame", nil, bar)
        p:SetFrameLevel(bar:GetFrameLevel() + 3)
        p:SetSize(DL_SIZE, DL_SIZE)
        p:SetPoint("CENTER", bar, "LEFT", DL_STARTX + (i - 1) * DL_STEP, -33)

        local outline = p:CreateTexture(nil, "BACKGROUND")
        outline:SetTexture(STAR_TEX)
        outline:SetTexCoord(0, 0.25, 0, 0.25)
        outline:SetSize(DL_SIZE * 1.38, DL_SIZE * 1.38)
        outline:SetPoint("CENTER", p, "CENTER", 0, 0)
        outline:SetVertexColor(0.02, 0.02, 0.04)
        outline:SetAlpha(0.85)

        local glow = p:CreateTexture(nil, "BORDER")
        glow:SetTexture(STAR_TEX)
        glow:SetTexCoord(0, 0.25, 0, 0.25)
        glow:SetBlendMode("ADD")
        glow:SetSize(DL_SIZE * 2.15, DL_SIZE * 2.15)
        glow:SetPoint("CENTER", p, "CENTER", 0, 0)
        glow:SetAlpha(0)

        local core = p:CreateTexture(nil, "ARTWORK")
        core:SetTexture(STAR_TEX)
        core:SetTexCoord(0, 0.25, 0, 0.25)
        core:SetAllPoints(p)
        core:SetVertexColor(0.2, 0.5, 1.0)
        core:SetAlpha(0.25)

        local hot = p:CreateTexture(nil, "OVERLAY")
        hot:SetTexture(SPARK_TEX)
        hot:SetBlendMode("ADD")
        hot:SetSize(DL_SIZE * 0.62, DL_SIZE * 0.62)
        hot:SetPoint("CENTER", p, "CENTER", 0, 0)
        hot:SetVertexColor(0.6, 0.9, 1.0)
        hot:SetAlpha(0)

        p.outline = outline
        p.core = core
        p.glow = glow
        p.hot = hot
        p.phase = i * 2.1
        p.curScale = 1
        p.dlA = 0.25

        bar.dawnlightPips[i] = p
    end

    -- Events
    local ef = CreateFrame("Frame", "BigJ_StarBar_EventFrame")
    ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if unit ~= "player" then return end
        local now = GetTime()

        if spellID == AVENGING_WRATH_ID or spellID == CRUSADE_ID then
            bar.wingsUntil = now + AVENGING_WRATH_DURATION
        elseif spellID == WAKE_OF_ASHES then
            bar.dawnlightsLeft = 3
        elseif SPENDERS[spellID] then
            if bar.dawnlightsLeft > 0 and (now - bar.lastDecrement) > 0.5 then
                bar.dawnlightsLeft = bar.dawnlightsLeft - 1
                bar.lastDecrement = now
            end
        elseif GENERATORS[spellID] then
            bar.pendingGeneratorPing = true
        end
    end)

    -- OnUpdate
    bar:SetScript("OnUpdate", function(self, elapsed)
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate < 1/30 then return end
        local dt = self.lastUpdate
        self.lastUpdate = 0

        local plate = C_NamePlate.GetNamePlateForUnit("target")
        if plate then
            self:ClearAllPoints()
            self:SetPoint("BOTTOM", plate, "TOP", 0, 18)
            self:SetAlpha(1)
        else
            self:SetAlpha(0)
            self.lastPower = -1
            return
        end

        local power = UnitPower("player", HOLY_POWER) or 0
        local now = GetTime()

        if self.pendingGeneratorPing then
            self.pendingGeneratorPing = false
            if power >= 5 then
                SafePlaySound(SND_FIVE)
            end
        end

        local hasWings = self.wingsUntil and (now < self.wingsUntil)

        if power < self.lastPower and (self.lastPower - power) >= 3 then
            if self.dawnlightsLeft > 0 and (now - self.lastDecrement) > 0.5 then
                self.dawnlightsLeft = self.dawnlightsLeft - 1
                self.lastDecrement = now
            end
        end

        local inAnshe = self.dawnlightsLeft > 0

        if power > self.lastPower then
            self.popImpulse = 0.26
            self.flash = 0.8
        elseif power < self.lastPower then
            self.popImpulse = -0.16
        end
        self.lastPower = power

        self.popImpulse = self.popImpulse > 0 and max(0, self.popImpulse - dt * 8) or min(0, self.popImpulse + dt * 8)
        self.flash = max(0, self.flash - dt * 4)

        local t = now * 3
        local k = min(1, dt * 12)

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
            local p = (sin(now * 9.0) + 1) / 2
            coR, coG, coB = 1, 0.97*(1-p)+0.80*p, 0.86*(1-p)+0.42*p
            gR, gG, gB = 1, 0.96, 0.62
            haloA, glowA = 0.38, 0.74
            spineA, auraA = 0.44, 0.16
            sparkleOn = true
        elseif inAnshe then
            mode = "anshe"
            baseScale, spinSpeed = 1.14, 2.9
            local p = (sin(now * 7.5) + 1) / 2
            coR, coG, coB = 1, 0.96*(1-p)+0.55*p, 0.86*(1-p)+0.06*p
            gR, gG, gB = 1, 0.90, 0.50
            haloA, glowA = 0.27, 0.59
            spineA, auraA = 0.32, 0.10
            sparkleOn = true
        elseif hasWings then
            mode = "wings"
            baseScale, spinSpeed = 1.28, 3.3
            local p = (sin(now * 6.3) + 1) / 2
            coR, coG, coB = 1, 0.85*(1-p)+0.95*p, 0.55*(1-p)+0.72*p
            gR, gG, gB = 1, 0.88, 0.60
            haloA, glowA = 0.30, 0.58
            spineA, auraA = 0.36, 0.12
            sparkleOn = true
        else
            baseScale = (power >= 5 and 1.40) or (power >= 3 and 1.16) or 0.90
            baseScale = baseScale + sin(t) * 0.04
        end

        local flashMix = self.flash * 0.45
        local fR = coR*(1-flashMix) + 1*flashMix
        local fG = coG*(1-flashMix) + 0.97*flashMix
        local fB = coB*(1-flashMix) + 0.85*flashMix
        local hotBoost = self.flash * 0.5

        self.gR = self.gR + (gR - self.gR) * k
        self.gG = self.gG + (gG - self.gG) * k
        self.gB = self.gB + (gB - self.gB) * k
        self.auraA = self.auraA + (auraA - self.auraA) * k
        self.spine:SetVertexColor(self.gR, self.gG, self.gB)
        self.spine:SetAlpha(spineA)
        self.aura:SetVertexColor(self.gR, self.gG, self.gB)
        self.aura:SetAlpha(self.auraA)

        for i = 1, NUM do
            local b = self.blocks[i]
            local active = i <= power
            local psh = (sin(t + b.o9) + 1) / 2

            local tScale, tcoR, tcoG, tcoB
            local tHoA, tHiA, tHotA, tSpA, tBpA
            local tSpin

            if mode == "normal" then
                if active then
                    tScale = baseScale + sin(t + b.o7) * 0.05
                    if power >= 5 then
                        tcoR, tcoG, tcoB = 1, 0.60, 0.16
                        tHoA, tHiA = 0.17, 0.44
                    else
                        tcoR, tcoG, tcoB = 0.72 + b.pp*0.28, 0.26 + b.pp*0.22, 0.05
                        tHoA, tHiA = 0.13 + psh*0.05, 0.34
                    end
                    tHotA = 0.28 + psh*0.10
                    tSpA = (power >= 5) and (0.10 + psh*0.08) or 0
                    tBpA = 0.5
                    tSpin = 3.0
                else
                    tScale = 0.80 + sin(t + b.o7) * 0.03
                    tcoR, tcoG, tcoB = 0.16, 0.11, 0.07
                    tHoA, tHiA, tHotA, tSpA = 0.03, 0.03, 0, 0
                    tBpA = 0.32
                    tSpin = 0
                end
            else
                if active then
                    tScale = baseScale + sin(t + b.o7) * 0.06
                    tcoR, tcoG, tcoB = fR, fG, fB
                    tHoA = haloA * (0.85 + psh*0.15)
                    tHiA = glowA * (0.85 + psh*0.15)
                    tHotA = 0.45 + psh*0.15 + hotBoost
                    tSpA = sparkleOn and (0.18 + psh*0.14) or 0
                    tBpA = 0.5
                    tSpin = spinSpeed
                else
                    tScale = (baseScale * 0.82) + sin(t + b.o7) * 0.03
                    tcoR, tcoG, tcoB = coR*0.20, coG*0.20, coB*0.20
                    tHoA, tHiA = 0.04, 0.05
                    tHotA, tSpA = 0, 0
                    tBpA = 0.34
                    tSpin = spinSpeed * 0.4
                end
            end

            if active and i == power and self.popImpulse > 0.05 then
                tScale = tScale + self.popImpulse * 0.5
                tHotA = tHotA + self.popImpulse * 0.4
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

            b.spin = b.spin + dt * tSpin

            b:SetScale(b.curScale)
            b.bp:SetAlpha(b.bpA)
            b.bp:SetRotation(b.spin * 0.25)

            b.ho:SetVertexColor(self.gR, self.gG, self.gB)
            b.ho:SetAlpha(b.hoA)
            b.ho:SetRotation(-b.spin * 0.6)

            b.hi:SetVertexColor(self.gR, self.gG, self.gB)
            b.hi:SetAlpha(b.hiA)
            b.hi:SetRotation(b.spin * 0.9)

            b.co:SetVertexColor(b.cR, b.cG, b.cB)
            b.co:SetAlpha(active and 1 or 0.85)
            b.co:SetRotation(b.spin * 0.18)

            b.hot:SetAlpha(b.hotA)
            b.hot:SetRotation(-b.spin * 1.6)

            b.sp:SetAlpha(b.spA)
            b.sp:SetRotation(-b.spin * 1.1 + i * 0.5)
        end

        -- Dawnlight pips
        for i = 1, NUM_DAWNLIGHT do
            local p = self.dawnlightPips[i]
            local lit = i <= self.dawnlightsLeft

            local phase = now * 4.8 + p.phase
            local pulse = (sin(phase) + 1) * 0.5
            local slow  = (sin(now * 2.6 + p.phase) + 1) * 0.5

            local targetScale, tA, gA, hA, oA
            local r, g, b

            if lit then
                targetScale = 1.00 + pulse * 0.14
                r = 0.12 + slow * 0.88
                g = 0.35 + (1 - slow) * 0.35
                b = 1.00 - slow * 0.75
                tA = 0.92 + pulse * 0.08
                gA = 0.32 + pulse * 0.38
                hA = 0.55 + pulse * 0.35
                oA = 0.95
            else
                targetScale = 0.80 + pulse * 0.07
                r, g, b = 0.13, 0.20, 0.42
                tA = 0.22 + pulse * 0.06
                gA = 0.06 + pulse * 0.05
                hA = 0
                oA = 0.55
            end

            p.curScale = p.curScale + (targetScale - p.curScale) * k
            p:SetScale(p.curScale)

            p.outline:SetAlpha(oA)
            p.dlA = p.dlA + (tA - p.dlA) * k
            p.core:SetAlpha(p.dlA)
            p.core:SetVertexColor(r, g, b)
            p.glow:SetAlpha(gA)
            p.glow:SetVertexColor(r * 0.65 + 0.35, g * 0.55, b)
            p.hot:SetAlpha(hA)
            p.hot:SetVertexColor(min(1, r + 0.45), min(1, g + 0.35), min(1, b + 0.25))
        end
    end)

    _G.BigJ_StarBar_Final = bar
    print("|cff00ff00[StarBar]|r construction succeeded")
end