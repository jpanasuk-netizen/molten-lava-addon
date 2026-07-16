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

    local BLOCK = 40
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
        bar.gR, bar.gG, bar.gB = 1, 0.6, 0.2
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

            -- subtle contrast shadow (fixed size, never resized)
            local bp = s:CreateTexture(nil, "BACKGROUND")
            bp:SetTexture(STAR_TEX)
            bp:SetTexCoord(0, 0.25, 0, 0.25)
            bp:SetSize(BLOCK * 1.05, BLOCK * 1.05)
            bp:SetPoint("CENTER", s, "CENTER", 0, 0)
            bp:SetVertexColor(0.04, 0.03, 0.02)
            bp:SetAlpha(0.22)

            -- outer halo
            local ho = s:CreateTexture(nil, "BORDER")
            ho:SetTexture(STAR_TEX)
            ho:SetTexCoord(0, 0.25, 0, 0.25)
            ho:SetBlendMode("ADD")
            ho:SetSize(BLOCK * 1.95, BLOCK * 1.95)
            ho:SetPoint("CENTER", s, "CENTER", 0, 0)
            ho:SetAlpha(0)

            -- inner halo
            local hi = s:CreateTexture(nil, "ARTWORK")
            hi:SetTexture(STAR_TEX)
            hi:SetTexCoord(0, 0.25, 0, 0.25)
            hi:SetBlendMode("ADD")
            hi:SetSize(BLOCK * 1.3, BLOCK * 1.3)
            hi:SetPoint("CENTER", s, "CENTER", 0, 0)
            hi:SetAlpha(0)

            -- core star (readable glyph)
            local co = s:CreateTexture(nil, "ARTWORK")
            co:SetTexture(STAR_TEX)
            co:SetTexCoord(0, 0.25, 0, 0.25)
            co:SetSize(BLOCK, BLOCK)
            co:SetPoint("CENTER", s, "CENTER", 0, 0)
            co:SetVertexColor(1, 0.5, 0.1)

            -- hot inner core
            local hot = s:CreateTexture(nil, "OVERLAY")
            hot:SetTexture(STAR_TEX)
            hot:SetTexCoord(0, 0.25, 0, 0.25)
            hot:SetBlendMode("ADD")
            hot:SetSize(BLOCK * 0.55, BLOCK * 0.55)
            hot:SetPoint("CENTER", s, "CENTER", 0, 0)
            hot:SetVertexColor(1, 0.95, 0.65)
            hot:SetAlpha(0)

            -- sparkle twinkle
            local sp = s:CreateTexture(nil, "OVERLAY")
            sp:SetTexture(SPARK_TEX)
            sp:SetBlendMode("ADD")
            sp:SetSize(BLOCK * 1.25, BLOCK * 1.25)
            sp:SetPoint("CENTER", s, "CENTER", 0, 0)
            sp:SetVertexColor(1, 0.95, 0.8)
            sp:SetAlpha(0)

            s.bp, s.ho, s.hi, s.co, s.hot, s.sp = bp, ho, hi, co, hot, sp
            s.spin = 0
            s.curScale = 1.0
            s.cR, s.cG, s.cB = 1, 0.5, 0.1
            s.hoA, s.hiA, s.hotA, s.spA, s.bpA = 0, 0, 0, 0, 0.22

            bar.blocks[i] = s
        end

        --------------------------------------------------------------------
        -- Events: WoA arms dawnlights, spenders consume, UNIT_AURA tracks wings
        --------------------------------------------------------------------
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ef:RegisterEvent("UNIT_AURA")
        ef:SetScript("OnEvent", function(_, event, unit, _, spellID)
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
            local coR, coG, coB = 1, 0.5, 0.1
            local gR, gG, gB = 1, 0.6, 0.2
            local haloA, glowA = 0.08, 0.18
            local spineA, auraA = 0.10, 0.03
            local sparkleOn = false

            if inAnshe and hasWings then
                mode = "both"
                baseScale, spinSpeed = 1.18, 5.0
                local p = (sin(now * 9.0) + 1) / 2
                coR, coG, coB = 1, 0.97*(1-p)+0.80*p, 0.86*(1-p)+0.42*p
                gR, gG, gB = 1, 0.96, 0.62
                haloA, glowA = 0.20, 0.38
                spineA, auraA = 0.22, 0.08
                sparkleOn = true

            elseif inAnshe then
                mode = "anshe"
                baseScale, spinSpeed = 1.10, 3.5
                local p = (sin(now * 7.5) + 1) / 2
                coR, coG, coB = 1, 0.96*(1-p)+0.55*p, 0.86*(1-p)+0.06*p
                gR, gG, gB = 1, 0.90, 0.50
                haloA, glowA = 0.14, 0.28
                spineA, auraA = 0.16, 0.05
                sparkleOn = true

            elseif hasWings then
                mode = "wings"
                baseScale, spinSpeed = 1.14, 4.0
                local p = (sin(now * 6.3) + 1) / 2
                coR, coG, coB = 1, 0.55*(1-p)+0.30*p, 0.18*(1-p)+0.05*p
                gR, gG, gB = 1, 0.62, 0.20
                haloA, glowA = 0.16, 0.30
                spineA, auraA = 0.18, 0.06
                sparkleOn = true
            else
                baseScale = (power >= 5 and 1.08) or (power >= 3 and 1.04) or 1.0
                baseScale = baseScale + sin(t) * 0.02
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
                local tHoA, tHiA, tHotA, tSpA, tBpA
                local tSpin

                if mode == "normal" then
                    if active then
                        tScale = baseScale + sin(t + b.o7) * 0.02
                        if power >= 5 then
                            tcoR, tcoG, tcoB = 1, 0.60, 0.16
                            tHoA, tHiA = 0.08, 0.20
                        else
                            tcoR, tcoG, tcoB = 0.72 + b.pp*0.28, 0.26 + b.pp*0.22, 0.05
                            tHoA, tHiA = 0.05 + psh*0.02, 0.14
                        end
                        tHotA = 0.12 + psh*0.05
                        tSpA = (power >= 5) and (0.05 + psh*0.04) or 0
                        tBpA = 0.22
                        tSpin = spinSpeed
                    else
                        tScale = 0.88
                        tcoR, tcoG, tcoB = 0.16, 0.11, 0.07
                        tHoA, tHiA, tHotA, tSpA = 0.02, 0.02, 0, 0
                        tBpA = 0.14
                        tSpin = 0
                    end
                else
                    if active then
                        tScale = baseScale + sin(t + b.o7) * 0.02
                        tcoR, tcoG, tcoB = fR, fG, fB
                        tHoA = haloA * (0.8 + psh*0.2)
                        tHiA = glowA * (0.8 + psh*0.2)
                        tHotA = 0.16 + psh*0.08 + hotBoost
                        tSpA = sparkleOn and (0.06 + psh*0.06) or 0
                        tBpA = 0.22
                        tSpin = spinSpeed
                    else
                        tScale = 0.82
                        tcoR, tcoG, tcoB = coR*0.20, coG*0.20, coB*0.20
                        tHoA, tHiA = 0.03, 0.04
                        tHotA, tSpA = 0, 0
                        tBpA = 0.14
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
                b.bpA = b.bpA + (tBpA - b.bpA) * k

                b.spin = b.spin + dt * tSpin

                b:SetScale(b.curScale)

                b.bp:SetAlpha(b.bpA)
                -- backplate fixed size, barely rotates

                b.ho:SetVertexColor(self.gR, self.gG, self.gB)
                b.ho:SetAlpha(b.hoA)
                b.ho:SetRotation(-b.spin * 1.2)    -- outer counter-spin

                b.hi:SetVertexColor(self.gR, self.gG, self.gB)
                b.hi:SetAlpha(b.hiA)
                b.hi:SetRotation(b.spin * 1.8)     -- inner co-spin faster

                b.co:SetVertexColor(b.cR, b.cG, b.cB)
                b.co:SetAlpha(active and 1 or 0.85)
                b.co:SetRotation(-b.spin * 0.12)   -- core barely moves (readable)

                b.hot:SetAlpha(b.hotA)
                b.hot:SetRotation(b.spin * 3.5)    -- hot center screams inward (vortex focal point)

                b.sp:SetAlpha(b.spA)
                b.sp:SetRotation(-b.spin * 1.5 + i * 0.5)
            end
        end)

        _G.BigJ_StarBar_Final = bar
    end
end
