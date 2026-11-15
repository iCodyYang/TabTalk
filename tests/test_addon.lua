local A = TEST_ADDON
local function pressTab(box) return box:RunScript("OnTabPressed") end
local checks = 0
local function eq(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
local function ok(value, label) eq(not not value, true, label) end
for _, frame in ipairs(objects) do
    if frame.events.PLAYER_LOGIN then frame.scripts.OnEvent(frame, "PLAYER_LOGIN") break end
end
eq(#sendLog, 0, "login does not send chat")
eq(#A.db.order, 5, "include combat log")
eq(A.db.language, "zhCN", "default Chinese")
eq(A.db.skipUnavailable, false, "all destinations included by default")
for _, id in ipairs(A.db.order) do ok(A.db.windows[id].enabled, "each window enabled by default") end
eq(A.db.order[2], 2, "combat log in native window order")
eq(A.db.windows[3].route, "KEEP", "no guessed routes")
eq(TabTalkOptions, nil, "options created lazily")
local box = ChatFrame1.editBox
ChatFrameUtil.OpenChat("")
SELECTED_CHAT_FRAME=ChatFrame1
box:SetText("combat log draft")
box:SetCursorPosition(3)
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 2, "Tab selects combat log")
ok(box:HasFocus(), "combat log retains input focus")
eq(box:GetText(), "combat log draft", "combat log preserves draft")
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 3, "Tab leaves combat log")
state.shift=true
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 2, "reverse selects combat log")
state.shift=false
-- Remaining regression scenarios explicitly opt out of the log and opt into skipping.
A.db.windows[2].enabled=false
A.db.skipUnavailable=true
SELECTED_CHAT_FRAME=ChatFrame1
A.db.windows[1].route = "SAY"
A.db.windows[3].route = "PARTY"
A.db.windows[4].route = "INCOMING"
A.db.windows[5].route, A.db.windows[5].target = "CHANNEL", "Trade"
ChatFrameUtil.OpenChat("")
box:SetText("你好，|Hitem:123|h[测试物品]|h")
box:SetCursorPosition(6)
local draft = box:GetText()
ok(pressTab(box), "Tab consumed")
eq(SELECTED_CHAT_FRAME.id, 3, "next window selected")
eq(box:GetChatType(), "PARTY", "party route")
eq(box:GetText(), draft, "Chinese text and item link preserved")
eq(box:GetCursorPosition(), 6, "cursor preserved")
eq(box.setText, 0, "queued native update cannot overwrite restored draft")
state.shift = true
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 1, "Shift Tab previous")
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 5, "backward wrap")
eq(box:GetAttribute("channelTarget"), 2, "channel ID looked up")
state.shift = false
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 1, "forward wrap")
ChatFrameUtil.SetLastToldTarget("Bob", "WHISPER")
eq(A.Resolve(A.db.windows[4], A.Environment()), nil, "incoming NEVER falls back to last outgoing")
ChatFrameUtil.SetLastTellTarget("Alice-Realm", "WHISPER")
ChatFrameUtil.SetLastToldTarget("Bob", "WHISPER")
local destination = A.Resolve(A.db.windows[4], A.Environment())
eq(destination.target, "Alice-Realm", "strict last incoming remains Alice")
destination = A.Resolve({route = "RECENT"}, A.Environment())
eq(destination.target, "Bob", "recent follows outgoing")
ChatFrameUtil.SetLastTellTarget("BattleFriend", "BN_WHISPER")
destination = A.Resolve(A.db.windows[4], A.Environment())
eq(destination.kind, "BN_WHISPER", "BNet type preserved")
A.RecordWhisper({secret = true}, "WHISPER", true)
eq(A.incoming.target, "BattleFriend", "secret targets ignored")
state.group = false
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 4, "skip ungrouped party")
eq(box:GetTellTarget(), "BattleFriend", "private recipient")
state.channels.Trade = 8
pressTab(box)
eq(box:GetAttribute("channelTarget"), 8, "renumbered channel resolved by name")
state.channels.Trade = nil
FCF_Tab_OnClick(ChatFrame1Tab, "LeftButton")
A.incoming = nil
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 1, "all unavailable windows skipped")
A.db.skipUnavailable = false
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 3, "skip=false visits unavailable destination")
local sent = #sendLog
ok(box:IsShown() and box:HasFocus(), "unavailable targets never steal focus")
eq(box:GetText(), draft, "unavailable targets keep draft")
state.group = true
ChatFrameUtil.OpenChat("", ChatFrame3)
box = ChatFrame3.editBox
box:SetText("party message")
box:RunScript("OnEnterPressed")
eq(#sendLog, sent + 1, "now available route can send")
eq(sendLog[#sendLog].kind, "PARTY", "revalidated send destination")
state.group = false
A.RouteBox(box, 3)
box:SetAttribute("chatType", "SAY")
box:SetText("manual destination")
box:RunScript("OnEnterPressed")
eq(sendLog[#sendLog].kind, "SAY", "manual slash routing overrides blocked default")
box:SetText("/whisper Al")
eq(pressTab(box), false, "slash autocomplete retained")
ChatFrameUtil.ActivateChat(box)
box:SetText("你好")
box.ime = true
eq(pressTab(box), false, "Chinese IME composition retained")
box.ime = false
A.db.enabled = false
eq(pressTab(box), false, "global disable restores Tab")
A.db.enabled = true
box.protected, state.combat = true, true
eq(pressTab(box), false, "do not touch combat-protected editbox")
box.protected, state.combat = false, false
state.group, A.db.skipUnavailable = true, true
SELECTED_CHAT_FRAME = ChatFrame1
state.imStyle = true
box:SetText(draft)
pressTab(box)
eq(box:GetText(), draft, "IM-style hide does not lose draft")
ok(box:HasFocus(), "focus restored after IM tab switch")
state.imStyle = false
ChatFrameUtil.SetLastTellTarget("ReplyPerson", "WHISPER")
SELECTED_CHAT_FRAME = ChatFrame3
ChatFrameUtil.ReplyTell()
box = ChatFrame1.editBox
eq(box:GetChatType(), "WHISPER", "R reply overrides party mapping")
eq(box:GetTellTarget(), "ReplyPerson", "R recipient preserved")
ChatFrameUtil.SetLastToldTarget("SentPerson", "WHISPER")
ChatFrameUtil.ReplyTell2()
eq(box:GetTellTarget(), "SentPerson", "reply-to-outgoing override")
ChatFrameUtil.SendBNetTell("BNPerson")
eq(box:GetTellTarget(), "BNPerson", "BNet explicit recipient preserved")
eq(box:GetChatType(), "BN_WHISPER", "BNet explicit type preserved")
state.bnetCharacter = "Character-Realm"
ChatFrameUtil.SendBNetTell("BNPerson")
eq(box:GetTellTarget(), "Character-Realm", "BNet title-friend route preserved")
eq(box:GetChatType(), "WHISPER", "title friend uses character whisper")
state.bnetCharacter = nil
box:SetAttribute("chatType", "YELL")
ChatFrameUtil.OpenChat("/g hello")
eq(box:GetChatType(), "YELL", "OpenChat slash text not remapped")
FCF_SetWindowName(ChatFrame3, "副本伙伴")
A.RefreshWindows()
eq(A.db.windows[3].route, "PARTY", "renamed window retains config")
FCF_Close(ChatFrame4)
makeWindow(4, "新窗口")
A.RefreshWindows()
eq(A.db.windows[4].route, "KEEP", "reused window slot drops private target")
destination = A.Resolve({route = "FIXED", target = "Name-Realm"}, A.Environment())
eq(destination.target, "Name-Realm", "fixed realm target")
eq(A.Resolve({route = "FIXED", target = "/s hello"}, A.Environment()), nil, "invalid recipient rejected")
state.target, state.realm = "Target", "Realm"
destination = A.Resolve({route = "TARGET"}, A.Environment())
eq(destination.target, "Target-Realm", "target realm retained")
state.raid = true
destination = A.Resolve({route = "GROUP"}, A.Environment())
eq(destination.kind, "RAID", "smart group raid")
eq(A.Resolve({route = "RAID_WARNING"}, A.Environment()), nil, "raid warning permission")
state.leader = true
ok(A.Resolve({route = "RAID_WARNING"}, A.Environment()), "raid leader warning allowed")
state.guild = false
eq(A.Resolve({route = "GUILD"}, A.Environment()), nil, "unguilded skipped")
eq(A.Resolve({route = "OFFICER"}, A.Environment()), nil, "unguilded officer skipped")
state.guild = true
ok(A.Resolve({route = "OFFICER"}, A.Environment()), "no false officer-note permission assumption")
eq(A.Resolve({route = "INSTANCE_CHAT"}, A.Environment()), nil, "no instance party skipped")
state.instance = true
ok(A.Resolve({route = "INSTANCE_CHAT"}, A.Environment()), "instance group route")
A.db.windows[3].enabled = false
SELECTED_CHAT_FRAME = ChatFrame1
ChatFrameUtil.ActivateChat(box)
box:SetText("text")
pressTab(box)
eq(SELECTED_CHAT_FRAME.id, 4, "disabled window skipped")
A.ToggleOptions()
ok(TabTalkOptions:IsShown(), "settings open")
ok(TabTalkOptions.detail:IsShown(), "settings detail exists")
ok(TabTalkOptions.listChild:GetHeight() > 0, "window list rendered")
A.ToggleOptions()
eq(TabTalkOptions:IsShown(), false, "settings close")
for _, obj in ipairs(objects) do eq(obj.scripts.OnUpdate, nil, "no addon OnUpdate") end
TEST_CHECKS = checks
