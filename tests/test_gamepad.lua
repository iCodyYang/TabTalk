-- Contract tests only: the real Blizzard security engine remains a device test.
local A=TEST_ADDON
local function check(v,msg) assert(v,msg); TEST_CHECKS=TEST_CHECKS+1 end
InputUtil={IsGamepadUIEnabled=function() return true end}
C_RestrictedActions={IsAddOnRestrictionActive=function() return state.gamepadRestricted end}
Enum=Enum or {}; Enum.AddOnRestrictionType={Combat=1}
A.db.enabled=true; A.db.clickRouting=true; A.db.skipUnavailable=false
A.db.order={1,2,3,4,5}
for _,id in ipairs(A.db.order) do A.db.windows[id].enabled=true; A.db.windows[id].route='KEEP' end
A.db.windows[3].route='PARTY'; A.db.windows[4].route='INCOMING'
A.incoming={kind='WHISPER',target='Alice'}
state.imStyle=true; state.combat=false
local originalClick,originalActivate=FCF_Tab_OnClick,ChatFrameUtil.ActivateChat
local nativeFocusCalls=0
for id=1,5 do
 local f=_G['ChatFrame'..id]
 f:SetScript('OnShow',nil)
 f.SetGamepadFocus=function(self)
  nativeFocusCalls=nativeFocusCalls+1
  check(self:IsShown(),'target shown before native focus entry')
  for i=1,5 do _G['ChatFrame'..i].editBox:ClearFocus() end
  FCFDock_SelectWindow(nil,self)
  self.editBox:Show(); self.editBox:SetFocus()
  ACTIVE_CHAT_EDIT_BOX=self.editBox
 end
end
FCF_Tab_OnClick=function() error('gamepad cycle must not invoke legacy tab selection') end
ChatFrameUtil.ActivateChat=function() error('addon must not reactivate source editor in gamepad mode') end
SELECTED_CHAT_FRAME=ChatFrame1
local box=ChatFrame1.editBox
box.protected=false; box:Show(); box:SetFocus(); box:SetText('手柄 draft'); box:SetCursorPosition(2)
ACTIVE_CHAT_EDIT_BOX=box
for _,id in ipairs({2,3,4,5,1}) do
 local source=ACTIVE_CHAT_EDIT_BOX
 check(A.Cycle(1,source),'gamepad consumes Tab')
 local target=_G['ChatFrame'..id].editBox
 check(SELECTED_CHAT_FRAME:GetID()==id,'gamepad visits each window including combat log')
 check(target:HasFocus() and not source:HasFocus(),'focus belongs to destination only')
 check(target:GetText()=='手柄 draft' and target:GetCursorPosition()==2,'draft transferred to destination')
 if id==3 then check(target:GetChatType()=='PARTY','gamepad party route') end
 if id==4 then check(target:GetTellTarget()=='Alice','gamepad whisper route') end
end
local before=nativeFocusCalls
state.gamepadRestricted=true
A.Cycle(1,ACTIVE_CHAT_EDIT_BOX)
check(nativeFocusCalls==before and SELECTED_CHAT_FRAME==ChatFrame1,'actual native restriction respected')
state.gamepadRestricted=false
-- Ordinary combat does not disable cycling when the native entry permits it.
state.combat=true
A.Cycle(-1,ACTIVE_CHAT_EDIT_BOX)
check(SELECTED_CHAT_FRAME==ChatFrame5,'ordinary combat reverse cycle')
state.combat=false
-- Controller dock selection bypasses OnClick; passive hook must still route.
ChatFrame4.editBox:SetText('')
FCFDock_SelectWindow(nil,ChatFrame4)
check(ChatFrame4.editBox:GetTellTarget()=='Alice','native controller selection routes recipient')
check(nativeFocusCalls==before+1,'passive route does not steal focus')
-- The mouse callback should also delegate focus to the native entry.
FCF_Tab_OnClick=originalClick
originalClick(ChatFrame3Tab,'LeftButton')
check(ChatFrame3.editBox:HasFocus(),'gamepad mouse selection uses destination editor')
check(ChatFrame3.editBox:GetChatType()=='PARTY','gamepad mouse route')
ChatFrameUtil.ActivateChat=originalActivate
InputUtil=nil; C_RestrictedActions=nil; state.imStyle=false
