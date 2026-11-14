local A = TEST_ADDON
local checks = 0
local function check(condition, name) assert(condition, name) checks = checks + 1 end
local box = ChatFrame1.editBox
A.db.enabled, A.db.skipUnavailable = true, true
A.db.windows[1].enabled, A.db.windows[3].enabled = true, true
A.db.windows[3].route = "PARTY"
state.group = true
SELECTED_CHAT_FRAME = ChatFrame1
ChatFrameUtil.ActivateChat(box)
box:SetText("测试直接按键")
-- Replicates a build that never calls ChatEdit_CustomTabPressed.
ChatEdit_CustomTabPressed = nil
local nativeBefore = nativeTabs
box:GetScript("OnTabPressed")(box)
check(SELECTED_CHAT_FRAME == ChatFrame3, "widget Tab switches without global extension")
check(nativeTabs == nativeBefore, "handled Tab is not processed twice")
check(box:GetText() == "测试直接按键", "direct dispatch preserves Chinese draft")
state.shift = true
box:GetScript("OnTabPressed")(box)
check(SELECTED_CHAT_FRAME == ChatFrame1, "direct Shift Tab reverses")
state.shift = false
box.ime = 0
box:GetScript("OnTabPressed")(box)
check(SELECTED_CHAT_FRAME == ChatFrame3, "numeric zero IME flag does not block Tab")
box.ime = true
box:GetScript("OnTabPressed")(box)
check(nativeTabs == nativeBefore + 1, "IME delegates original handler")
box.ime = false
box:SetText("/w Al")
box:GetScript("OnTabPressed")(box)
check(nativeTabs == nativeBefore + 2, "slash completion delegates original handler")
box:SetText("hello")
AutoCompleteBox = CreateFrame("Frame", nil, box)
AutoCompleteBox:Show()
box:GetScript("OnTabPressed")(box)
check(nativeTabs == nativeBefore + 3, "visible completion list delegates original handler")
AutoCompleteBox:Hide()
A.db.enabled = false
box:GetScript("OnTabPressed")(box)
check(nativeTabs == nativeBefore + 4, "disabled addon restores native handler")
A.db.enabled = true
local existing = box:GetScript("OnTabPressed")
A.RefreshWindows()
check(box:GetScript("OnTabPressed") == existing, "refresh never stacks input wrappers")
ACTIVE_CHAT_EDIT_BOX = nil
check(A.ActiveBox() == box, "focused box fallback when active API returns nil")
ChatFrameUtil.ActivateChat(box)
local b = A.minimapButton
check(b.border.texture == 136430, "native tracking ring texture")
check(b.icon.mask == b.mask, "icon has circular alpha mask")
check(b.icon.width == 20 and b.icon.height == 20, "small icon inside ring")
A.ToggleOptions()
check(TabTalkOptions.solidBackground.color[4] >= 0.95, "panel has opaque solid background")
check(TabTalkOptions.destination:GetFontString().maxLines == 1, "selector text has bounded lines")
check(TabTalkOptions.destination:GetFontString().width == 404, "selector has text insets")
check(TabTalkOptions.destination:GetFontString().fontSize <= 14, "button avoids overridden global font sizes")
local grow, fontGrow, reset
for _, obj in ipairs(objects) do
    if obj:GetText() == "放大" then grow = obj end
    if obj:GetText() == "A+" then fontGrow = obj end
    if obj:GetText() == "恢复大小" then reset = obj end
end
check(grow and fontGrow and reset, "independent panel and font controls exist")
fontGrow:GetScript("OnClick")(fontGrow)
check(A.db.fontScale > 1, "font size changes and persists")
check(TabTalkOptions.destination:GetFontString().fontSize > 12, "font control affects button captions")
grow:GetScript("OnClick")(grow)
check(A.db.uiScale > 1, "panel size saved independently")
reset:GetScript("OnClick")(reset)
check(A.db.fontScale == 1 and A.db.uiScale == 1, "reset affects presentation only")
check(A.db.windows[3].route == "PARTY", "presentation controls preserve routes")
UIParent:SetSize(640, 480)
TabTalkOptions:GetScript("OnEvent")(TabTalkOptions, "UI_SCALE_CHANGED")
check(TabTalkOptions.scale * 760 < 640 and TabTalkOptions.scale * 550 < 480, "panel fits smaller UI coordinate space")
TEST_CHECKS = TEST_CHECKS + checks
