local _, A = ...
local busy = false
local compatible = false
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
-- Fail closed if a restriction query returns a secret or cannot be evaluated.
local function restrictedBy(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    if not ok or not readable(value) then return true end
    return value == true or value == 1
end
-- Ask the chat API, not combat/encounter heuristics. Ordinary combat can
-- leave chat unrestricted; conversely chat can be restricted outside combat.
local function chatRestricted()
    if C_ChatInfo and restrictedBy(C_ChatInfo.InChatMessagingLockdown) then return true end
    local getBool = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    if restrictedBy(getBool, "addonChatRestrictionsForced") then return true end
    return false
end
-- The Forever gamepad UI owns selection, focus and its ABXY binding groups.
local function gamepadUI()
    return InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function"
        and restrictedBy(InputUtil.IsGamepadUIEnabled)
end
local function gamepadSelectionRestricted()
    local query = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    local kind = Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Combat
    return query and kind and restrictedBy(query, kind)
end
local function focusGamepadWindow(frame)
    -- Use Blizzard's already registered FrameShown entry via SetGamepadFocus.
    -- Do not call FocusGamepad, FocusFrame or binding-manager internals directly.
    if not frame or type(frame.SetGamepadFocus) ~= "function"
        or gamepadSelectionRestricted() then return false end
    if restrictedBy(InCombatLockdown) and frame.IsProtected and frame:IsProtected() then return false end
    if not frame:IsShown() then frame:Show() end
    frame:SetGamepadFocus()
    return true
end

local function canTouch(box)
    if not compatible or not box or box.isGM or box.disableActivate or chatRestricted() then return false end
    -- Combat alone is not a chat restriction. Only protect genuinely locked frames.
    if restrictedBy(InCombatLockdown) and box.IsProtected and box:IsProtected() then return false end
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
    if not canTouch(box) then return end
    if destination.kind == "KEEP" then return end
    box:SetAttribute("chatType", destination.kind)
    box:SetAttribute("tellTarget", destination.target)
    box:SetAttribute("channelTarget", destination.channel)
    header(box)
end

-- Keep the editor active even when a selected destination is unavailable.
-- Preserve configured group channels even before joining. Native headers own
-- text insets; never replace their text after UpdateHeader. Sending stays native.
local function routeBox(box, id)
    local config = id and A.db.windows[id]
    if not config or not canTouch(box) then return end
    local env = A.Environment()
    local destination = A.Resolve(config, env)
    if destination then
        apply(box, destination)
    elseif A.db.skipUnavailable and not busy then
        A.Cycle(1, box)
    else
        local kind = config.route
        if kind == "GROUP" then kind = env.raid and "RAID" or "PARTY" end
        if (kind == "PARTY" or kind == "RAID" or kind == "RAID_WARNING"
            or kind == "INSTANCE_CHAT" or kind == "GUILD" or kind == "OFFICER")
            and env.supported(kind) then
            apply(box, {kind = kind})
        else
            -- No recipient: clear the old target, keep the native whisper header.
            apply(box, {kind = "WHISPER", target = ""})
        end
    end
end

function A.RefreshWindows()
    local windows = {}
    local count = Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows
        or NUM_CHAT_WINDOWS or 10
    for id = 1, count do
        local frame = frameForID(id)
        if frame and not frame.isTemporary then
            local info = FCF_GetChatWindowInfo or GetChatWindowInfo
            local name, _, _, _, _, _, shown, _, docked = info(id)
            if readable(name) and type(name) == "string" and name ~= ""
                and (shown or docked or frame.isDocked) then
                windows[#windows + 1] = {id = id, name = name, frame = frame}
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
        if not readable(composing) or composing == true or composing == 1 then return false end
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
    if gamepadUI() then
        local targetBox = frame.editBox or _G[frame:GetName() .. "EditBox"]
        if not canTouch(targetBox) then return true end
        busy = true
        local selected = focusGamepadWindow(frame)
        -- Native FocusGamepad activates the destination's editor. Never pull
        -- focus back to the source editor (the 1.0.8 gamepad regression).
        if selected and targetBox:HasFocus() then
            local current = targetBox:GetText()
            if readable(current) and current ~= text then targetBox:SetText(text) end
            if targetBox:GetCursorPosition() ~= cursor then targetBox:SetCursorPosition(cursor) end
            routeBox(targetBox, id)
        end
        busy = false
        return true
    end
    busy = true
    -- Keep one input draft while changing the native selected tab. No chat filters change.
    FCF_Tab_OnClick(tab, "LeftButton")
    if not box:HasFocus() or not box:IsShown() then
        util("ActivateChat", "ChatEdit_ActivateChat", box)
    end
    -- A queued native OpenChat update must not overwrite the restored draft next frame.
    if box.setText == 1 then
        box.setText = 0
        box.desiredCursorPosition = nil
    end
    -- Normal tab selection must not rewrite text/cursor merely to keep them.
    local currentText = box:GetText()
    if readable(currentText) and currentText ~= text then box:SetText(text) end
    if box:GetCursorPosition() ~= cursor then box:SetCursorPosition(cursor) end
    routeBox(box, id)
    busy = false
    return true
end

local function openChat(text, explicitFrame)
    if busy or not A.db.enabled or not readable(text) then return end
    if text and text ~= "" then
        return
    end
    local box = activeBox()
    if not canTouch(box) then return end
    -- Dedicated per-person popout windows retain their native recipient.
    if explicitFrame and explicitFrame.isTemporary then return end
    A.RefreshWindows()
    routeBox(box, explicitFrame and explicitFrame:GetID() or selectedID(box))
end

local function clickedTab(tab, button)
    if busy or button ~= "LeftButton" or not A.db.enabled or not A.db.clickRouting then return end
    if chatRestricted() then return end
    A.RefreshWindows()
    local id = tab:GetID()
    local frame = frameForID(id)
    if not frame or frame.isTemporary or not A.db.windows[id] then return end
    if gamepadUI() then
        local box = frame.editBox or _G[frame:GetName() .. "EditBox"]
        if not canTouch(box) or not plainInput(box) then return end
        busy = true
        focusGamepadWindow(frame)
        routeBox(box, id)
        busy = false
        return
    end
    local box = activeBox() or util("GetActiveWindow", "ChatEdit_GetActiveWindow")
        or frame.editBox or _G[frame:GetName() .. "EditBox"]
    if not canTouch(box) or not plainInput(box) then return end
    if restrictedBy(InCombatLockdown) and ((frame.IsProtected and frame:IsProtected())
        or (tab.IsProtected and tab:IsProtected())) then return end
    -- Clicking a tab can leave the editor unfocused (or never open it).
    -- Activate without OpenChat: it would replace an existing draft.
    if not box:HasFocus() or not box:IsShown() then
        util("ActivateChat", "ChatEdit_ActivateChat", box)
    end
    if box:HasFocus() then routeBox(box, id) end
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
    -- Blizzard explicitly dispatches this extension through securecall.
    -- Never replace native edit-box scripts, even if another addon owns Tab.
    local previousTab = ChatEdit_CustomTabPressed
    compatible = type(previousTab) == "function"
    if compatible then
        ChatEdit_CustomTabPressed = function(box)
            if A.Cycle(IsShiftKeyDown() and -1 or 1, box) then return true end
            return previousTab(box)
        end
    end
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
    -- Native controller previous/next-tab actions select the dock directly,
    -- without FCF_Tab_OnClick. Follow that selection like CodyChatTabs did.
    if type(FCFDock_SelectWindow) == "function" then
        hooksecurefunc("FCFDock_SelectWindow", function(_, frame)
            if busy or not A.db.enabled or not A.db.clickRouting or not gamepadUI()
                or not frame or frame.isTemporary then return end
            local box = frame.editBox
            if not canTouch(box) or not plainInput(box) then return end
            A.RefreshWindows()
            busy = true
            routeBox(box, frame:GetID())
            busy = false
        end)
    end
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

A.ChatRestricted = chatRestricted
