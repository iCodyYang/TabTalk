local _, A = ...
local panel, popup, rows = nil, nil, {}
local selected
local fontWidgets = {}
local localizedWidgets = {}
local function rememberText(region, value)
    local key = A.LocaleKey(value)
    if key then localizedWidgets[#localizedWidgets + 1] = {region, key} end
end
local function font(region, size)
    fontWidgets[#fontWidgets + 1] = {region, size}
    region:SetFont(A.FontPath(), size * (A.db.fontScale or 1), "")
end
local function fitPanel()
    if not panel then return end
    local scale = math.max(0.7, math.min(1.3, A.db.uiScale or 1))
    panel:SetScale(math.min(scale, UIParent:GetWidth() / 790, UIParent:GetHeight() / 580))
end
local function resizeFonts(delta)
    A.db.fontScale = math.max(0.85, math.min(1.15, (A.db.fontScale or 1) + delta))
    for _, entry in ipairs(fontWidgets) do
        entry[1]:SetFont(A.FontPath(), entry[2] * A.db.fontScale, "")
    end
    panel.fontValue:SetText(math.floor(A.db.fontScale * 100 + 0.5) .. "%")
end
local function text(parent, value, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(value)
    rememberText(label, value)
    label:SetJustifyH("LEFT")
    label:SetWidth(math.max(60, parent:GetWidth() - x - 16))
    label:SetWordWrap(true)
    local size = font == "GameFontNormalLarge" and 19 or font == "GameFontDisableSmall" and 11 or 13
    fontWidgets[#fontWidgets + 1] = {label, size}
    label:SetFont(A.FontPath(), size * (A.db.fontScale or 1), "")
    return label
end
local function button(parent, label, width, x, y, action)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 26)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    rememberText(b, label)
    local caption = b:GetFontString()
    font(caption, 12)
    caption:ClearAllPoints()
    caption:SetPoint("LEFT", b, "LEFT", 8, 0)
    caption:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    caption:SetWidth(width - 16)
    caption:SetWordWrap(false)
    caption:SetMaxLines(1)
    b:SetScript("OnClick", action)
    return b
end
local function check(parent, label, x, y, action)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(26, 26)
    b:SetPoint("TOPLEFT", x, y)
    local caption = text(b, label, 28, -6)
    caption:SetWidth(350)
    caption:SetMaxLines(2)
    b:SetScript("OnClick", function(self) action(self:GetChecked() and true or false) end)
    b.caption = caption
    return b
end
local function skin(frame)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetColorTexture(0.035, 0.045, 0.06, 0.97)
    frame.solidBackground = background
    frame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true,
        tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
    frame:SetBackdropColor(0.04, 0.06, 0.09, 0.98)
end

-- A small reusable picker; only its visible eight rows exist, even with many channels.
local function choose(anchor, choices, pick)
    if not popup then
        popup = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        skin(popup)
        popup:SetFrameStrata("TOOLTIP")
        popup:SetSize(410, 256)
        popup:EnableMouse(true)
        popup:EnableMouseWheel(true)
        popup.items = {}
        for i = 1, 8 do
            local b = button(popup, "", 386, 12, -10 - (i - 1) * 27, function(self)
                local value = popup.choices[self.index]
                popup:Hide()
                if value then popup.pick(value[1]) end
            end)
            popup.items[i] = b
        end
        popup.hint = text(popup, A.T("滚轮查看更多 · 再点选择框收起"), 14, -232, "GameFontDisableSmall")
        popup.render = function()
            for i, b in ipairs(popup.items) do
                b.index = popup.offset + i
                local item = popup.choices[b.index]
                b:SetShown(item ~= nil)
                if item then b:SetText(item[2]) end
            end
        end
        popup:SetScript("OnMouseWheel", function(_, delta)
            popup.offset = math.max(0, math.min(math.max(0, #popup.choices - 8), popup.offset - delta))
            popup.render()
        end)
    end
    if popup:IsShown() and popup.anchor == anchor then popup:Hide() return end
    popup.anchor, popup.choices, popup.pick, popup.offset = anchor, choices, pick, 0
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    popup:SetClampedToScreen(true)
    popup.render()
    popup:Show()
end

local function refresh()
    if not panel then return end
    if panel.language then
        local mode = A.db.language
        panel.language:SetText("中文 / EN: " .. (mode == "zhCN" and "中文" or mode == "enUS" and "EN" or "Auto"))
    end
    if panel.footer then panel.footer:SetText(A.T("设置自动保存到当前角色 · /tabtalk 打开设置 · ") .. A.VERSION) end
    local windows = A.RefreshWindows()
    local names = {}
    for _, window in ipairs(windows) do names[window.id] = window.name end
    if not A.db.windows[selected] then selected = A.db.order[1] end
    for i, id in ipairs(A.db.order) do
        local row = rows[i]
        if not row then
            row = button(panel.listChild, "", 204, 0, -(i - 1) * 44, function(self)
                selected = self.windowID
                if popup then popup:Hide() end
                refresh()
            end)
            row:SetHeight(40)
            row:GetFontString():SetMaxLines(2)
            rows[i] = row
        end
        row.windowID = id
        local config = A.db.windows[id]
        local color = id == selected and "|cffffd16b" or "|cffffffff"
        local short = {INCOMING = A.T("私聊 · 最后来信"), RECENT = A.T("私聊 · 最近交谈"),
            FIXED = A.T("私聊 · 固定玩家"), TARGET = A.T("私聊 · 当前目标"), GROUP = A.T("小队 / 团队"),
            CHANNEL = A.T("公共 / 自定义频道")}
        row:SetText(color .. i .. ". " .. names[id] .. "|r\n|cff9ba8b6" ..
            (config.enabled and (short[config.route] or A.labels[config.route] or "") or A.T("不参与 Tab 切换")) .. "|r")
        row:Show()
    end
    for i = #A.db.order + 1, #rows do rows[i]:Hide() end
    panel.listChild:SetHeight(math.max(1, #A.db.order * 44))
    panel.enabled:SetChecked(A.db.enabled)
    panel.skip:SetChecked(A.db.skipUnavailable)
    panel.click:SetChecked(A.db.clickRouting)
    panel.minimap:SetChecked(A.db.minimap)
    local config = selected and A.db.windows[selected]
    panel.detail:SetShown(config ~= nil)
    if not config then return end
    panel.windowTitle:SetText(names[selected] or config.name)
    panel.include:SetChecked(config.enabled)
    panel.destination:SetText((A.labels[config.route] or A.T("保持原生频道")) .. "  v")
    panel.recipient:SetShown(config.route == "FIXED")
    panel.recipientLabel:SetShown(config.route == "FIXED")
    panel.channel:SetShown(config.route == "CHANNEL")
    panel.channelLabel:SetShown(config.route == "CHANNEL")
    panel.recipient:SetText(config.route == "FIXED" and config.target or "")
    panel.channel:SetText((config.target ~= "" and config.target or A.T("选择已加入的频道")) .. "  v")
    local destination, reason = A.Resolve(config, A.Environment())
    panel.status:SetText(destination and A.T("|cff86d3ad当前可用|r") or "|cffffc773" .. reason .. "|r")
    panel.explanation:SetText(selected == 2 and A.T("战斗记录显示战斗事件，不是发送频道；默认保持当前输入频道，也可在这里另设发送目标。")
        or config.route == "INCOMING" and
        A.T("只跟随收到的私聊；你主动密别人不会改变此目标。角色私聊和战网私聊都可记录。")
        or config.route == "RECENT" and A.T("跟随最近一次收到或发出的私聊。刷新界面 / 重新登录后重新记录。")
        or config.route == "CHANNEL" and A.T("按频道名称保存，发言时重新查找编号。退出频道时会跳过，不会误发到同编号的其他频道。")
        or config.route == "KEEP" and A.T("使用游戏原本的输入频道；本窗口仍可参与 Tab 循环。")
        or A.T("切换到这个窗口后，输入框使用上面指定的发送目标。窗口显示哪些消息，仍由魔兽原生聊天设置管理。"))
end

function A.SetLanguage(mode)
    if mode ~= "auto" and mode ~= "zhCN" and mode ~= "enUS" then return end
    A.db.language = mode
    A.UpdateRouteLabels()
    for _, entry in ipairs(localizedWidgets) do entry[1]:SetText(A.T(entry[2])) end
    if panel then
        if popup then popup:Hide() end
        resizeFonts(0)
        refresh()
    end
end

local function move(delta)
    local order = A.db.order
    for i, id in ipairs(order) do
        if id == selected then
            local target = i + delta
            if target >= 1 and target <= #order then order[i], order[target] = order[target], order[i] end
            break
        end
    end
    refresh()
end

local function createPanel()
    panel = CreateFrame("Frame", "TabTalkOptions", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(760, 550)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetScript("OnHide", function() if popup then popup:Hide() end end)
    skin(panel)
    UISpecialFrames[#UISpecialFrames + 1] = "TabTalkOptions"
    text(panel, "TabTalk", 24, -20, "GameFontNormalLarge")
    text(panel, A.T("字号"), 476, -23):SetWidth(44)
    button(panel, "A-", 42, 520, -18, function() resizeFonts(-0.05) end)
    panel.fontValue = text(panel, "", 572, -23)
    panel.fontValue:SetWidth(52)
    button(panel, "A+", 42, 628, -18, function() resizeFonts(0.05) end)
    text(panel, A.T("回车后 Tab → 下一个窗口    Shift + Tab → 上一个窗口"), 24, -51)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    panel.enabled = check(panel, A.T("启用 TabTalk"), 175, -18, function(v) A.db.enabled = v end)
    panel.enabled.caption:SetWidth(200)
    panel.minimap = check(panel, A.T("显示小地图图标"), 20, -78, function(v)
        A.db.minimap = v
        A.minimapButton:SetShown(v)
    end)
    panel.minimap.caption:SetWidth(165)
    panel.click = check(panel, A.T("鼠标点窗口时也切频道"), 330, -78, function(v) A.db.clickRouting = v end)
    panel.skip = check(panel, A.T("自动跳过不可用目标"), 20, -110,
        function(v) A.db.skipUnavailable = v end)
    panel.skip.caption:SetWidth(690)
    text(panel, A.T("已有聊天窗口 · 按下列顺序循环"), 24, -155, "GameFontNormal")
    local list = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 24, -180)
    list:SetSize(210, 290)
    panel.listChild = CreateFrame("Frame", nil, list)
    panel.listChild:SetSize(208, 1)
    list:SetScrollChild(panel.listChild)
    button(panel, A.T("上移"), 70, 24, -480, function() move(-1) end)
    button(panel, A.T("下移"), 70, 98, -480, function() move(1) end)
    button(panel, A.T("刷新"), 70, 172, -480, refresh)
    panel.detail = CreateFrame("Frame", nil, panel)
    panel.detail:SetPoint("TOPLEFT", 286, -155)
    panel.detail:SetSize(442, 350)
    local d = panel.detail
    panel.windowTitle = text(d, "", 0, 0, "GameFontNormalLarge")
    panel.include = check(d, A.T("参与 Tab 循环"), -4, -30, function(v)
        A.db.windows[selected].enabled = v
        refresh()
    end)
    text(d, A.T("这个窗口的默认发送目标"), 0, -76, "GameFontNormal")
    panel.destination = button(d, "", 420, 0, -100, function(self)
        choose(self, A.routes, function(value)
            local config = A.db.windows[selected]
            if config.route ~= value then config.target = "" end
            config.route = value
            refresh()
        end)
    end)
    panel.recipientLabel = text(d, A.T("角色名（跨服可填写 名字-服务器）"), 0, -143)
    panel.recipient = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    panel.recipient:SetSize(410, 26)
    panel.recipient:SetPoint("TOPLEFT", 6, -166)
    panel.recipient:SetAutoFocus(false)
    panel.recipient:SetMaxLetters(100)
    font(panel.recipient, 13)
    panel.recipient:SetScript("OnTextChanged", function(self, userInput)
        if userInput and selected then
            A.db.windows[selected].target = (self:GetText():gsub("^%s+", ""):gsub("%s+$", ""))
        end
    end)
    panel.recipient:SetScript("OnEnterPressed", function(self) self:ClearFocus() refresh() end)
    panel.recipient:SetScript("OnEscapePressed", function(self) self:ClearFocus() refresh() end)
    panel.channelLabel = text(d, A.T("公共 / 自定义频道（仅列出已加入的频道）"), 0, -143)
    panel.channel = button(d, "", 420, 0, -166, function(self)
        local joined, choices = {GetChannelList()}, {}
        for i = 1, #joined, 3 do
            local id, name, disabled = joined[i], joined[i + 1], joined[i + 2]
            if id and name and not disabled then choices[#choices + 1] = {name, id .. ". " .. name} end
        end
        if #choices == 0 then panel.status:SetText(A.T("|cffffc773请先在游戏中加入频道，再回来选择。|r")) return end
        choose(self, choices, function(name) A.db.windows[selected].target = name refresh() end)
    end)
    panel.status = text(d, "", 0, -215)
    panel.status:SetWidth(420)
    panel.explanation = text(d, "", 0, -248)
    panel.explanation:SetWidth(420)
    panel.explanation:SetSpacing(5)
    panel.explanation:SetHeight(86)
    text(panel, A.T("面板大小"), 286, -486):SetWidth(76)
    button(panel, A.T("缩小"), 62, 366, -480, function()
        A.db.uiScale = math.max(0.7, A.db.uiScale - 0.1) fitPanel()
    end)
    button(panel, A.T("放大"), 62, 434, -480, function()
        A.db.uiScale = math.min(1.3, A.db.uiScale + 0.1) fitPanel()
    end)
    button(panel, A.T("恢复大小"), 88, 502, -480, function()
        A.db.uiScale, A.db.fontScale = 1, 1 resizeFonts(0) fitPanel()
    end)
    panel.language = button(panel, "", 134, 600, -480, function(self)
        choose(self, {{"zhCN", "中文 / Chinese"}, {"enUS", "EN / English"}, {"auto", "Auto / 跟随游戏"}}, A.SetLanguage)
    end)
    panel.footer = text(panel, A.T("设置自动保存到当前角色 · /tabtalk 打开设置 · ") .. A.VERSION, 24, -523, "GameFontDisableSmall")
    panel:RegisterEvent("UI_SCALE_CHANGED")
    panel:RegisterEvent("DISPLAY_SIZE_CHANGED")
    panel:SetScript("OnEvent", fitPanel)
end

function A.ToggleOptions()
    if not panel then createPanel() end
    if panel:IsShown() then panel:Hide() return end
    fitPanel()
    resizeFonts(0)
    refresh()
    panel:Show()
end

function A.CreateMinimap()
    local b = CreateFrame("Button", "TabTalkMinimapButton", Minimap)
    A.minimapButton = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:SetMovable(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\AddOns\\TabTalk\\Media\\Icon")
    icon:SetTexCoord(0.16, 0.84, 0.16, 0.84)
    local mask = b:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture(136430) -- Blizzard MiniMap-TrackingBorder, like standard minimap addons.
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    b.icon, b.border, b.mask = icon, border, mask
    b:SetScript("OnMouseDown", function() icon:SetVertexColor(0.75, 0.75, 0.75) end)
    b:SetScript("OnMouseUp", function() icon:SetVertexColor(1, 1, 1) end)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local function position()
        local angle = math.rad(A.db.angle)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * (Minimap:GetWidth() / 2 + 2),
            math.sin(angle) * (Minimap:GetHeight() / 2 + 2))
    end
    position()
    Minimap:HookScript("OnSizeChanged", position)
    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then A.Cycle(IsShiftKeyDown() and -1 or 1)
        else A.ToggleOptions() end
    end)
    b:SetScript("OnDragStart", b.StartMoving)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        local scale = self:GetEffectiveScale() / Minimap:GetEffectiveScale()
        A.db.angle = math.deg(math.atan2(y * scale - my, x * scale - mx))
        position()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("TabTalk")
        GameTooltip:AddLine(A.T("左键：设置\n输入时右键：下一个窗口\nShift + 右键：上一个窗口\n拖动：移动图标"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetShown(A.db.minimap)
end
