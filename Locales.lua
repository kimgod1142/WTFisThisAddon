-- Locales.lua
-- WTFisThisAddon 로케일 문자열 정의
-- 영어(enUS)를 기본값으로, koKR만 별도 override

local L = {
    -- ── 프레임 기본값 ───────────────────────────────────────
    UNNAMED_FRAME    = "(unnamed)",
    NO_DEBUG_NAME    = "(none)",
    UNNAMED_PARENT   = "(unnamed #%d)",

    -- ── 간단 보기 ────────────────────────────────────────────
    BASIC_UI         = "Default UI",
    GUESSED          = "(guessed)",
    UNKNOWN          = "Unknown",
    NO_SOURCE        = "No source info",
    CVAR_HINT        = "(enableSourceLocationLookup required)",
    AFFECTING_ADDONS = "Affecting addons",
    LBL_FRAME_SIMPLE = "Frame",
    SHIFT_HINT       = "/wtf detail or Shift+Click to restart in detail view",

    -- ── 자세히 보기 ──────────────────────────────────────────
    NAME_GUESSED     = "(name guessed)",
    LBL_FOLDER       = "Folder",
    LBL_FILE         = "File",
    LBL_LINE         = "Line",
    LBL_FRAME        = "Frame",
    LBL_DEBUG        = "Debug",
    LBL_SIZE         = "Size",
    LBL_LAYER        = "Layer",
    INVOLVED_ADDONS  = "Involved addons",
    PARENT_CHAIN     = "Parent chain",
    MORE_PARENTS     = "... and %d more",

    -- ── 팝업 타이틀 배지 ─────────────────────────────────────
    DETAIL_BADGE     = "[Detail]",

    -- ── 미니맵 버튼 툴팁 ─────────────────────────────────────
    TIP_SCANNING     = "Scanning",
    TIP_IDLE         = "Idle",
    TIP_CLICK_STOP   = "Click: Stop scan",
    TIP_CLICK_SIMPLE = "Click: Start simple scan",
    TIP_SHIFT_DETAIL = "Shift+Click: Start detail scan",

    -- ── 채팅 메시지 ──────────────────────────────────────────
    MSG_CVAR_ON      = "SourceLocation enabled.",
    MSG_CVAR_RELOAD  = "Please /reload and try again.",
    MSG_START_SIMPLE = "Simple scan started  (/wtf to stop)",
    MSG_START_DETAIL = "Detail scan started  (/wtf to stop)",
    MSG_STOP         = "Scan stopped",
    MSG_LOADED       = "loaded",
}

if GetLocale() == "koKR" then
    -- ── 프레임 기본값 ─────────────────────────────────────
    L.UNNAMED_FRAME    = "(이름 없음)"
    L.NO_DEBUG_NAME    = "(없음)"
    L.UNNAMED_PARENT   = "(이름없음 #%d)"

    -- ── 간단 보기 ──────────────────────────────────────────
    L.BASIC_UI         = "기본 UI"
    L.GUESSED          = "(추정)"
    L.UNKNOWN          = "알 수 없음"
    L.NO_SOURCE        = "소스 정보 없음"
    L.CVAR_HINT        = "(enableSourceLocationLookup 필요)"
    L.AFFECTING_ADDONS = "영향을 주는 애드온"
    L.LBL_FRAME_SIMPLE = "프레임"
    L.SHIFT_HINT       = "/wtf detail 또는 Shift+클릭으로 자세히 보기"

    -- ── 자세히 보기 ────────────────────────────────────────
    L.NAME_GUESSED     = "(이름 추정)"
    L.LBL_FOLDER       = "폴더"
    L.LBL_FILE         = "파일"
    L.LBL_LINE         = "라인"
    L.LBL_FRAME        = "프레임"
    L.LBL_DEBUG        = "디버그"
    L.LBL_SIZE         = "크기"
    L.LBL_LAYER        = "레이어"
    L.INVOLVED_ADDONS  = "함께 관여 중인 애드온"
    L.PARENT_CHAIN     = "부모 체인"
    L.MORE_PARENTS     = "... 외 %d단계"

    -- ── 팝업 타이틀 배지 ───────────────────────────────────
    L.DETAIL_BADGE     = "[상세]"

    -- ── 미니맵 버튼 툴팁 ───────────────────────────────────
    L.TIP_SCANNING     = "검사 중"
    L.TIP_IDLE         = "검사 대기 중"
    L.TIP_CLICK_STOP   = "클릭: 검사 종료"
    L.TIP_CLICK_SIMPLE = "클릭: 간단히 보기로 시작"
    L.TIP_SHIFT_DETAIL = "Shift+클릭: 자세히 보기로 시작"

    -- ── 채팅 메시지 ────────────────────────────────────────
    L.MSG_CVAR_ON      = "SourceLocation 기능을 켰습니다."
    L.MSG_CVAR_RELOAD  = "/reload 후 재시도해주세요."
    L.MSG_START_SIMPLE = "간단히 검사 시작  (/wtf 로 종료)"
    L.MSG_START_DETAIL = "자세히 검사 시작  (/wtf 로 종료)"
    L.MSG_STOP         = "검사 종료"
    L.MSG_LOADED       = "로드됨"
end

WTFisThisAddon_L = L
