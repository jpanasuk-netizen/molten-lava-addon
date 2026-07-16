function (self, unitId, unitFrame, envTable, modTable)

    --------------------------------------------------------------------
    -- Config
    --------------------------------------------------------------------
    local STAR_TEX  = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX = "Interface\\Cooldown\\star4"          -- ornamental twinkle (blank if path changes)
    local SOLID     = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower

    local DEBUG    = false      -- print dawnlights/wings state while testing
    local SOUND_ON = true       -- bell when you hit 5 Holy Power

    local SND_FIVE    = 567455   -- direct file ID, confirmed working (v1)
    local SND_OVERCAP = 567458   -- adjacent bell variant for overcap warning

    local function SafePlaySound(fileID)
        if SOUND_ON and fileID then
            PlaySoundFile(fileID, "SFX")
        end
    end

    local WAKE_OF_ASHES = 255937
    local SPENDERS = {
        [85256]  = true, -- Templar's Verdict
        [336872] = true, -- Final Verdict
        [383328] = true, -- Final Verdict (alt id)
        [224239] = true, -- Divine Storm
        [215661] = true, -- Justicar's Vengeance
        [53600]  = true, -- Shield of the Righteous
        [85673]  = true, -- Word of Glory
    }

    local GENERATORS = {
        [35395]  = true, -- Crusader Strike
        [406647] = true, -- Crusading Strikes
        [406648] = true, -- Crusading Strikes (alt)
        [184575] = true, -- Blade of Justice
        [20271]  = true, -- Judgment
        [24275]  = true, -- Hammer of Wrath
        [255937] = true, -- Wake of Ashes
        [304971] = true, -- Divine Toll
        [383385] = true, -- Crusading Strikes (talent)
    }

    -- hoisted math
    local sin, min, max = math.sin, math.min, math.max
    local PHI = 1.6180339887   -- golden ratio: irrational spin ratios = aperiodic "4D" rotation

    local BLOCK = 46
    local STEP  = 62
    local NUM   = 5
    local BAR_W = 340
    local STARTX = (BAR_W - (NUM - 1) * STEP) / 2

    local function HasWings()
        return (AuraUtil.FindAuraByName("Avenging Wrath", "player") ~= nil)
            or (AuraUtil.FindAuraByName("Crusade", "player") ~= nil)
    end

    if not _G.BigJ_StarBar_Final then
        local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
        bar:SetSize(BAR_W, 70)
        bar:SetFrameStrata("HIGH")
        bar:SetFrameLevel(100)
        bar.blocks = {}
        bar.dawnlightsLeft = 0
        bar.lastPower = -1
        bar.popImpulse = 0
        bar.lastUpdate = 0
        bar.lastDecrement = 0
        bar.flash = 0
        bar.hasWings = HasWings()
        bar.currentTarget = nil        -- track target to prevent re-anchor jitter
        bar.lastGenTime = {}           -- per-spellID timestamps for overcap double-fire guard
        bar.wasAtFive = false          -- true when player was at 5 HP last frame (overcap detection)
        -- bar-level smoothed glow color (shared by halos, spine, aura)
        bar.gR, bar.gG, bar.gB = 0.3, 0.7, 1.0
        bar.auraA = 0.10

        --------------------------------------------------------------------
        -- Backdrop: luminous spine + soft full-bar aura
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
            s:SetFrameLevel(bar:GetFrameLevel() + 2 + i)   -- unique level per star, no overlap z-fighting
            s:SetSize(BLOCK, BLOCK)
            s:SetPoint("CENTER", bar, "LEFT", STARTX + (i - 1) * STEP, 0)

            -- precomputed per-star offsets
            s.o7 = i * 0.7
            s.o9 = i * 0.9
            s.pp = i / NUM
            s.zp = i * 1.2566   -- z-axis phase: 2π/5 spread so stars evenly rotate toward/away

            -- outer halo (star4, ADD, large glow ring)
            local ho = s:CreateTexture(nil, "BORDER")
            ho:SetTexture(SPARK_TEX)
            ho:SetBlendMode("ADD")
            ho:SetSize(BLOCK * 2.2, BLOCK * 2.2)
            ho:SetPoint("CENTER", s, "CENTER", 0, 0)
            ho:SetAlpha(0)

            -- inner halo (star4, ADD)
            local hi = s:CreateTexture(nil, "ARTWORK")
            hi:SetTexture(SPARK_TEX)
            hi:SetBlendMode("ADD")
            hi:SetSize(BLOCK * 1.45, BLOCK * 1.45)
            hi:SetPoint("CENTER", s, "CENTER", 0, 0)
            hi:SetAlpha(0)

            -- core star: raid icon atlas (proper 8-point star shape, normal blend so color shows)
            local co = s:CreateTexture(nil, "ARTWORK")
            co:SetTexture(STAR_TEX)
            co:SetTexCoord(0, 0.25, 0, 0.25)
            co:SetSize(BLOCK, BLOCK)
            co:SetPoint("CENTER", s, "CENTER", 0, 0)
            co:SetVertexColor(0.25, 0.70, 1.0)

            -- hot inner core (star4 small = glowing dot, ADD so color adds over star)
            local hot = s:CreateTexture(nil, "OVERLAY")
            hot:SetTexture(SPARK_TEX)
            hot:SetBlendMode("ADD")
            hot:SetSize(BLOCK * 0.65, BLOCK * 0.65)
            hot:SetPoint("CENTER", s, "CENTER", 0, 0)
            hot:SetAlpha(0)

            -- sparkle twinkle
            local sp = s:CreateTexture(nil, "OVERLAY")
            sp:SetTexture(SPARK_TEX)
            sp:SetBlendMode("ADD")
            sp:SetSize(BLOCK * 1.5, BLOCK * 1.5)
            sp:SetPoint("CENTER", s, "CENTER", 0, 0)
            sp:SetVertexColor(1, 0.95, 0.8)
            sp:SetAlpha(0)

            s.ho, s.hi, s.co, s.hot, s.sp = ho, hi, co, hot, sp
            s.spin = 0
            s.curScale = 1.0
            s.cR, s.cG, s.cB = 0.25, 0.70, 1.0
            s.hoA, s.hiA, s.hotA, s.spA = 0, 0, 0, 0

            bar.blocks[i] = s
        end

        --------------------------------------------------------------------
        -- Events: WoA arms dawnlights, spenders consume, UNIT_AURA tracks wings
        --------------------------------------------------------------------
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ef:RegisterEvent("UNIT_AURA")
        ef:RegisterEvent("PLAYER_TARGET_CHANGED")
        ef:SetScript("OnEvent", function(_, event, unit, _, spellID)
            if event == "PLAYER_TARGET_CHANGED" then
                -- Re-anchor immediately on target change (not waiting for OnUpdate tick)
                bar.currentTarget = nil
                local plate = C_NamePlate.GetNamePlateForUnit("target")
                if plate then
                    bar:ClearAllPoints()
                    bar:SetPoint("BOTTOM", plate, "TOP", 0, 18)
                    bar:Show()
                else
                    bar:Hide()
                end
                return
            end
            if event == "UNIT_AURA" then
                if unit == "player" then
                    bar.hasWings = HasWings()
                end
                return
            end
            if unit ~= "player" then return end
            local now = GetTime()
            if spellID == WAKE_OF_ASHES then
                bar.dawnlightsLeft = 3
                bar.lastDecrement = now
            elseif SPENDERS[spellID] then
                if bar.dawnlightsLeft > 0 and (now - bar.lastDecrement) > 0.5 then
                    bar.dawnlightsLeft = bar.dawnlightsLeft - 1
                    bar.lastDecrement = now
                    if DEBUG then print("[StarBar] spender", spellID, "-> dawnlights", bar.dawnlightsLeft) end
                end
            end
            -- Overcap: generator fired while already at 5 HP (wasted charge)
            if GENERATORS[spellID] then
                local last = bar.lastGenTime[spellID] or 0
                if (now - last) >= 0.4 then
                    bar.lastGenTime[spellID] = now
                    if bar.wasAtFive then
                        SafePlaySound(SND_OVERCAP)
                    end
                end
            end
        end)

        --------------------------------------------------------------------
        -- Per-frame update
        --------------------------------------------------------------------
        bar:SetScript("OnUpdate", function(self, elapsed)
            self.lastUpdate = self.lastUpdate + elapsed
            if self.lastUpdate < 1/30 then return end
            local dt = self.lastUpdate
            self.lastUpdate = 0

            -- Update overcap tracker before any early returns (event handler reads this)
            self.wasAtFive = (UnitPower("player", HOLY_POWER) or 0) >= 5

            local plate = C_NamePlate.GetNamePlateForUnit("target")
            if plate then
                local currentUnit = plate:GetUnit()
                if currentUnit ~= self.currentTarget then
                    self.currentTarget = currentUnit
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOM", plate, "TOP", 0, 18)
                end
                self:Show()
            else
                self:Hide()
                self.currentTarget = nil
                self.lastPower = -1        -- avoid a fake ding on next target
                return
            end

            local power = UnitPower("player", HOLY_POWER) or 0
            local now = GetTime()

            local hasWings = self.hasWings

            -- Power-drop spender detection (ID-agnostic fallback)
            if power < self.lastPower and (self.lastPower - power) >= 3 then
                if self.dawnlightsLeft > 0 and (now - self.lastDecrement) > 0.5 then
                    self.dawnlightsLeft = self.dawnlightsLeft - 1
                    self.lastDecrement = now
                    if DEBUG then print("[StarBar] power-drop spender -> dawnlights", self.dawnlightsLeft) end
                end
            end

            local inAnshe = self.dawnlightsLeft > 0

            -- Bell when you HIT 5 Holy Power (ready to dump)
            local hitFive = self.lastPower >= 0 and self.lastPower < 5 and power >= 5
            if hitFive then
                SafePlaySound(SND_FIVE)
            end

            if DEBUG and (inAnshe or hasWings) then
                print("[StarBar] dawnlights", self.dawnlightsLeft, "wings", hasWings)
            end

            -- Gain / spend pop
            if power > self.lastPower then
                self.popImpulse = 0.34
                self.flash = 1
            elseif power < self.lastPower then
                self.popImpulse = -0.22
            end
            self.lastPower = power

            self.popImpulse = self.popImpulse > 0
                and max(0, self.popImpulse - dt * 8)
                or  min(0, self.popImpulse + dt * 8)
            self.flash = max(0, self.flash - dt * 4)

            local t = now * 3
            local k = min(1, dt * 12)

            ----------------------------------------------------------------
            -- Mode targets. Priority: both > WoA(anshe) > AW(wings) > normal
            ----------------------------------------------------------------
            local mode = "normal"
            local baseScale, spinSpeed = 1.0, 2.5
            -- breatheFreq/breatheAmp: slow unified pulse — stars lunge toward viewer together
            local breatheFreq, breatheAmp = 0.65, 0.07
            local breatheOffset = 0   -- phase offset per star (0 = all together, b.o7 = ripple)
            local coR, coG, coB = 0.25, 0.70, 1.0
            local gR, gG, gB = 0.3, 0.7, 1.0
            local haloA, glowA = 0.08, 0.18
            local spineA, auraA = 0.10, 0.03
            local sparkleOn = false
            local wobAmp = 0   -- 4D wobble intensity, per mode

            if inAnshe and hasWings then
                -- BOTH: red + blue = magenta plasma — absolute maximum
                mode = "both"
                baseScale, spinSpeed = 1.28, 7.0
                breatheFreq, breatheAmp, breatheOffset = 2.5, 0.28, 0.5
                wobAmp = 10
                local p = (sin(now * 9.0) + 1) / 2
                coR, coG, coB = 1.0*(1-p)+0.40*p, 0.12*(1-p)+0.80*p, 0.90
                gR, gG, gB = 0.9, 0.3, 1.0    -- magenta glow
                haloA, glowA = 0.55, 0.82
                spineA, auraA = 0.50, 0.22
                sparkleOn = true

            elseif inAnshe then
                mode = "anshe"
                baseScale, spinSpeed = 1.10, 3.5
                breatheFreq, breatheAmp = 0.85, 0.10
                wobAmp = 4
                local p = (sin(now * 7.5) + 1) / 2
                coR, coG, coB = 0.20*(1-p)+0.50*p, 0.65*(1-p)+0.80*p, 1.0
                gR, gG, gB = 0.35, 0.78, 1.0
                haloA, glowA = 0.14, 0.28
                spineA, auraA = 0.16, 0.05
                sparkleOn = true

            elseif hasWings then
                -- WINGS (AW): red-crimson fire — aggressive, punchy
                mode = "wings"
                baseScale, spinSpeed = 1.16, 4.8
                breatheFreq, breatheAmp = 1.4, 0.16
                wobAmp = 6
                local p = (sin(now * 8.0) + 1) / 2
                coR, coG, coB = 1.0, 0.12*(1-p)+0.22*p, 0.30*(1-p)+0.08*p
                gR, gG, gB = 0.95, 0.18, 0.30   -- red glow on halos/spine
                haloA, glowA = 0.32, 0.55
                spineA, auraA = 0.32, 0.12
                sparkleOn = true
            else
                baseScale = (power >= 5 and 1.08) or (power >= 3 and 1.04) or 1.0
            end

            -- gain flash nudges core toward white + brightens hot center
            local flashMix = self.flash * 0.45
            local fR = coR*(1-flashMix) + 1*flashMix
            local fG = coG*(1-flashMix) + 0.97*flashMix
            local fB = coB*(1-flashMix) + 0.85*flashMix
            local hotBoost = self.flash * 0.5

            -- smooth bar-level glow color (halos + spine + aura share it)
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
                local psh = (sin(t + b.o9) + 1) / 2

                local tScale, tcoR, tcoG, tcoB
                local tHoA, tHiA, tHotA, tSpA
                local tSpin

                if mode == "normal" then
                    if active then
                        tScale = baseScale + sin(now * breatheFreq) * breatheAmp
                        if power >= 5 then
                            tcoR, tcoG, tcoB = 0.40, 0.85, 1.0
                            tHoA, tHiA = 0.08, 0.20
                        else
                            tcoR, tcoG, tcoB = 0.15 + b.pp*0.25, 0.45 + b.pp*0.40, 0.90 + b.pp*0.10
                            tHoA, tHiA = 0.05 + psh*0.02, 0.14
                        end
                        tHotA = 0.12 + psh*0.05
                        tSpA = (power >= 5) and (0.05 + psh*0.04) or 0
                        tSpin = spinSpeed
                    else
                        tScale = 0.88
                        tcoR, tcoG, tcoB = 0.10, 0.10, 0.25
                        tHoA, tHiA, tHotA, tSpA = 0.02, 0.02, 0, 0
                        tSpin = 0
                    end
                else
                    if active then
                        tScale = baseScale + sin(now * breatheFreq + b.o7 * breatheOffset) * breatheAmp
                        tcoR, tcoG, tcoB = fR, fG, fB
                        tHoA = haloA * (0.8 + psh*0.2)
                        tHiA = glowA * (0.8 + psh*0.2)
                        tHotA = 0.16 + psh*0.08 + hotBoost
                        tSpA = sparkleOn and (0.10 + psh*0.10) or 0
                        tSpin = spinSpeed
                    else
                        tScale = 0.82
                        tcoR, tcoG, tcoB = coR*0.20, coG*0.20, coB*0.20
                        tHoA, tHiA = 0.03, 0.04
                        tHotA, tSpA = 0, 0
                        tSpin = spinSpeed * 0.35
                    end
                end

                if active and i == power and self.popImpulse > 0.05 then
                    tScale = tScale + self.popImpulse * 0.18
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

                b.spin = b.spin + dt * tSpin

                -- 4D axis wobble: XY oscillation at irrational (PHI-derived) frequencies
                local wobX = sin(now * 1.3 + b.zp) * (active and wobAmp or 0)
                local wobY = sin(now * (1.3 / PHI) + b.zp) * (active and wobAmp * 0.75 or 0)
                b:ClearAllPoints()
                b:SetPoint("CENTER", bar, "LEFT", STARTX + (i-1)*STEP + wobX, wobY)

                b:SetScale(b.curScale)

                b.ho:SetVertexColor(self.gR, self.gG, self.gB)
                b.ho:SetAlpha(b.hoA)
                b.ho:SetRotation(-b.spin * PHI)

                b.hi:SetVertexColor(self.gR, self.gG, self.gB)
                b.hi:SetAlpha(b.hiA)
                b.hi:SetRotation(b.spin * PHI * PHI)

                b.co:SetVertexColor(b.cR, b.cG, b.cB)
                b.co:SetAlpha(active and 1 or 0.55)
                b.co:SetRotation(-b.spin / PHI)

                b.hot:SetVertexColor(b.cR, b.cG * 0.5, b.cB * 0.3)
                b.hot:SetAlpha(b.hotA)
                b.hot:SetRotation(b.spin * PHI * 3)

                b.sp:SetAlpha(b.spA)
                b.sp:SetRotation(-b.spin * PHI * PHI + i * 0.5)
            end
        end)

        _G.BigJ_StarBar_Final = bar
    end
end
