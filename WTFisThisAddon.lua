-- WTFisThisAddon.lua
-- UI 프레임을 마우스로 가리키면 어떤 애드온이 만든 건지 알려주는 검사 도구
-- /wita 또는 /wtfisthis 로 검사 모드 토글

local ADDON_NAME = "WTFisThisAddon"
local VERSION    = "1.0.0"

-- ================================================================
-- STATE
-- ================================================================
local WITA = {
    active   = false,
    db       = nil,   -- SavedVariables (WITAdb)
}


-- ================================================================
-- UTIL: 소스 경로 파싱
-- ================================================================

--- GetSourceLocation() 결과 문자열을 파싱해서 구조체로 반환
--- @param location string  예) "Interface\\AddOns\\WeakAuras\\WeakAuras.lua:2847"
--- @return table|nil  { type, name, file, line, raw }
local function ParseLocation(location)
    if not location or location == "" or location == "UnknownFile" then
        return nil
    end

    -- AddOns 경로  →  Interface\AddOns\<Name>\...\<file>.lua:<line>
    local addonName, file, line =
        location:match("Interface\\AddOns\\([^\\]+)\\(.+):(%d+)")
    if addonName then
        return { type = "addon", name = addonName,
                 file = file,   line = line, raw = location }
    end

    -- Blizzard 기본 UI (FrameXML, BlizzardInterfaceCode 등)
    if location:find("FrameXML")
    or location:find("BlizzardInterfaceCode")
    or location:find("Interface\\BuiltIn") then
        local bfile = location:match("([^\\]+%.lua):%d+") or "?"
        local bline = location:match(":(%d+)$")           or "?"
        return { type = "blizzard", name = "Blizzard UI",
                 file = bfile, line = bline, raw = location }
    end

    -- 그 외 (string.dump, loadstring 등)
    return { type = "unknown", name = "Unknown",
             file = location, line = "?", raw = location }
end

--- 프레임 이름으로 애드온명 추정 (보조 수단)
--- 예) "WeakAuras_SomeFrame" → "WeakAuras"
local function GuessAddonFromName(frameName)
    if not frameName then return nil end
    return frameName:match("^([A-Za-z][A-Za-z0-9]+)[_%-]") or nil
end


-- ================================================================
-- UTIL: 프레임 분석
-- ================================================================

--- 프레임을 분석해서 정보 테이블 반환
--- @param frame Frame
--- @return table
local function AnalyzeFrame(frame)
    local result = {
        frameName    = frame:GetName() or "(이름 없음)",
        debugName    = (frame.GetDebugName and frame:GetDebugName()) or "(없음)",
        source       = nil,   -- ParseLocation 결과
        nameGuess    = nil,   -- 이름 기반 추정 애드온명
        parentChain  = {},    -- [{ name, source }]  최대 6단계
        contributors = {},    -- 부모 체인에서 발견된 다른 애드온들
    }

    -- GetSourceLocation 파싱
    local ok, loc = pcall(function() return frame:GetSourceLocation() end)
    if ok and loc then
        result.source = ParseLocation(loc)
    end

    -- 소스를 못 읽었을 때 이름으로 보조 추정
    if not result.source or result.source.type == "unknown" then
        result.nameGuess = GuessAddonFromName(frame:GetName())
    end

    -- 부모 체인 탐색 (최대 6단계)
    local seen = {}
    local mainName = result.source and result.source.name or ""
    if mainName ~= "" then seen[mainName] = true end

    local cur   = frame:GetParent()
    local depth = 0
    while cur and cur ~= UIParent and cur ~= WorldFrame and depth < 6 do
        local ok2, loc2 = pcall(function() return cur:GetSourceLocation() end)
        local src2      = (ok2 and loc2) and ParseLocation(loc2) or nil

        table.insert(result.parentChain, {
            name   = cur:GetName() or ("(이름없음 #" .. depth .. ")"),
            source = src2,
        })

        -- 주 출처와 다른 애드온이면 contributor로 기록
        if src2 and src2.type == "addon" and not seen[src2.name] then
            table.insert(result.contributors, src2.name)
            seen[src2.name] = true
        end

        cur   = cur:GetParent()
        depth = depth + 1
    end

    return result
end


-- ================================================================
-- UI: 하이라이트 오버레이 (반투명 + 테두리)
-- ================================================================

local hlFrame = CreateFrame("Frame", "WITA_Highlight", UIParent)
hlFrame:SetFrameStrata("TOOLTIP")
hlFrame:SetFrameLevel(100)
hlFrame:EnableMouse(false)   -- 마우스 이벤트를 아래 프레임에 투과
hlFrame:Hide()

-- 반투명 파란 배경
local hlBg = hlFrame:CreateTexture(nil, "BACKGROUND")
hlBg:SetAllPoints()
hlBg:SetColorTexture(0, 0.8, 1, 0.10)

-- 테두리 4선 (시안 컬러)
local function MakeBorderLine(parent, col)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 1, 1, col or 1)
    return t
end

local hlTop    = MakeBorderLine(hlFrame)
local hlBottom = MakeBorderLine(hlFrame)
local hlLeft   = MakeBorderLine(hlFrame)
local hlRight  = MakeBorderLine(hlFrame)

hlTop:SetHeight(2)
hlTop:SetPoint("TOPLEFT",    hlFrame, "TOPLEFT",    0,  0)
hlTop:SetPoint("TOPRIGHT",   hlFrame, "TOPRIGHT",   0,  0)

hlBottom:SetHeight(2)
hlBottom:SetPoint("BOTTOMLEFT",  hlFrame, "BOTTOMLEFT",  0, 0)
hlBottom:SetPoint("BOTTOMRIGHT", hlFrame, "BOTTOMRIGHT", 0, 0)

hlLeft:SetWidth(2)
hlLeft:SetPoint("TOPLEFT",    hlFrame, "TOPLEFT",    0,  0)
hlLeft:SetPoint("BOTTOMLEFT", hlFrame, "BOTTOMLEFT", 0,  0)

hlRight:SetWidth(2)
hlRight:SetPoint("TOPRIGHT",    hlFrame, "TOPRIGHT",    0, 0)
hlRight:SetPoint("BOTTOMRIGHT", hlFrame, "BOTTOMRIGHT", 0, 0)


-- ================================================================
-- UI: 정보 팝업
-- ================================================================

local popup = CreateFrame("Frame", "WITA_Popup", UIParent, "BackdropTemplate")
popup:SetSize(310, 80)
popup:SetFrameStrata("TOOLTIP")
popup:SetFrameLevel(200)
popup:EnableMouse(false)
popup:Hide()

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

-- 헤더 텍스트
local popupTitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popupTitle:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -10)
popupTitle:SetText("|cff00ffff⬡ WTF|r |cffaaaaaaIs This?|r")

-- 구분선
local popupDivider = popup:CreateTexture(nil, "ARTWORK")
popupDivider:SetColorTexture(0, 0.85, 1, 0.30)
popupDivider:SetHeight(1)
popupDivider:SetPoint("TOPLEFT",  popupTitle, "BOTTOMLEFT",  0, -5)
popupDivider:SetPoint("TOPRIGHT", popup,      "TOPRIGHT",   -10, 0)

-- 본문
local popupBody = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popupBody:SetPoint("TOPLEFT",  popupDivider, "BOTTOMLEFT",  2, -8)
popupBody:SetPoint("TOPRIGHT", popup,        "TOPRIGHT",  -12,  0)
popupBody:SetJustifyH("LEFT")
popupBody:SetJustifyV("TOP")
popupBody:SetWordWrap(true)

--- 팝업 본문 텍스트 생성
local function BuildContent(info)
    local lines = {}
    local src   = info.source

    -- ── 주 출처 ──
    if src then
        if src.type == "blizzard" then
            lines[#lines+1] = "|cff6699ff🔷  Blizzard 기본 UI|r"
        elseif src.type == "addon" then
            lines[#lines+1] = "|cffffff00📦  " .. src.name .. "|r"
        else
            -- Unknown 이지만 이름 추정이 있을 때
            if info.nameGuess then
                lines[#lines+1] = "|cffddaa00📦  " .. info.nameGuess ..
                                   "|r |cff777777(이름으로 추정)|r"
            else
                lines[#lines+1] = "|cff888888❓  알 수 없음|r"
            end
        end

        if src.file and src.file ~= "?" then
            lines[#lines+1] = "  |cff666666파일|r  |cffaaaaaa" .. src.file .. "|r"
        end
        if src.line and src.line ~= "?" then
            lines[#lines+1] = "  |cff666666라인|r  |cffaaaaaa" .. src.line .. "|r"
        end
    else
        lines[#lines+1] = "|cff777777❓  소스 정보 없음|r"
        lines[#lines+1] = "  |cff555555(enableSourceLocationLookup 필요)|r"
    end

    -- ── 프레임명 ──
    lines[#lines+1] = " "
    lines[#lines+1] = "|cff666666프레임  |r|cffcccccc" .. info.frameName .. "|r"

    -- ── 관여 중인 다른 애드온들 ──
    if #info.contributors > 0 then
        lines[#lines+1] = " "
        lines[#lines+1] = "|cffff9900⚙  함께 관여 중인 애드온|r"
        for _, name in ipairs(info.contributors) do
            lines[#lines+1] = "   |cffddccaa•  " .. name .. "|r"
        end
    end

    -- ── 부모 체인 (최대 3단계) ──
    local shown = math.min(3, #info.parentChain)
    if shown > 0 then
        lines[#lines+1] = " "
        lines[#lines+1] = "|cff666666부모 체인|r"
        for i = 1, shown do
            local p     = info.parentChain[i]
            local pname = (p.source and p.source.name) or "?"
            local pad   = string.rep("  ", i)
            lines[#lines+1] = pad .. "|cff555555└ |r|cff999999" ..
                               p.name .. " |cff555555(" .. pname .. ")|r"
        end
        if #info.parentChain > 3 then
            lines[#lines+1] = "     |cff444444... 외 " ..
                               (#info.parentChain - 3) .. "단계|r"
        end
    end

    return table.concat(lines, "\n")
end

--- 팝업 갱신 (내용 + 높이 자동 조정)
local function RefreshPopup(info)
    popupBody:SetText(BuildContent(info))
    local h = 14                               -- 상단 패딩
            + popupTitle:GetStringHeight()
            + 5 + 1 + 8                        -- 구분선
            + popupBody:GetStringHeight()
            + 18                               -- 하단 패딩
    popup:SetHeight(math.max(80, h))
end

--- 팝업을 커서 근처에 배치 (화면 밖으로 나가지 않게)
local function PositionPopup()
    local cx, cy = GetCursorPosition()
    local s      = UIParent:GetEffectiveScale()
    cx, cy = cx / s, cy / s

    local pw = popup:GetWidth()
    local ph = popup:GetHeight()
    local sw = GetScreenWidth()
    local sh = GetScreenHeight()

    local px = cx + 22
    local py = cy + 14

    if px + pw > sw  then px = cx - pw - 10 end
    if py + ph > sh  then py = cy - ph - 10 end
    if py < 4        then py = 4             end

    popup:ClearAllPoints()
    popup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", px, py)
end


-- ================================================================
-- CORE: 검사 루프 (OnUpdate)
-- ================================================================

local scanFrame  = CreateFrame("Frame")
local prevFocus  = nil
scanFrame:Hide()

scanFrame:SetScript("OnUpdate", function()
    -- GetMouseFocus() 는 12.0에서 제거됨
    -- GetMouseFoci() 로 대체 → 마우스 아래 프레임 목록(위→아래 순) 반환
    local foci  = GetMouseFoci()
    local focus = foci and foci[1]   -- 첫 번째 = 가장 위에 있는 프레임

    -- 스킵 조건 (자기 프레임, 월드, UIParent)
    if not focus
    or focus == WorldFrame
    or focus == UIParent
    or focus == hlFrame
    or focus == popup then
        if prevFocus ~= nil then
            hlFrame:Hide()
            popup:Hide()
            prevFocus = nil
        end
        return
    end

    -- 같은 프레임이면 팝업 위치만 갱신
    if focus == prevFocus then
        if popup:IsShown() then PositionPopup() end
        return
    end
    prevFocus = focus

    -- 하이라이트
    hlFrame:ClearAllPoints()
    hlFrame:SetAllPoints(focus)
    hlFrame:Show()

    -- 분석 & 팝업
    local info = AnalyzeFrame(focus)
    RefreshPopup(info)
    PositionPopup()
    popup:Show()
end)


-- ================================================================
-- 토글 함수
-- ================================================================

local function EnableWITA()
    -- enableSourceLocationLookup CVar 확인
    if GetCVar and GetCVar("enableSourceLocationLookup") ~= "1" then
        SetCVar("enableSourceLocationLookup", "1")
        print("|cff00ffff[WITA]|r |cffffff00SourceLocation 기능을 켰습니다.|r")
        print("|cff00ffff[WITA]|r |cffff8800/reload 후 재시도해주세요.|r")
        return
    end

    WITA.active = true
    scanFrame:Show()
    print("|cff00ffff[WITA]|r 검사 모드 |cff00ff00ON|r" ..
          "  |cff888888— 아무 UI에나 마우스를 올려보세요  (/wita 로 끄기)|r")
end

local function DisableWITA()
    WITA.active = false
    scanFrame:Hide()
    hlFrame:Hide()
    popup:Hide()
    prevFocus = nil
    print("|cff00ffff[WITA]|r 검사 모드 |cffff4444OFF|r")
end

local function ToggleWITA()
    if WITA.active then DisableWITA() else EnableWITA() end
end


-- ================================================================
-- 슬래시 커맨드
-- ================================================================

SLASH_WITA1 = "/wita"
SLASH_WITA2 = "/wtfisthis"
SlashCmdList["WITA"] = function() ToggleWITA() end


-- ================================================================
-- 미니맵 버튼
-- ================================================================

local minimapBtn

local function UpdateMinimapPos(angle)
    local rad = math.rad(angle)
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER",
                        math.cos(rad) * 80,
                        math.sin(rad) * 80)
end

local function CreateMinimapButton()
    minimapBtn = CreateFrame("Button", "WITA_MinimapBtn", Minimap)
    minimapBtn:SetSize(32, 32)
    minimapBtn:SetFrameStrata("MEDIUM")
    minimapBtn:SetFrameLevel(8)
    minimapBtn:RegisterForDrag("LeftButton")
    minimapBtn:RegisterForClicks("AnyUp")

    -- 아이콘 배경 (미니맵 스타일 테두리)
    local border = minimapBtn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- 아이콘 본체 (물음표)
    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    -- 호버 하이라이트
    minimapBtn:SetHighlightTexture(
        "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- ── 드래그로 위치 조정 ──
    local isDragging = false

    minimapBtn:SetScript("OnDragStart", function(self)
        isDragging = true
        self:LockHighlight()
    end)

    minimapBtn:SetScript("OnDragStop", function(self)
        isDragging = false
        self:UnlockHighlight()
    end)

    minimapBtn:SetScript("OnUpdate", function()
        if not isDragging then return end
        local mx, my = Minimap:GetCenter()
        local s      = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy       = cx / s, cy / s
        local angle  = math.deg(math.atan2(cy - my, cx - mx))
        WITA.db.minimapPos = angle
        UpdateMinimapPos(angle)
    end)

    -- ── 클릭 ──
    minimapBtn:SetScript("OnClick", function(self, btn)
        if isDragging then return end
        if btn == "LeftButton" then ToggleWITA() end
    end)

    -- ── 툴팁 ──
    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("WTF is this Addon?", 0, 1, 1)
        GameTooltip:AddLine(" ")
        if WITA.active then
            GameTooltip:AddLine("|cff00ff00● 검사 모드 ON|r")
        else
            GameTooltip:AddLine("|cffaaaaaa○ 검사 모드 OFF|r")
        end
        GameTooltip:AddLine("|cff888888좌클릭: 토글   드래그: 이동|r")
        GameTooltip:Show()
    end)

    minimapBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateMinimapPos(WITA.db and WITA.db.minimapPos or 195)
end


-- ================================================================
-- ADDON_LOADED 초기화
-- ================================================================

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- SavedVariables 초기화
    WITAdb   = WITAdb or { minimapPos = 195 }
    WITA.db  = WITAdb

    CreateMinimapButton()

    print("|cff00ffff[WTFisThisAddon]|r v" .. VERSION ..
          " 로드됨  |cff888888/wita  또는  /wtfisthis|r")
end)
