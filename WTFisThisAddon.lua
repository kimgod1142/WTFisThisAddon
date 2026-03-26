-- WTFisThisAddon.lua
-- UI 프레임을 마우스로 가리키면 어떤 애드온이 만든 건지 알려주는 검사 도구
-- /wita 또는 /wtfisthis 로 검사 모드 토글

local ADDON_NAME = "WTFisThisAddon"
local VERSION    = "1.1.0"
local L          = WTFisThisAddon_L   -- Locales.lua 에서 로드됨

-- ================================================================
-- CONFIG
-- ================================================================
local CFG = {
    SCAN_THROTTLE = 0.05,   -- 프레임 감지 주기 (초) — 50ms = 최대 20회/s
    PARENT_DEPTH  = 6,      -- 부모 체인 탐색 최대 깊이
    POPUP_PARENTS = 3,      -- 팝업에 표시할 부모 체인 수
}

-- ================================================================
-- STATE
-- ================================================================
local WITA = {
    active     = false,
    detailMode = false,  -- false = 간단 보기, true = 자세히 보기
    db         = nil,
    ownFrames  = {},     -- 자기 자신 프레임 집합 (검사 대상 제외용)
}

-- ================================================================
-- ICONS: 이모지 대신 WoW 인라인 텍스처
-- ================================================================
local ICO = {
    ADDON    = "|TInterface\\Icons\\INV_Misc_Bag_07:14:14|t",
    BLIZZARD = "|TInterface\\Icons\\INV_Misc_Rune_01:14:14|t",
    UNKNOWN  = "|TInterface\\Icons\\INV_Misc_QuestionMark:14:14|t",
    GEAR     = "|TInterface\\Icons\\Trade_Engineering:14:14|t",
    EYE      = "Interface\\Icons\\Spell_Holy_MindVision",
}


-- ================================================================
-- SECTION 1: SAFE HELPERS
-- ================================================================

--- pcall 래퍼 — 실패하면 nil 반환
local function SafeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

--- 숫자 반환 함수를 안전하게 호출 후 floor — Secret 값이면 0 반환
--- (WoW 12.0+: HP바 등에서 GetWidth/GetHeight가 secret number를 반환할 수 있음)
local function SafeNum(fn, obj)
    local ok, v = pcall(fn, obj)
    if not ok or v == nil then return 0 end
    local ok2, n = pcall(math.floor, v)
    return ok2 and n or 0
end

--- 경로 구분자 정규화 (Mac: / → \) + @ 접두사 제거
local function NormalizePath(location)
    if not location then return nil end
    return location:gsub("^@", ""):gsub("/", "\\")
end


-- ================================================================
-- SECTION 2: ADDON CACHE
-- 로드 시 모든 애드온 폴더명 → TOC 타이틀 매핑
-- ================================================================
local addonCache = {}   -- [folderName:lower()] = { folder, title }

local function BuildAddonCache()
    local getCount = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
    local getInfo  = (C_AddOns and C_AddOns.GetAddOnInfo)  or GetAddOnInfo
    if not getCount or not getInfo then return end

    local count = getCount()
    for i = 1, count do
        local folder, title = getInfo(i)
        if folder then
            addonCache[folder:lower()] = {
                folder = folder,
                title  = (title and title ~= "") and title or folder,
            }
        end
    end
end

local function GetAddonTitle(folderName)
    if not folderName then return nil end
    local entry = addonCache[folderName:lower()]
    return entry and entry.title or folderName
end


-- ================================================================
-- SECTION 3: FRAME ANALYSIS + CACHE
-- weak key 테이블: 프레임이 GC되면 캐시 항목도 자동 제거
-- ================================================================
local frameInfoCache = setmetatable({}, { __mode = "k" })
local frameRootCache = setmetatable({}, { __mode = "k" })

local function ParseLocation(location)
    if not location or location == "" or location == "UnknownFile" then
        return nil
    end
    local loc = NormalizePath(location)

    -- AddOns 경로
    local addonFolder, file, line =
        loc:match("[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\]+)\\(.+):(%d+)")
    if addonFolder then
        -- Blizzard_ 접두사 폴더 = Blizzard 자체 모듈 (기본 UI로 처리)
        if addonFolder:match("^[Bb]lizzard_") then
            return { type = "blizzard", name = addonFolder, title = "기본 UI",
                     file = file,       line = line,         raw  = location }
        end
        return { type = "addon",    name = addonFolder,   title = GetAddonTitle(addonFolder),
                 file = file,       line = line,           raw  = location }
    end

    -- Blizzard 기본 UI (FrameXML 경로 등)
    if loc:find("[Ff]rame[Xx][Mm][Ll]")
    or loc:find("[Bb]lizzard[Ii]nterface[Cc]ode")
    or loc:find("[Ii]nterface\\[Bb]uilt[Ii]n") then
        return { type = "blizzard", name = "Blizzard UI", title = "기본 UI",
                 file = loc:match("([^\\]+%.lua):%d+") or "?",
                 line = loc:match(":(%d+)$") or "?",
                 raw  = location }
    end

    return { type = "unknown",  name = "Unknown",     title = "Unknown",
             file = loc,        line = "?",            raw  = location }
end

local function QuickGetFolder(location)
    if not location then return nil end
    return NormalizePath(location):match("[Ii]nterface\\[Aa]dd[Oo]ns\\([^\\]+)\\")
end

local function GuessAddonFromName(frameName)
    if not frameName then return nil end
    return frameName:match("^([A-Za-z][A-Za-z0-9]+)[_%-]") or nil
end

--- 프레임 분석 (결과 캐시)
local function AnalyzeFrame(frame)
    if frameInfoCache[frame] then return frameInfoCache[frame] end

    local result = {
        frameName    = frame:GetName() or L.UNNAMED_FRAME,
        debugName    = SafeCall(frame.GetDebugName,   frame) or L.NO_DEBUG_NAME,
        source       = nil,
        nameGuess    = nil,
        rawLoc       = nil,
        width        = SafeNum(frame.GetWidth,  frame),
        height       = SafeNum(frame.GetHeight, frame),
        strata       = SafeCall(frame.GetFrameStrata, frame) or "?",
        level        = SafeCall(frame.GetFrameLevel,  frame) or "?",
        parentChain  = {},
        contributors = {},
    }

    local loc = SafeCall(frame.GetSourceLocation, frame)
    if loc then
        result.source = ParseLocation(loc)
        result.rawLoc = loc
    end

    if not result.source or result.source.type == "unknown" then
        result.nameGuess = GuessAddonFromName(frame:GetName())
    end

    local seen       = {}
    local mainFolder = result.source and result.source.name or ""
    if mainFolder ~= "" then seen[mainFolder:lower()] = true end

    local cur   = frame:GetParent()
    local depth = 0
    while cur and cur ~= UIParent and cur ~= WorldFrame and depth < CFG.PARENT_DEPTH do
        local loc2 = SafeCall(cur.GetSourceLocation, cur)
        local src2 = loc2 and ParseLocation(loc2) or nil

        table.insert(result.parentChain, {
            name   = cur:GetName() or string.format(L.UNNAMED_PARENT, depth),
            source = src2,
        })

        if src2 and src2.type == "addon" and not seen[src2.name:lower()] then
            table.insert(result.contributors, src2.title or src2.name)
            seen[src2.name:lower()] = true
        end

        cur   = cur:GetParent()
        depth = depth + 1
    end

    frameInfoCache[frame] = result
    return result
end

--- 같은 애드온 소속의 최상위 프레임 탐색 (결과 캐시)
local function FindAddonRoot(frame, addonFolder)
    if not addonFolder then return frame end
    if frameRootCache[frame] then return frameRootCache[frame] end

    local root = frame
    local cur  = frame:GetParent()
    while cur and cur ~= UIParent and cur ~= WorldFrame do
        local loc2   = SafeCall(cur.GetSourceLocation, cur)
        local folder = loc2 and QuickGetFolder(loc2) or nil
        if folder and folder:lower() == addonFolder:lower() then
            root = cur
        else
            break
        end
        cur = cur:GetParent()
    end

    frameRootCache[frame] = root
    return root
end


-- ================================================================
-- SECTION 4: SELF-FRAME EXCLUSION
-- hlFrame / popup / minimapBtn 및 그 자식 텍스처가
-- 포커스를 먹는 경우를 부모 체인 전체에서 차단
-- ================================================================
local function RegisterOwnFrame(frame)
    WITA.ownFrames[frame] = true
end

local function IsOwnFrame(frame)
    local cur = frame
    while cur do
        if WITA.ownFrames[cur] then return true end
        cur = cur.GetParent and cur:GetParent() or nil
    end
    return false
end


-- ================================================================
-- SECTION 5: RENDERING — 하이라이트 + 팝업
-- ================================================================

-- 하이라이트 오버레이
local hlFrame = CreateFrame("Frame", "WITA_Highlight", UIParent)
hlFrame:SetFrameStrata("TOOLTIP")
hlFrame:SetFrameLevel(100)
hlFrame:EnableMouse(false)
hlFrame:Hide()
RegisterOwnFrame(hlFrame)

local hlBg = hlFrame:CreateTexture(nil, "BACKGROUND")
hlBg:SetAllPoints()
hlBg:SetColorTexture(0, 0.8, 1, 0.10)

local function MakeBorderLine(parent)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 1, 1, 1)
    return t
end
local hlTop    = MakeBorderLine(hlFrame)
local hlBottom = MakeBorderLine(hlFrame)
local hlLeft   = MakeBorderLine(hlFrame)
local hlRight  = MakeBorderLine(hlFrame)

hlTop:SetHeight(2);    hlTop:SetPoint("TOPLEFT",     hlFrame, "TOPLEFT");    hlTop:SetPoint("TOPRIGHT",    hlFrame, "TOPRIGHT")
hlBottom:SetHeight(2); hlBottom:SetPoint("BOTTOMLEFT",hlFrame,"BOTTOMLEFT"); hlBottom:SetPoint("BOTTOMRIGHT",hlFrame,"BOTTOMRIGHT")
hlLeft:SetWidth(2);    hlLeft:SetPoint("TOPLEFT",    hlFrame, "TOPLEFT");    hlLeft:SetPoint("BOTTOMLEFT", hlFrame, "BOTTOMLEFT")
hlRight:SetWidth(2);   hlRight:SetPoint("TOPRIGHT",  hlFrame, "TOPRIGHT");   hlRight:SetPoint("BOTTOMRIGHT",hlFrame,"BOTTOMRIGHT")

-- 정보 팝업
local popup = CreateFrame("Frame", "WITA_Popup", UIParent, "BackdropTemplate")
popup:SetSize(310, 80)
popup:SetFrameStrata("TOOLTIP")
popup:SetFrameLevel(200)
popup:EnableMouse(false)
popup:Hide()
RegisterOwnFrame(popup)

if popup.SetBackdrop then
    popup:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    popup:SetBackdropColor(0.04, 0.04, 0.12, 0.97)
    popup:SetBackdropBorderColor(0, 0.85, 1, 1)
end

local popupTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popupTitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -10)
popupTitle:SetText("|TInterface\\Icons\\Spell_Holy_MindVision:16:16|t |cff00ffffWTF|r |cffaaaaaaIs This?|r")

local popupDivider = popup:CreateTexture(nil, "ARTWORK")
popupDivider:SetColorTexture(0, 0.85, 1, 0.30)
popupDivider:SetHeight(1)
popupDivider:SetPoint("TOPLEFT",  popupTitle, "BOTTOMLEFT",  0, -5)
popupDivider:SetPoint("TOPRIGHT", popup,      "TOPRIGHT",  -10,  0)

local popupBody = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupBody:SetPoint("TOPLEFT",  popupDivider, "BOTTOMLEFT",  2, -8)
popupBody:SetPoint("TOPRIGHT", popup,        "TOPRIGHT",  -12,  0)
popupBody:SetJustifyH("LEFT")
popupBody:SetJustifyV("TOP")
popupBody:SetWordWrap(true)

-- ----------------------------------------------------------------
-- 간단 보기: 핵심 출처만 + 영향을 주는 애드온
-- ----------------------------------------------------------------
local function BuildSimpleContent(info)
    local lines = {}
    local src   = info.source

    if src then
        if src.type == "blizzard" then
            if src.name and src.name ~= "Blizzard UI" then
                lines[#lines+1] = ICO.BLIZZARD .. " |cff6699ff" .. L.BASIC_UI .. "|r  |cff555555(" .. src.name .. ")|r"
            else
                lines[#lines+1] = ICO.BLIZZARD .. " |cff6699ff" .. L.BASIC_UI .. "|r"
            end
            lines[#lines+1] = "  |cff666666" .. L.LBL_FRAME_SIMPLE .. "  |r|cff888888" .. info.frameName .. "|r"
        elseif src.type == "addon" then
            lines[#lines+1] = ICO.ADDON .. " |cffffff00" .. (src.title or src.name) .. "|r"
        else
            if info.nameGuess then
                lines[#lines+1] = ICO.ADDON .. " |cffddaa00" .. info.nameGuess .. "|r |cff777777" .. L.GUESSED .. "|r"
            else
                lines[#lines+1] = ICO.UNKNOWN .. " |cff888888" .. L.UNKNOWN .. "|r"
            end
        end
    else
        lines[#lines+1] = ICO.UNKNOWN .. " |cff777777" .. L.NO_SOURCE .. "|r"
        lines[#lines+1] = "  |cff555555" .. L.CVAR_HINT .. "|r"
    end

    -- 영향을 주는 애드온 (모든 케이스에서 표시)
    if #info.contributors > 0 then
        lines[#lines+1] = " "
        lines[#lines+1] = ICO.GEAR .. " |cffff9900" .. L.AFFECTING_ADDONS .. "|r"
        for _, name in ipairs(info.contributors) do
            lines[#lines+1] = "   |cffddccaa- " .. name .. "|r"
        end
    end

    lines[#lines+1] = " "
    lines[#lines+1] = "|cff444444" .. L.SHIFT_HINT .. "|r"

    return table.concat(lines, "\n")
end

-- ----------------------------------------------------------------
-- 자세히 보기: 개발자용 전체 정보
-- ----------------------------------------------------------------
local function BuildDetailContent(info)
    local lines = {}
    local src   = info.source

    -- 출처 식별
    if src then
        if src.type == "blizzard" then
            lines[#lines+1] = ICO.BLIZZARD .. " |cff6699ff" .. L.BASIC_UI .. "|r"
        elseif src.type == "addon" then
            lines[#lines+1] = ICO.ADDON .. " |cffffff00" .. (src.title or src.name) .. "|r"
            if src.title and src.title ~= src.name then
                lines[#lines+1] = "  |cff666666" .. L.LBL_FOLDER .. "  |r|cff888888" .. src.name .. "|r"
            end
        else
            if info.nameGuess then
                lines[#lines+1] = ICO.ADDON .. " |cffddaa00" .. info.nameGuess ..
                                   "|r |cff777777" .. L.NAME_GUESSED .. "|r"
            else
                lines[#lines+1] = ICO.UNKNOWN .. " |cff888888" .. L.UNKNOWN .. "|r"
            end
        end
        if src.file and src.file ~= "?" then
            lines[#lines+1] = "  |cff666666" .. L.LBL_FILE .. "  |r|cffaaaaaa" .. src.file .. "|r"
        end
        if src.line and src.line ~= "?" then
            lines[#lines+1] = "  |cff666666" .. L.LBL_LINE .. "  |r|cffaaaaaa" .. src.line .. "|r"
        end
    else
        lines[#lines+1] = ICO.UNKNOWN .. " |cff777777" .. L.NO_SOURCE .. "|r"
        lines[#lines+1] = "  |cff555555" .. L.CVAR_HINT .. "|r"
    end

    -- 프레임 정보
    lines[#lines+1] = " "
    lines[#lines+1] = "|cff666666" .. L.LBL_FRAME .. "  |r|cffcccccc" .. info.frameName .. "|r"

    -- debugName (프레임명과 다를 때만)
    if info.debugName and info.debugName ~= L.NO_DEBUG_NAME and info.debugName ~= info.frameName then
        lines[#lines+1] = "|cff666666" .. L.LBL_DEBUG .. "  |r|cff999999" .. info.debugName .. "|r"
    end

    -- 크기 + 레이어 정보
    if info.width > 0 or info.height > 0 then
        lines[#lines+1] = "|cff666666" .. L.LBL_SIZE .. "    |r|cff888888" ..
                          info.width .. " x " .. info.height ..
                          "  |r|cff666666" .. L.LBL_LAYER .. "  |r|cff888888" ..
                          (info.strata or "?") .. " / " .. (info.level or "?") .. "|r"
    end

    -- raw location (unknown일 때만 원문 노출)
    if src and src.type == "unknown" and info.rawLoc then
        lines[#lines+1] = "|cff555555" .. info.rawLoc .. "|r"
    end

    -- 관여 중인 다른 애드온
    if #info.contributors > 0 then
        lines[#lines+1] = " "
        lines[#lines+1] = ICO.GEAR .. " |cffff9900" .. L.INVOLVED_ADDONS .. "|r"
        for _, name in ipairs(info.contributors) do
            lines[#lines+1] = "   |cffddccaa- " .. name .. "|r"
        end
    end

    -- 부모 체인
    local shown = math.min(CFG.POPUP_PARENTS, #info.parentChain)
    if shown > 0 then
        lines[#lines+1] = " "
        lines[#lines+1] = "|cff666666" .. L.PARENT_CHAIN .. "|r"
        for i = 1, shown do
            local p     = info.parentChain[i]
            local pSrc  = p.source
            local pname = pSrc and (pSrc.title or pSrc.name) or "?"
            local pad   = string.rep("  ", i)
            lines[#lines+1] = pad .. "|cff555555- |r|cff999999" ..
                               p.name .. " |cff555555(" .. pname .. ")|r"
        end
        if #info.parentChain > CFG.POPUP_PARENTS then
            lines[#lines+1] = "     |cff444444" ..
                               string.format(L.MORE_PARENTS, #info.parentChain - CFG.POPUP_PARENTS) .. "|r"
        end
    end

    return table.concat(lines, "\n")
end

local function RefreshPopup(info)
    local titleBase = "|TInterface\\Icons\\Spell_Holy_MindVision:16:16|t |cff00ffffWTF|r |cffaaaaaaIs This?|r"
    if WITA.detailMode then
        popupTitle:SetText(titleBase .. "  |cffff9900" .. L.DETAIL_BADGE .. "|r")
        popupBody:SetText(BuildDetailContent(info))
    else
        popupTitle:SetText(titleBase)
        popupBody:SetText(BuildSimpleContent(info))
    end
    local h = 14 + popupTitle:GetStringHeight() + 5 + 1 + 8
            + popupBody:GetStringHeight() + 18
    popup:SetHeight(math.max(80, h))
end

local function PositionPopup()
    local cx, cy = GetCursorPosition()
    local s      = UIParent:GetEffectiveScale()
    cx, cy = cx / s, cy / s

    local pw, ph = popup:GetWidth(), popup:GetHeight()
    local sw, sh = GetScreenWidth(), GetScreenHeight()

    local px = cx + 22
    local py = cy + 14
    if px + pw > sw then px = cx - pw - 10 end
    if py + ph > sh then py = cy - ph - 10 end
    if py < 4       then py = 4            end

    popup:ClearAllPoints()
    popup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", px, py)
end


-- ================================================================
-- SECTION 6: SCAN LOOP (throttled)
-- 팝업 위치: 매 프레임 갱신 (커서 추적, 매우 가벼움)
-- 프레임 감지 + 분석: CFG.SCAN_THROTTLE 간격으로만 실행
-- ================================================================
local scanFrame = CreateFrame("Frame")
local prevFocus = nil
local timeSince = 0
scanFrame:Hide()

scanFrame:SetScript("OnUpdate", function(self, elapsed)
    -- 팝업 위치는 매 프레임 갱신
    if popup:IsShown() then PositionPopup() end

    -- 프레임 감지는 throttle
    timeSince = timeSince + elapsed
    if timeSince < CFG.SCAN_THROTTLE then return end
    timeSince = 0

    local foci  = GetMouseFoci()
    local focus = foci and foci[1]

    -- 자기 프레임 / 월드 / 루트 → 부모 체인까지 확인해서 제외
    if not focus
    or focus == WorldFrame
    or focus == UIParent
    or IsOwnFrame(focus) then
        if prevFocus ~= nil then
            hlFrame:Hide()
            popup:Hide()
            prevFocus = nil
        end
        return
    end

    -- 같은 프레임이면 분석 스킵 (캐시 + 위치는 위에서 이미 갱신됨)
    if focus == prevFocus then return end
    prevFocus = focus

    local info        = AnalyzeFrame(focus)
    local addonFolder = (info.source and info.source.type == "addon") and info.source.name or nil
    local rootFrame   = addonFolder and FindAddonRoot(focus, addonFolder) or focus

    hlFrame:ClearAllPoints()
    hlFrame:SetAllPoints(rootFrame)
    hlFrame:Show()

    RefreshPopup(info)
    popup:Show()
end)


-- ================================================================
-- SECTION 7: TOGGLE + COMMANDS
-- ================================================================
-- detail: true → 자세히 보기, false → 간단히 보기
local function StartWITA(detail)
    if GetCVar and GetCVar("enableSourceLocationLookup") ~= "1" then
        SetCVar("enableSourceLocationLookup", "1")
        print("|cff00ffff[WITA]|r |cffffff00" .. L.MSG_CVAR_ON .. "|r")
        print("|cff00ffff[WITA]|r |cffff8800" .. L.MSG_CVAR_RELOAD .. "|r")
        return
    end
    WITA.active     = true
    WITA.detailMode = detail or false
    scanFrame:Show()
    local msg = detail and L.MSG_START_DETAIL or L.MSG_START_SIMPLE
    print("|cff00ffff[WITA]|r " .. msg)
end

local function StopWITA()
    WITA.active     = false
    WITA.detailMode = false
    scanFrame:Hide()
    hlFrame:Hide()
    popup:Hide()
    prevFocus = nil
    print("|cff00ffff[WITA]|r " .. L.MSG_STOP)
end

-- /wtf        → 간단히 시작 / 종료
-- /wtf detail → 자세히 시작 (검사 중엔 무반응)
-- /what       → /wtf 와 동일
SLASH_WTF1 = "/wtf"
SLASH_WTF2 = "/what"
SlashCmdList["WTF"] = function(msg)
    local arg = msg and msg:lower():match("^%s*(%S*)") or ""
    local isDetail = (arg == "detail" or arg == "d")
    if WITA.active then
        if isDetail then return end   -- 검사 중 /wtf detail → 무반응
        StopWITA()
    else
        StartWITA(isDetail)
    end
end


-- ================================================================
-- SECTION 8: MINIMAP BUTTON (LibDataBroker + LibDBIcon)
-- LibDBIcon이 버튼 생성/위치/드래그/저장을 모두 처리
-- 미니맵 버튼 관리 애드온(Minimap Button Bag 등)에 자동 등록됨
-- ================================================================
local function SetupMinimapButton()
    local LDB    = LibStub("LibDataBroker-1.1")
    local DBIcon = LibStub("LibDBIcon-1.0")

    local launcher = LDB:NewDataObject("WTFisThisAddon", {
        type = "launcher",
        text = "WTF is This?",
        icon = ICO.EYE,

        OnClick = function(self, btn)
            if btn ~= "LeftButton" then return end
            if WITA.active then
                -- 검사 중: 클릭/Shift+클릭 모두 종료
                StopWITA()
            else
                -- 검사 중 아닐 때: Shift → 자세히, 일반 → 간단히
                StartWITA(IsShiftKeyDown())
            end
        end,

        OnTooltipShow = function(tip)
            tip:AddLine("|cff00ffffWTF|r is This?", 1, 1, 1)
            tip:AddLine(" ")
            if WITA.active then
                tip:AddLine("|cff00ff00" .. L.TIP_SCANNING .. "|r")
                tip:AddLine("|cff888888" .. L.TIP_CLICK_STOP .. "|r")
            else
                tip:AddLine("|cffaaaaaa" .. L.TIP_IDLE .. "|r")
                tip:AddLine("|cff888888" .. L.TIP_CLICK_SIMPLE .. "|r")
                tip:AddLine("|cff888888" .. L.TIP_SHIFT_DETAIL .. "|r")
            end
        end,
    })

    -- WITAdb.minimapIcon 서브테이블을 LibDBIcon에 전달
    -- LibDBIcon이 위치(각도), 숨김 상태 등을 여기에 저장/불러옴
    DBIcon:Register("WTFisThisAddon", launcher, WITA.db.minimapIcon)

    -- LibDBIcon이 만든 버튼을 자기 프레임으로 등록 (자가 탐지 방지)
    local btn = DBIcon:GetMinimapButton("WTFisThisAddon")
    if btn then RegisterOwnFrame(btn) end
end


-- ================================================================
-- SECTION 9: INIT
-- ================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    WITAdb = WITAdb or {}
    WITAdb.minimapIcon = WITAdb.minimapIcon or {}   -- LibDBIcon 위치/숨김 저장

    WITA.db         = WITAdb
    WITA.detailMode = false   -- 세션 시작 시 항상 간단히 보기로 초기화

    BuildAddonCache()
    SetupMinimapButton()

    print("|cff00ffff[WTFisThisAddon]|r v" .. VERSION ..
          " " .. L.MSG_LOADED .. "  |cff888888/wtf|r")
end)
