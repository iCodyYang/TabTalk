local _, A = ...
local busy = false
local hooked = setmetatable({}, {__mode = "k"})
local blocked = setmetatable({}, {__mode = "k"})
local eventFrame = CreateFrame("Frame")
local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end
local function util(name, legacy, ...)
    local fn = ChatFrameUtil and ChatFrameUtil[name] or _G[legacy]
    if fn then return fn(...) end
end
local function activeBox()
    local box = util("GetActiveWindow", "ChatEdit_GetActiveWindow")
    if box and box:HasFocus() then return box end
    for id = 1, NUM_CHAT_WINDOWS or 10 do
        local frame = _G["ChatFrame" .. id]
        local candidate = frame and frame.editBox or _G["ChatFrame" .. id .. "EditBox"]
        if candidate and candidate:HasFocus() then return candidate end
    end
end
local function frameForID(id)
    return FCF_GetChatFrameByID and FCF_GetChatFrameByID(id) or _G["ChatFrame" .. id]
end
local function getType(box) return box:GetAttribute("chatType") end
local function header(box)
    if box.UpdateHeader then box:UpdateHeader()
    elseif ChatEdit_UpdateHeader then ChatEdit_UpdateHeader(box) end
end
local function canTouch(box)
    if not box or box.isGM or box.disableActivate then return false end
    if InCombatLockdown() and box.IsProtected and box:IsProtected() then return false end
    return true
end

function A.Environment()
    local name, realm
    if UnitIsPlayer("target") then name, realm = UnitName("target") end
    if not readable(name) or not readable(realm) then name, realm = nil, nil end
    if name and realm and realm ~= "" then name = name .. "-" .. realm end
    return {
        group = IsInGroup(LE_PARTY_CATEGORY_HOME), raid = IsInRaid(LE_PARTY_CATEGORY_HOME),
        instance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE), guild = IsInGuild(),
        raidOfficer = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"),
        -- There is no reliable public per-player officer-speak query on this build.
        -- Let the client enforce rank permissions; editing notes is NOT equivalent.
        playerTarget = name,
        channel = function(channelName) return GetChannelName(channelName) end,
        supported = function(kind) return ChatTypeInfo and ChatTypeInfo[kind] ~= nil end,
    }
end

local function apply(box, destination)
    blocked[box] = nil
    if destination.kind == "KEEP" then return end
    box:SetAttribute("chatType", destination.kind)
    box:SetAttribute("tellTarget", destination.target)
    box:SetAttribute("channelTarget", destination.channel)
    header(box)
end

local function sameBlockedDestination(box, state)
    return getType(box) == state.kind
        and box:GetAttribute("tellTarget") == state.target
        and box:GetAttribute("channelTarget") == state.channel
end

-- An unavailable mapped destination must never quietly send to the old one.
local function block(box, config, reason)
    box:SetAttribute("chatType", "WHISPER")
    box:SetAttribute("tellTarget", nil)
    box:SetAttribute("channelTarget", nil)
    blocked[box] = {kind = "WHISPER", config = config}
    header(box)
    local label = box.header or _G[box:GetName() .. "Header"]
    if label then label:SetText((A.labels[config.route] or "TabTalk") .. "（" .. reason .. "）：") end
end

local function routeBox(box, id)
    local config = id and A.db.windows[id]
    if not config or not canTouch(box) then return end
    local destination, reason = A.Resolve(config, A.Environment())
    if destination then apply(box, destination) else block(box, config, reason) end
end

local function installBox(box)
    if not canTouch(box) or hooked[box] then return end
    hooked[box] = true
    -- Bind the actual widget event, not a global extension point that some client
    -- branches never dispatch (or another addon can replace after login).
    local originalTab = box:GetScript("OnTabPressed")
    box:SetScript("OnTabPressed", function(self, ...)
        local completing = AutoCompleteBox and AutoCompleteBox:IsShown()
            and AutoCompleteBox:GetParent() == self
        if not completing and A.Cycle(IsShiftKeyDown() and -1 or 1, self) then return true end
        if originalTab then return originalTab(self, ...) end
        return false
    end)
    local originalEnter = box:GetScript("OnEnterPressed")
    box:SetScript("OnEnterPressed", function(self, ...)
        local state = blocked[self]
        if state and A.db.enabled and sameBlockedDestination(self, state) then
            local text = self:GetText()
            if not readable(text) then return end
            if not text:match("^%s*/") then
                local destination, reason = A.Resolve(state.config, A.Environment())
                if not destination then block(self, state.config, reason) return end
                apply(self, destination)
            end
        end
        blocked[self] = nil
        if originalEnter then return originalEnter(self, ...) end
    end)
    box:HookScript("OnHide", function(self) blocked[self] = nil end)
end

function A.RefreshWindows()
    local windows = {}
    local count = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows
        or NUM_CHAT_WINDOWS or 10
    for id = 1, count do
        local frame = frameForID(id)
        if frame and id ~= 2 and frame ~= COMBATLOG and not frame.isTemporary then
            local info = FCF_GetChatWindowInfo or GetChatWindowInfo
            local name, _, _, _, _, _, shown, _, docked = info(id)
            if readable(name) and type(name) == "string" and name ~= ""
                and (shown or docked or frame.isDocked) then
                windows[#windows + 1] = {id = id, name = name, frame = frame}
                installBox(frame.editBox or _G[frame:GetName() .. "EditBox"])
            end
        end
    end
    A.SyncWindows(windows)
    return windows
end

local function selectedID(box)
    local frame = SELECTED_CHAT_FRAME or SELECTED_DOCK_FRAME or (box and box.chatFrame)
    return frame and frame:GetID()
end

local function plainInput(box)
    local text = box:GetText()
    if not readable(text) then return false end
    -- Preserve slash-command/name completion and Chinese IME composition.
    if text:match("^%s*/") then return false end
    if box.IsInIMECompositionMode then
        local composing = box:IsInIMECompositionMode()
        if composing == true or composing == 1 then return false end
    end
    return true
end

function A.Cycle(direction, box)
    box = box or activeBox()
    if not A.db or not A.db.enabled or busy or not canTouch(box) or not box:HasFocus() then return false end
    if not plainInput(box) then return false end
    A.RefreshWindows()
    local env = A.Environment()
    local id = A.NextWindow(selectedID(box), direction, function(config) return A.Resolve(config, env) end)
    -- Consume Tab even if nothing is available: do not fall into native whisper cycling.
    if not id then return true end
    local frame = frameForID(id)
    local tab = frame and _G[frame:GetName() .. "Tab"]
    if not frame or not tab then return true end
    if InCombatLockdown() and ((frame.IsProtected and frame:IsProtected())
        or (tab.IsProtected and tab:IsProtected())) then return true end
    local text, cursor = box:GetText(), box:GetCursorPosition()
    busy = true
    -- Keep one input draft while changing the native selected tab. No chat filters change.
    FCF_Tab_OnClick(tab, "LeftButton")
    if not box:HasFocus() or not box:IsShown() then
        util("ActivateChat", "ChatEdit_ActivateChat", box)
    end
    -- A queued native OpenChat update must not overwrite the restored draft next frame.
    box.setText = 0
    box.desiredCursorPosition = nil
    box:SetText(text)
    box:SetCursorPosition(cursor)
    routeBox(box, id)
    busy = false
    return true
end

local function openChat(text, explicitFrame)
    if busy or not A.db.enabled or (text and text ~= "") then return end
    local box = activeBox()
    if not canTouch(box) then return end
    -- Dedicated per-person popout windows retain their native recipient.
    if explicitFrame and explicitFrame.isTemporary then return end
    A.RefreshWindows()
    routeBox(box, explicitFrame and explicitFrame:GetID() or selectedID(box))
end

local function clickedTab(tab, button)
    if busy or button ~= "LeftButton" or not A.db.enabled or not A.db.clickRouting then return end
    A.RefreshWindows()
    local box = activeBox()
    if box and plainInput(box) then routeBox(box, tab:GetID()) end
end

local function hookUtil(name, legacy, callback)
    if ChatFrameUtil and type(ChatFrameUtil[name]) == "function" then
        hooksecurefunc(ChatFrameUtil, name, callback)
    elseif type(_G[legacy]) == "function" then hooksecurefunc(legacy, callback) end
end

local function explicitReply(getter, legacy)
    if not A.db.enabled then return end
    local target, kind = util(getter, legacy)
    local box = activeBox()
    if readable(target) and target and canTouch(box) then apply(box, {kind = kind, target = target}) end
end

local function initialize()
    TabTalkDB = A.InitDB(TabTalkDB)
    A.RefreshWindows()
    hookUtil("OpenChat", "ChatFrame_OpenChat", openChat)
    hookUtil("SetLastTellTarget", "ChatEdit_SetLastTellTarget", function(target, kind)
        A.RecordWhisper(target, kind, true)
    end)
    hookUtil("SetLastToldTarget", "ChatEdit_SetLastToldTarget", function(target, kind)
        A.RecordWhisper(target, kind, false)
    end)
    -- OpenChat is also used by explicit reply actions; restore their intended recipient.
    hookUtil("ReplyTell", "ChatFrame_ReplyTell", function()
        explicitReply("GetLastTellTarget", "ChatEdit_GetLastTellTarget")
    end)
    hookUtil("ReplyTell2", "ChatFrame_ReplyTell2", function()
        explicitReply("GetLastToldTarget", "ChatEdit_GetLastToldTarget")
    end)
    hookUtil("SendBNetTell", "ChatFrame_SendBNetTell", function(target)
        local box = activeBox()
        if readable(target) and target and canTouch(box) and A.db.enabled then
            local character = ChatFrameUtil and ChatFrameUtil.GetCharacterWhisperTargetIfTitleFriend
                and ChatFrameUtil.GetCharacterWhisperTargetIfTitleFriend(target)
            apply(box, {kind = character and "WHISPER" or "BN_WHISPER", target = character or target})
        end
    end)
    hooksecurefunc("FCF_Tab_OnClick", clickedTab)
    hooksecurefunc("FCF_SetWindowName", function(frame, name)
        local config = A.db.windows[frame:GetID()]
        if config and readable(name) then config.name = name end
    end)
    hooksecurefunc("FCF_Close", function(frame)
        A.db.windows[frame:GetID()] = nil
    end)
    SLASH_TABTALK1 = "/tabtalk"
    SLASH_TABTALK2 = "/ttalk"
    SlashCmdList.TABTALK = function() A.ToggleOptions() end
    A.CreateMinimap()
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    initialize()
end)

-- Exposed only in the shared addon namespace for deterministic adapter tests.
A.RouteBox = routeBox
A.ActiveBox = activeBox
