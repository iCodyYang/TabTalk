function GetLocale() return TEST_LOCALE or "zhCN" end
-- Purposefully limited client double. It cannot simulate WoW taint/security or IME.
objects, sendLog, nativeTabs = {}, {}, 0
local methods = {}
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...) if old then old(...) end fn(...) end
end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:GetParent() return self.parent end
function methods:SetFont(path, size, flags) self.fontPath, self.fontSize = path, size end
function methods:GetFontString()
    if not self.caption then self.caption = self:CreateFontString() end
    return self.caption
end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function methods:CreateMaskTexture() return CreateFrame("MaskTexture", nil, self) end
function methods:AddMaskTexture(mask) self.mask = mask end
function methods:SetTexture(value) self.texture = value end
function methods:SetWordWrap(value) self.wrap = value end
function methods:SetMaxLines(value) self.maxLines = value end
function methods:SetScale(value) self.scale = value end
function methods:SetColorTexture(r,g,b,a) self.color = {r,g,b,a} end
function methods:GetName() return self.name end
function methods:GetID() return self.id end
function methods:SetID(id) self.id = id end
function methods:SetText(value) self.text = value if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end end
function methods:GetText() return self.text or "" end
function methods:SetAttribute(key, value) self.attrs[key] = value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetChatType(value) self:SetAttribute("chatType", value) end
function methods:GetChatType() return self:GetAttribute("chatType") end
function methods:SetTellTarget(value) self:SetAttribute("tellTarget", value) end
function methods:GetTellTarget() return self:GetAttribute("tellTarget") end
function methods:UpdateHeader() self.header:SetText(self:GetChatType() or "") end
function methods:GetCursorPosition() return self.cursor or #self:GetText() end
function methods:SetCursorPosition(value) self.cursor = value end
function methods:IsShown() return self.shown ~= false end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:HasFocus() return self.focus == true end
function methods:SetFocus() self.focus = true end
function methods:ClearFocus() self.focus = false end
function methods:IsProtected() return self.protected == true end
function methods:IsInIMECompositionMode() return self.ime == true end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width or 1024 end
function methods:GetHeight() return self.height or 768 end
function methods:GetFrameLevel() return 1 end
function methods:GetCenter() return 100, 100 end
function methods:GetEffectiveScale() return 1 end
function methods:SetScrollChild(child) self.child = child end
for _, method in ipairs({"SetPoint", "ClearAllPoints", "SetFrameStrata", "SetFrameLevel", "SetClampedToScreen",
    "SetMovable", "EnableMouse", "EnableMouseWheel", "RegisterForDrag", "RegisterForClicks", "SetBackdrop",
    "SetBackdropColor", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetAutoFocus",
    "SetAllPoints", "SetTexCoord", "SetVertexColor", "SetMaxLetters", "SetJustifyH", "SetSpacing", "StartMoving", "StopMovingOrSizing", "Raise"}) do
    methods[method] = function() end
end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({scripts = {}, attrs = {}, events = {}, name = name or "Anonymous", parent = parent,
        template = template}, {__index = methods})
    if name then _G[name] = frame end
    objects[#objects + 1] = frame
    return frame
end
function methods:CreateFontString() return CreateFrame("FontString") end
UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = {SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end}
UISpecialFrames, SlashCmdList = {}, {}
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
Constants = {ChatFrameConstants = {MaxChatWindows = 10}}
ChatTypeInfo = {}
for _, kind in ipairs({"SAY", "YELL", "EMOTE", "PARTY", "RAID", "RAID_WARNING", "INSTANCE_CHAT", "GUILD", "OFFICER", "WHISPER", "BN_WHISPER", "CHANNEL"}) do ChatTypeInfo[kind] = {} end
state = {group = true, raid = false, instance = false, guild = true, channels = {General = 1, Trade = 2}}
function IsInGroup(category) return category == 2 and state.instance or category == 1 and state.group end
function IsInRaid() return state.raid end
function IsInGuild() return state.guild end
function UnitIsGroupLeader() return state.leader end
function UnitIsGroupAssistant() return state.assistant end
function UnitIsPlayer() return state.target ~= nil end
function UnitName() return state.target, state.realm end
function InCombatLockdown() return state.combat end
function IsShiftKeyDown() return state.shift end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function GetChannelName(name) return state.channels[name] or 0 end
function GetChannelList() return 1, "General", false, 2, "Trade", false end
function hooksecurefunc(object, key, fn)
    if type(object) == "string" then object, key, fn = _G, object, key end
    local original = object[key]
    assert(type(original) == "function", key)
    object[key] = function(...) local result = original(...) fn(...) return result end
end
windows = {}
function makeWindow(id, name)
    local f = CreateFrame("Frame", "ChatFrame" .. id)
    f.id, f.isDocked = id, true
    f.editBox = CreateFrame("EditBox", "ChatFrame" .. id .. "EditBox")
    f.editBox.chatFrame = f
    f.editBox.header = f.editBox:CreateFontString()
    f.editBox:SetAttribute("chatType", "SAY")
    f.editBox:SetAttribute("stickyType", "SAY")
    f.editBox:SetScript("OnEnterPressed", function(box)
        sendLog[#sendLog + 1] = {kind = box:GetChatType(), text = box:GetText(), target = box:GetTellTarget()}
    end)
    f.editBox:SetScript("OnTabPressed", function() nativeTabs = nativeTabs + 1 return false end)
    f.editBox.SecureTabPressed = function() nativeTabs = nativeTabs + 1 end
    local tab = CreateFrame("Button", f.name .. "Tab")
    tab.id = id
    windows[id] = {name = name, frame = f}
    return f
end
makeWindow(1, "综合")
makeWindow(2, "战斗记录")
makeWindow(3, "小队")
makeWindow(4, "私聊")
makeWindow(5, "交易")
function FCF_GetChatFrameByID(id) return windows[id] and windows[id].frame end
function GetChatWindowInfo(id)
    if windows[id] then return windows[id].name, 12, 1, 1, 1, 1, true, false, true end
end
FCF_GetChatWindowInfo = GetChatWindowInfo
function FCF_Tab_OnClick(tab, mouseButton)
    if mouseButton ~= "LeftButton" then return end
    SELECTED_CHAT_FRAME = FCF_GetChatFrameByID(tab.id)
    SELECTED_DOCK_FRAME = SELECTED_CHAT_FRAME
    if state.imStyle and ACTIVE_CHAT_EDIT_BOX then
        ACTIVE_CHAT_EDIT_BOX:ClearFocus()
        ACTIVE_CHAT_EDIT_BOX:Hide()
        ACTIVE_CHAT_EDIT_BOX:SetText("")
        ACTIVE_CHAT_EDIT_BOX = nil
    end
end
function FCF_SetWindowName(frame, name) windows[frame.id].name = name end
function FCF_Close(frame) windows[frame.id] = nil end
ChatFrameUtil = {}
function ChatFrameUtil.GetActiveWindow() return ACTIVE_CHAT_EDIT_BOX end
function ChatFrameUtil.ActivateChat(box)
    ACTIVE_CHAT_EDIT_BOX = box
    box:Show()
    box:SetFocus()
end
function ChatFrameUtil.OpenChat(value, frame)
    local box = (frame or ChatFrame1).editBox
    ChatFrameUtil.ActivateChat(box)
    box.text, box.setText = value, 1
end
function ChatFrameUtil.SetLastTellTarget(target, kind) state.lastIn, state.lastInKind = target, kind end
function ChatFrameUtil.SetLastToldTarget(target, kind) state.lastOut, state.lastOutKind = target, kind end
function ChatFrameUtil.GetLastTellTarget() return state.lastIn, state.lastInKind end
function ChatFrameUtil.GetLastToldTarget() return state.lastOut, state.lastOutKind end
function ChatFrameUtil.ReplyTell()
    ChatFrameUtil.OpenChat("")
end
ChatFrameUtil.ReplyTell2 = ChatFrameUtil.ReplyTell
function ChatFrameUtil.SendBNetTell() ChatFrameUtil.OpenChat("") end
function ChatFrameUtil.GetCharacterWhisperTargetIfTitleFriend() return state.bnetCharacter end
function ChatEdit_CustomTabPressed() return false end
function AutoCompleteEditBox_OnTabPressed() return state.autocomplete end
function securecall(name, ...) return _G[name](...) end
SELECTED_CHAT_FRAME = ChatFrame1
SELECTED_DOCK_FRAME = ChatFrame1
