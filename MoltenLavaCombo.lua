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

    print("[StarBar VERSION] v20.0 (build 31) -- PERFORMANCE REWRITE: lower-churn update path with one-time frame construction, throttled rendering, and target-change re-anchor behavior.")

    --------------------------------------------------------------------
    -- Config
    --------------------------------------------------------------------
    local STAR_TEX  = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
    local SPARK_TEX = "Interface\\Cooldown\\star4"          -- ornamental twinkle (blank if path changes)
    local SOLID     = "Interface\\Buttons\\WHITE8X8"
    local HOLY_POWER = Enum.PowerType.HolyPower

    local DEBUG    = false      -- print dawnlights/wings state while testing (cast-id diagnostic done, turned back off)
    local SOUND_ON = true       -- bell when you hit 5 Holy Power

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
        [35395]   = true, -- Crusader Strike (older id)
        [1227637] = true, -- Crusader Strike (current redesign id)
        [20271]   = true, -- Judgment (older id)
        [275779]  = true, -- Judgment (newer id)
        [184575]  = true, -- Blade of Justice
        [24275]   = true, -- Hammer of Wrath (older id)
        [1241288] = true, -- Hammer of Wrath (current redesign id)
        [407480]  = true, -- Templar Strike (REAL current id, confirmed 2026-07-16 straight from the player's own
                           -- /run debug print -- 444722 (my earlier guess) was wrong and never matched, which is
                           -- exactly why only every OTHER hit (Templar Slash) was dinging.
        [198036]  = true, -- "Templar's Strike" (old/unrelated leftover id, harmless to keep as a fallback)
        [406647]  = true, -- Templar Slash (2nd half of the Templar Strikes talent combo, confirmed correct)
    }

    local WAKE_OF_ASHES = 255937
    local AVENGING_WRATH_DURATION = 20   -- base seconds; bump this up if you have talents that extend Wings
    local DAWNLIGHTS_WINDOW = 12          -- seconds you have to spend all 3 dawnlight stacks before it reverts to normal
    local SPENDERS = {
        [85256]  = true, -- Templar's Verdict
        [336872] = true, -- Final Verdict
        [383328] = true, -- Final Verdict (alt id)
        [224239] = true, -- Divine Storm
        [215661] = true, -- Justicar's Vengeance
        [53600]  = true, -- Shield of the Righteous
        [85673]  = true, -- Word of Glory
    }

    -- hoisted math
    local sin, min, max = math.sin, math.min, math.max

    local BLOCK = 40
    local STEP  = 47
    local NUM   = 5
    local BAR_W = 250
    local STARTX = (BAR_W - (NUM - 1) * STEP) / 2

    -- Avenging Wrath detection: tracked off the CAST event + a fixed duration
    -- timer, exactly like Wake of Ashes' dawnlights below -- NOT via the aura
    -- API. The aura-existence check (C_UnitAuras.GetPlayerAuraBySpellID) never
    -- reliably flipped true in-game even though it never crashed, so it's been
    -- dropped entirely in favor of this proven cast+timer approach.
    local AVENGING_WRATH_ID = 31884
    local CRUSADE_ID = 231895   -- Retribution's version of Wings; same duration logic

    -- NOTE: no pcall/xpcall anywhere in this script -- Plater's sandbox for
    -- this hook does not expose pcall/xpcall as callable globals at all
    -- (confirmed repeatedly: every pcall/xpcall call site has thrown
    -- "attempt to call a nil value" pointing right at that call).

    -- DIAGNOSTIC: print PlaySound's own return values to chat every time we try to
    -- ding. willPlay=false means WoW itself is refusing to play it (settings/cvar
    -- issue, not our code); no print at all would mean this code path never even runs.
    local SOUND_DEBUG = false   -- sound confirmed working in-game; leave off to avoid a chat print on every ding

    local function SafePlaySound(kit)
        if SOUND_ON and kit then
            -- "Master" channel instead of "SFX": some players' SFX channel volume
            -- (or sub-mixer state) blocks addon-triggered PlaySound calls even when the
            -- exact same call works fine from a plain /run macro. Master is the most
            -- reliable channel for guaranteeing playback regardless of SFX slider state.
            -- forceNoDuplicates = false: sound 888 is reused all over the base game
            -- (guild member online, level-up, etc.) -- if that flag were true, any
            -- unrelated 888 elsewhere could make WoW silently swallow OUR ding as a
            -- "duplicate." Always force it to actually play.
            local willPlay, handle = PlaySound(kit, "Master", false)
            if SOUND_DEBUG then
                print("[StarBar SOUND] PlaySound(" .. tostring(kit) .. ", Master, false) -> willPlay=" .. tostring(willPlay) .. " handle=" .. tostring(handle))
            end
        elseif SOUND_DEBUG then
            print("[StarBar SOUND] SafePlaySound skipped -- SOUND_ON=" .. tostring(SOUND_ON) .. " kit=" .. tostring(kit))
        end
    end

    -- No C_Timer usage here on purpose: Plater's sandbox for this hook already strips
    -- out other globals (pcall/xpcall), so we can't be sure C_Timer exists either.
    -- (No delayed/queued dings needed anymore -- the generator-while-capped ding fires
    -- once, synchronously, from the UNIT_SPELLCAST_SUCCEEDED handler.)

    local bar = CreateFrame("Frame", "BigJ_StarBar_Final", UIParent)
    bar:SetSize(BAR_W, 70)
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
    -- bar-level smoothed glow color (shared by halos, spine, aura)
    bar.gR, bar.gG, bar.gB = 1, 0.6, 0.2
    bar.auraA = 0.10

    -- IMPORTANT: never call bar:Hide() anywhere. A frame's OnUpdate script
    -- stops firing entirely while the frame is hidden, so if OnUpdate ever
    -- hides the frame itself, it can never run again to show itself back --
    -- that's what was causing the bar to "detach"/disappear permanently.
    -- We keep the frame always :Show()'n and use SetAlpha(0/1) to fade
    -- visibility instead, so OnUpdate always keeps ticking.
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

        -- precomputed per-star offsets
        s.o7 = i * 0.7
        s.o9 = i * 0.9
        s.pp = i / NUM

        -- dark contrast backplate
        local bp = s:CreateTexture(nil, "BACKGROUND")
        bp:SetTexture(STAR_TEX)
        bp:SetTexCoord(0, 0.25, 0, 0.25)
        bp:SetSize(BLOCK * 1.45, BLOCK * 1.45)
        bp:SetPoint("CENTER", s, "CENTER", 0, 0)
        bp:SetVertexColor(0.05, 0.04, 0.03)
        bp:SetAlpha(0.45)

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
        s.curScale = 1
        s.cR, s.cG, s.cB = 1, 0.5, 0.1
        s.hoA, s.hiA, s.hotA, s.spA, s.bpA = 0, 0, 0, 0, 0.45

        bar.blocks[i] = s
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
            bar.lastDecrement = now
            bar.dawnlightsExpire = now + DAWNLIGHTS_WINDOW
        elseif SPENDERS[spellID] then
            if bar.dawnlightsLeft > 0 and (now - bar.lastDecrement) > 0.5 then
                bar.dawnlightsLeft = bar.dawnlightsLeft - 1
                bar.lastDecrement = now
                if DEBUG then print("[StarBar] spender", spellID, "-> dawnlights", bar.dawnlightsLeft) end
            end
        elseif GENERATORS[spellID] then
            -- Don't read UnitPower right here -- the client hasn't necessarily
            -- applied the resource gain from THIS cast yet by the time this event
            -- fires, so checking now reads the PRE-cast value (that's why it used
            -- to look like it took 3 attempts to ding: it was really dinging one
            -- cast late every time). Instead, flag it and let the OnUpdate loop
            -- below check fresh UnitPower on its very next tick, which is always
            -- after the resource update has landed.
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
            self:SetAlpha(1)   -- fade in, never Hide() -- see note above
        else
            self:SetAlpha(0)   -- fade out, but stay :Show()'n so OnUpdate keeps running
            self.lastPower = -1        -- avoid a fake ding on next target
            return
        end

        local power = UnitPower("player", HOLY_POWER) or 0
        local now = GetTime()

        -- Resolve any generator cast flagged since the last tick, now that
        -- UnitPower is guaranteed fresh (see note in the event handler above).
        if self.pendingGeneratorPing then
            self.pendingGeneratorPing = false
            if power >= 5 then
                SafePlaySound(SND_FIVE)
                if DEBUG then print("[StarBar] generator used at cap (power=" .. power .. ") -- ding") end
            end
        end

        local hasWings = self.wingsUntil and (now < self.wingsUntil)

        -- If dawnlight stacks aren't all spent within the window, snap back
        -- to normal instead of staying lit forever.
        if self.dawnlightsLeft > 0 and self.dawnlightsExpire and now > self.dawnlightsExpire then
            self.dawnlightsLeft = 0
            if DEBUG then print("[StarBar] dawnlights window expired, reverting to normal") end
        end

        -- Power-drop spender detection (ID-agnostic fallback)
        if power < self.lastPower and (self.lastPower - power) >= 3 then
            if self.dawnlightsLeft > 0 and (now - self.lastDecrement) > 0.5 then
                self.dawnlightsLeft = self.dawnlightsLeft - 1
                self.lastDecrement = now
                if DEBUG then print("[StarBar] power-drop spender -> dawnlights", self.dawnlightsLeft) end
            end
        end

        local inAnshe = self.dawnlightsLeft > 0

        -- (Sound is now handled entirely by the GENERATORS check in the
        -- UNIT_SPELLCAST_SUCCEEDED handler above -- dings when you use a generator
        -- while already at 5 Holy Power. No separate "just reached 5" or double-tap
        -- logic needed here anymore.)

        if DEBUG and (inAnshe or hasWings) then
            print("[StarBar] dawnlights", self.dawnlightsLeft, "wings", hasWings)
        end

        -- Gain / spend pop
        if power > self.lastPower then
            self.popImpulse = 0.26
            self.flash = 0.8
        elseif power < self.lastPower then
            self.popImpulse = -0.16
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
        local baseScale, spinSpeed = 1.0, 3.0
        local coR, coG, coB = 1, 0.5, 0.1     -- core color target (mode-level default)
        local gR, gG, gB = 1, 0.6, 0.2        -- glow color target (bar-level)
        local haloA, glowA = 0.18, 0.45       -- base alphas for active stars
        local spineA, auraA = 0.22, 0.06
        local sparkleOn = false

        if inAnshe and hasWings then
            -- BOTH: the most intense state, but toned down from before
            mode = "both"
            baseScale, spinSpeed = 1.42, 4.2
            local p = (sin(now * 9.0) + 1) / 2
            coR, coG, coB = 1, 0.97*(1-p)+0.80*p, 0.86*(1-p)+0.42*p
            gR, gG, gB = 1, 0.96, 0.62
            haloA, glowA = 0.38, 0.74
            spineA, auraA = 0.44, 0.16
            sparkleOn = true

        elseif inAnshe then
            -- WoA alone: clean bright-yellow rotating throb (unchanged hue, toned down)
            mode = "anshe"
            baseScale, spinSpeed = 1.14, 2.9
            local p = (sin(now * 7.5) + 1) / 2
            coR, coG, coB = 1, 0.96*(1-p)+0.55*p, 0.86*(1-p)+0.06*p
            gR, gG, gB = 1, 0.90, 0.50
            haloA, glowA = 0.27, 0.59
            spineA, auraA = 0.32, 0.10
            sparkleOn = true

        elseif hasWings then
            -- AW alone: "holy molten glow" -- deliberately white-gold and hot,
            -- NOT the same orange as normal-mode-at-5-power, so it reads as a
            -- clearly distinct effect instead of blending into normal.
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

            -- ease toward targets
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
    end)

    _G.BigJ_StarBar_Final = bar
    print("[StarBar] construction succeeded, bar created.")
end
