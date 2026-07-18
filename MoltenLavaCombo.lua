function (self, unitId, unitFrame, envTable, modTable)
    -- Everything below only needs to run ONCE. Plater calls this hook
    -- function on every update tick (i.e. many times per second), and before
    -- this fix we were reprinting the version banner and rebuilding the
    -- GENERATORS/SPENDERS tables plus the SafePlaySound closure from scratch on
    -- EVERY single one of those calls -- constant chat prints and table/closure
    -- garbage allocation happening dozens of times a second, forever. That's what
    -- was actually causing the lag. This early-return guard means every call
    -- after the very first one does nothing but a single cheap global lookup.
    if _G.BigJ_StarBar_Final then return end
   
    print("[StarBar VERSION] v13.7 (build 29) -- Dawnlight pips: added solid dark outline/border for much better visibility + slightly larger size and stronger glow. Molten color cycle kept.")
   
    --------------------------------------------------------------------
    -- Config
    --------------------------------------------------------------------
    local STAR_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX = "Interface\\Cooldown\\star4" -- ornamental twinkle (blank if path changes)
    local SOLID = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower
   
    local DEBUG = false -- print dawnlights/wings state while testing (cast-id diagnostic done, turned back off)
    local SOUND_ON = true -- bell when you hit 5 Holy Power
   
    -- Bell sound: SoundKitID 162888 (FX_Ship_Bell_Chime_01) -- confirmed in-game by the
    -- player via a direct /run PlaySound(162888, "Master", false) test. Actually verified
    -- audible this time, not just guessed from a wiki/forum name.
    local SND_FIVE = 162888
   
    -- Holy Power generators. When one of these successfully casts while you're ALREADY
    -- at 5 Holy Power, it did nothing (you're capped) -- that's the "wasted generator"
    -- moment we want to ding on. Multiple IDs per ability on purpose: current-expansion
    -- redesigns keep reissuing new spell IDs for the "same" ability (already bit us once
    -- with Avenging Wrath/Final Verdict), so listing known variants is cheap insurance.
    local GENERATORS = {
        [35395] = true, -- Crusader Strike (older id)
        [1227637] = true, -- Crusader Strike (current redesign id)
        [20271] = true, -- Judgment (older id)
        [275779] = true, -- Judgment (newer id)
        [184575] = true, -- Blade of Justice
        [24275] = true, -- Hammer of Wrath (older id)
        [1241288] = true, -- Hammer of Wrath (current redesign id)
        [407480] = true, -- Templar Strike (REAL current id, confirmed 2026-07-16 straight from the player's own
        -- /run debug print -- 444722 (my earlier guess) was wrong and never matched, which is
        -- exactly why only every OTHER hit (Templar Slash) was dinging.
        [198036] = true, -- "Templar's Strike" (old/unrelated leftover id, harmless to keep as a fallback)
        [406647] = true, -- Templar Slash (2nd half of the Templar Strikes talent combo, confirmed correct)
    }
   
    local WAKE_OF_ASHES = 255937
    local AVENGING_WRATH_DURATION = 20 -- base seconds; bump this up if you have talents that extend Wings
    -- NOTE: the old DAWNLIGHTS_WINDOW=12 auto-revert timer has been removed entirely.
    -- Dawnlight charges have no time-based expiry in the real game -- they're only
    -- consumed by an actual spender cast, confirmed against tooltip/community data.
    local SPENDERS = {
        [85256] = true, -- Templar's Verdict
        [336872] = true, -- Final Verdict
        [383328] = true, -- Final Verdict (alt id)
        [53385]  = true, -- Divine Storm (PRIMARY / current player cast that costs 3 HP)
        [224239] = true, -- Divine Storm (secondary / echo / old Legion ID – still fires sometimes)
        [215661] = true, -- Justicar's Vengeance
        [53600]  = true, -- Shield of the Righteous
        [85673]  = true, -- Word of Glory
    }
   
    -- hoisted math
    local sin, min, max = math.sin, math.min, math.max
   
    local BLOCK = 40
    local STEP = 47
    local NUM = 5
    local BAR_W = 250
    local STARTX = (BAR_W - (NUM - 1) * STEP) / 2
   
    -- Dawnlight charge pip row config. Declared here, AFTER BAR_W/STEP above,
    -- on purpose -- a past revision of this script put an equivalent line up
    -- in the Config block BEFORE BAR_W existed as a local, which silently read
    -- a nonexistent global BAR_W (nil) and crashed the whole script on load.
    -- Never move this block above the BAR_W/STEP/NUM declarations.
    local NUM_DAWNLIGHT = 3
    local DL_STEP = 28
    local DL_SIZE = 20
    local DL_STARTX = (BAR_W - (NUM_DAWNLIGHT - 1) * DL_STEP) / 2
   
    -- Avenging Wrath detection: tracked off the CAST event + a fixed duration
    -- timer, exactly like Wake of Ashes' dawnlights below -- NOT via the aura
    -- API. The aura-existence check (C_UnitAuras.GetPlayerAuraBySpellID) never
    -- reliably flipped true in-game even though it never crashed, so it's been
    -- dropped entirely in favor of this proven cast+timer approach.
    local AVENGING_WRATH_ID = 31884
    local CRUSADE_ID = 231895 -- Retribution's version of Wings; same duration logic
   
    -- NOTE: no pcall/xpcall anywhere in this script -- Plater's sandbox for
    -- this hook does not expose pcall/xpcall as callable globals at all
    -- (confirmed repeatedly: every pcall/xpcall call site has thrown
    -- "attempt to call a nil value" pointing right at that call).
   
    -- DIAGNOSTIC: print PlaySound's own return values to chat every time we try to
    -- ding. willPlay=false means WoW itself is refusing to play it (settings/cvar
    -- issue, not our code); no print at all would mean this code path never even runs.
    local SOUND_DEBUG = false -- sound confirmed working in-game; leave off to avoid a chat print on every ding
   
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
    -- bar-level smoothed glow color (shared byhalos, spine, aura)
    bar.gR, bar.gG, bar.gB = 1, 0.6, 0.2
    bar.auraA = 0.10
   
    bar:Show()
    bar:SetAlpha(0)
   
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
   
    --------------------------------------------------------------------
    -- Dawnlight charge pips – molten + dark outline for visibility
    --------------------------------------------------------------------
    bar.dawnlightPips = {}
    for i = 1, NUM_DAWNLIGHT do
        local p = CreateFrame("Frame", nil, bar)
        p:SetFrameLevel(bar:GetFrameLevel() + 3)
        p:SetSize(DL_SIZE, DL_SIZE)
        p:SetPoint("CENTER", bar, "LEFT", DL_STARTX + (i - 1) * DL_STEP, -33)
       
        -- Dark outline / border (solid, slightly larger) – this is what makes them pop
        local outline = p:CreateTexture(nil, "BACKGROUND")
        outline:SetTexture(STAR_TEX)
        outline:SetTexCoord(0, 0.25, 0, 0.25)
        outline:SetSize(DL_SIZE * 1.38, DL_SIZE * 1.38)
        outline:SetPoint("CENTER", p, "CENTER", 0, 0)
        outline:SetVertexColor(0.02, 0.02, 0.04)
        outline:SetAlpha(0.85)
       
        -- Outer glow (additive, follows molten color)
        local glow = p:CreateTexture(nil, "BORDER")
        glow:SetTexture(STAR_TEX)
        glow:SetTexCoord(0, 0.25, 0, 0.25)
        glow:SetBlendMode("ADD")
        glow:SetSize(DL_SIZE * 2.15, DL_SIZE * 2.15)
        glow:SetPoint("CENTER", p, "CENTER", 0, 0)
        glow:SetAlpha(0)
       
        -- Main core
        local core = p:CreateTexture(nil, "ARTWORK")
        core:SetTexture(STAR_TEX)
        core:SetTexCoord(0, 0.25, 0, 0.25)
        core:SetAllPoints(p)
        core:SetVertexColor(0.2, 0.5, 1.0)
        core:SetAlpha(0.25)
       
        -- Hot center spark
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
   
    --------------------------------------------------------------------
    -- Events: WoA arms dawnlights, spenders consume, AW/Crusade cast arms wings
    --------------------------------------------------------------------
    local ef = CreateFrame("Frame", "BigJ_StarBar_EventFrame")
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
                -- IMPORTANT: do NOT touch bar.lastDecrement here. lastDecrement is a
                -- debounce timestamp meant only for "a charge was just actually spent"
                -- (used below, and in the OnUpdate power-drop fallback, to avoid double-
                -- decrementing the same spend twice). It used to get stamped here too
                -- which meant your FIRST spender cast right after Wake of Ashes (within
                -- 0.5s of it) always looked like "you just decremented 0.5s ago" and got
                -- silently skipped -- exactly the "first Divine Storm doesn't register"
                -- bug. Arming dawnlights and spending a charge are different events and
                -- must not share this timestamp.
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
                    if DEBUG then print("[StarBar] generator used at cap (power=" .. power .. ") -- ding") end
                end
            end
           
            local hasWings = self.wingsUntil and (now < self.wingsUntil)
           
            if power < self.lastPower and (self.lastPower - power) >= 3 then
                if self.dawnlightsLeft > 0 and (now - self.lastDecrement) > 0.5 then
                    self.dawnlightsLeft = self.dawnlightsLeft - 1
                    self.lastDecrement = now
                    if DEBUG then print("[StarBar] power-drop spender -> dawnlights", self.dawnlightsLeft) end
                end
            end
           
            local inAnshe = self.dawnlightsLeft > 0
           
            if DEBUG and (inAnshe or hasWings) then
                print("[StarBar] dawnlights", self.dawnlightsLeft, "wings", hasWings)
            end
           
            if power > self.lastPower then
                self.popImpulse = 0.26
                self.flash = 0.8
            elseif power < self.lastPower then
                self.popImpulse = -0.16
            end
            self.lastPower = power
           
            self.popImpulse = self.popImpulse > 0
            and max(0, self.popImpulse - dt * 8)
            or min(0, self.popImpulse + dt * 8)
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
           
            ----------------------------------------------------------------
            -- Render Dawnlight pips – molten + dark outline
            ----------------------------------------------------------------
            for i = 1, NUM_DAWNLIGHT do
                local p = self.dawnlightPips[i]
                local lit = i <= self.dawnlightsLeft
               
                local phase = now * 4.8 + p.phase
                local pulse = (sin(phase) + 1) * 0.5
                local slow  = (sin(now * 2.6 + p.phase) + 1) * 0.5
               
                local targetScale, tA, gA, hA, oA
                local r, g, b
               
                if lit then
                    targetScale = 1.00 + pulse * 0.14          -- still gentle
                    
                    -- Molten lava: deep electric blue ↔ hot molten red
                    r = 0.12 + slow * 0.88
                    g = 0.35 + (1 - slow) * 0.35
                    b = 1.00 - slow * 0.75
                    
                    tA = 0.92 + pulse * 0.08
                    gA = 0.32 + pulse * 0.38                   -- stronger glow
                    hA = 0.55 + pulse * 0.35
                    oA = 0.95                                  -- solid dark outline
                else
                    targetScale = 0.80 + pulse * 0.07
                    r, g, b = 0.13, 0.20, 0.42
                    tA = 0.22 + pulse * 0.06
                    gA = 0.06 + pulse * 0.05
                    hA = 0
                    oA = 0.55                                  -- outline still visible when dim
                end
               
                p.curScale = p.curScale + (targetScale - p.curScale) * k
                p:SetScale(p.curScale)
               
                -- Dark outline (the readability key)
                p.outline:SetAlpha(oA)
               
                -- Core
                p.dlA = p.dlA + (tA - p.dlA) * k
                p.core:SetAlpha(p.dlA)
                p.core:SetVertexColor(r, g, b)
               
                -- Outer glow
                p.glow:SetAlpha(gA)
                p.glow:SetVertexColor(r * 0.65 + 0.35, g * 0.55, b)
               
                -- Hot center
                p.hot:SetAlpha(hA)
                p.hot:SetVertexColor(
                    min(1, r + 0.45),
                    min(1, g + 0.35),
                    min(1, b + 0.25)
                )
            end
    end)
   
    _G.BigJ_StarBar_Final = bar
    print("[StarBar] construction succeeded, bar created.")
end
