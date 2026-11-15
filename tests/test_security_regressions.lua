-- Tests exercise addon contracts, not WoW's taint engine.
local A = TEST_ADDON
local checks = 0
local function check(value, name) assert(value, name) checks = checks + 1 end
for _, frame in pairs(windows) do
    local box = frame.frame.editBox
    check(box:GetScript("OnEnterPressed") == box.nativeEnter, "native Enter preserved")
    check(box:GetScript("OnTabPressed") == box.nativeTab, "native Tab preserved")
end
check(EventRegistry.callbacks["ChatFrame.OnEditBoxPreSendText"] == nil, "addon never enters pre-send chain")
local box = ChatFrame1.editBox
A.db.enabled = true
A.db.windows[3].enabled = true
A.db.windows[3].route = "PARTY"
state.group = true
ChatFrameUtil.ActivateChat(box)
-- Count all relevant addon mutations while restrictions are active.
local writes, attributes, clicks = 0, 0, 0
local setText, setAttr, tabClick = box.SetText, box.SetAttribute, FCF_Tab_OnClick
box.SetText = function(self,text) writes=writes+1 return setText(self,text) end
box.SetAttribute = function(self,key,value) attributes=attributes+1 return setAttr(self,key,value) end
FCF_Tab_OnClick = function(...) clicks=clicks+1 return tabClick(...) end
local cases = {
    function() C_ChatInfo={InChatMessagingLockdown=function() return true end} end,
    function() C_ChatInfo={InChatMessagingLockdown=function() error("query failed") end} end,
    function() C_ChatInfo={InChatMessagingLockdown=function() return {secret=true} end} end,
    function() C_CVar={GetCVarBool=function() return true end} end,
}
for i, setup in ipairs(cases) do
    state.combat=false
    C_ChatInfo,C_CVar,C_InstanceEncounter,C_ChallengeMode=nil,nil,nil,nil
    box.text="unchanged draft"
    box.focus,box.shown=true,true
    setup()
    writes,attributes,clicks=0,0,0
    check(A.ChatRestricted(), "restriction recognized "..i)
    check(not A.Cycle(1,box), "restricted cycle yields native "..i)
    A.RouteBox(box,3)
    ChatFrameUtil.SetLastTellTarget("Alice","WHISPER")
    ChatFrameUtil.ReplyTell()
    check(writes==0 and attributes==0 and clicks==0, "no addon mutation while restricted "..i)
end
state.combat=false
C_ChatInfo={InChatMessagingLockdown=function() return false end}
C_CVar,C_InstanceEncounter,C_ChallengeMode=nil,nil,nil
check(not A.ChatRestricted(), "unrestricted state available")
box.SetText,box.SetAttribute,FCF_Tab_OnClick=setText,setAttr,tabClick
C_ChatInfo=nil
-- Ordinary combat must retain the core feature, with zero text rewriting.
state.combat=true
state.group=true
state.shift=false
A.db.skipUnavailable=true
A.db.windows[1].enabled=true
A.db.windows[1].route="SAY"
A.db.windows[3].enabled=true
A.db.windows[3].route="PARTY"
SELECTED_CHAT_FRAME=ChatFrame1
box=ChatFrame1.editBox
box.focus,box.shown=true,true
box:SetText("combat draft")
box:SetCursorPosition(6)
local originalText,originalCursor=box.SetText,box.SetCursorPosition
local textWrites,cursorWrites=0,0
box.SetText=function(self,value) textWrites=textWrites+1 return originalText(self,value) end
box.SetCursorPosition=function(self,value) cursorWrites=cursorWrites+1 return originalCursor(self,value) end
for _, hasAPI in ipairs({true,false}) do
    C_ChatInfo=hasAPI and {InChatMessagingLockdown=function() return false end} or nil
    SELECTED_CHAT_FRAME=ChatFrame1
    check(not A.ChatRestricted(), "combat alone is not chat lockdown")
    check(A.Cycle(1,box), "combat forward cycle")
    check(SELECTED_CHAT_FRAME==ChatFrame3 and box:GetChatType()=="PARTY", "combat party window and destination")
    check(A.Cycle(-1,box), "combat reverse cycle")
    check(SELECTED_CHAT_FRAME==ChatFrame1 and box:GetChatType()=="SAY", "combat previous window and destination")
    check(textWrites==0 and cursorWrites==0, "combat cycling never rewrites unchanged input")
    check(box:GetText()=="combat draft" and box:GetCursorPosition()==6, "combat draft and cursor preserved")
end
C_ChatInfo={InChatMessagingLockdown=function() return false end}
C_InstanceEncounter={IsEncounterInProgress=function() return true end}
C_ChallengeMode={IsChallengeModeActive=function() return true end}
check(not A.ChatRestricted(), "encounter heuristics do not override unlocked chat API")
box.protected=true
check(not A.Cycle(1,box), "combat protected editor still guarded")
box.protected=false
ChatFrame3.protected=true
local previous=SELECTED_CHAT_FRAME
A.Cycle(1,box)
check(SELECTED_CHAT_FRAME==previous, "combat protected destination not selected")
ChatFrame3.protected=false
C_ChatInfo={InChatMessagingLockdown=function() return true end}
check(not A.Cycle(1,box), "actual chat lockdown still guarded during combat")
state.combat=false
check(not A.Cycle(1,box), "actual chat lockdown also guarded outside combat")
check(textWrites==0, "all restricted attempts leave text untouched")
box.SetText,box.SetCursorPosition=originalText,originalCursor
C_ChatInfo,C_InstanceEncounter,C_ChallengeMode=nil,nil,nil
TEST_CHECKS=TEST_CHECKS+checks
