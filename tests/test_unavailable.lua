local A=TEST_ADDON
local count=0
local function check(v,msg) assert(v,msg) count=count+1 end
local box=ChatFrame1.editBox
A.db.enabled=true
A.incoming,A.recent=nil,nil
state.group,state.raid,state.guild=false,false,true
A.db.order={1,4,3,5}
for _,id in ipairs(A.db.order) do A.db.windows[id].enabled=true end
A.db.windows[1].route='SAY'
A.db.windows[4].route='INCOMING'
A.db.windows[3].route='PARTY'
A.db.windows[5].route='GUILD'
for _,im in ipairs({false,true}) do
 for _,oldSkip in ipairs({true}) do
  state.imStyle=im
  A.db.skipUnavailable=oldSkip
  for _,draft in ipairs({'','测试草稿 |Hitem:123|h[物品]|h'}) do
   ChatFrameUtil.ActivateChat(box)
   box:SetText(draft)
   box:SetCursorPosition(0)
   SELECTED_CHAT_FRAME=ChatFrame1
   local sent=#sendLog
   for i=1,10 do
    state.shift=false
    box:RunScript('OnTabPressed')
    check(SELECTED_CHAT_FRAME==ChatFrame5,'forward skips missing recipient and party')
    state.shift=true
    box:RunScript('OnTabPressed')
    check(SELECTED_CHAT_FRAME==ChatFrame1,'reverse skips missing recipient and party')
    check(box:IsShown() and box:HasFocus(),'focus survives repeated cycles')
    check(box:GetText()==draft and box:GetCursorPosition()==0,'draft and cursor survive')
   end
   state.shift=false
   check(#sendLog==sent,'switching never sends')
  end
 end
end
state.imStyle=false
ChatFrameUtil.ActivateChat(box)
box:SetText('mouse draft')
FCF_Tab_OnClick(ChatFrame4Tab,'LeftButton')
check(SELECTED_CHAT_FRAME==ChatFrame5,'click unavailable tab advances to valid tab')
check(box:GetText()=='mouse draft' and box:HasFocus(),'click keeps input usable')
ChatFrameUtil.OpenChat('',ChatFrame4)
check(SELECTED_CHAT_FRAME~=ChatFrame4,'open unavailable tab selects valid destination')
check(ChatFrame4.editBox:HasFocus(),'open unavailable tab keeps focused editor')
for _,id in ipairs(A.db.order) do A.db.windows[id].route='PARTY' end
ChatFrameUtil.ActivateChat(box)
box:SetText('no available destinations')
SELECTED_CHAT_FRAME=ChatFrame1
local kind=box:GetChatType()
box:RunScript('OnTabPressed')
check(SELECTED_CHAT_FRAME==ChatFrame1,'all unavailable leaves selected window unchanged')
check(box:GetText()=='no available destinations' and box:HasFocus(),'all unavailable preserves input')
check(box:GetChatType()==kind,'all unavailable does not invent destination')
-- The restored checkbox must control routing independently of the master.
A.db.skipUnavailable=false
A.db.windows[1].route='SAY'
A.db.windows[4].route='INCOMING'
A.db.windows[3].route='PARTY'
A.db.windows[5].route='GUILD'
A.incoming=nil
state.group=false
ChatFrameUtil.ActivateChat(box)
box:SetText('unsent private draft')
box:SetCursorPosition(3)
SELECTED_CHAT_FRAME=ChatFrame1
for _,id in ipairs({4,3,5,1}) do
 box:RunScript('OnTabPressed')
 check(SELECTED_CHAT_FRAME:GetID()==id,'skip=false visits every configured tab')
 check(box:HasFocus() and box:IsShown(),'unavailable tab retains focus')
 check(box:GetText()=='unsent private draft' and box:GetCursorPosition()==3,'unavailable tab retains draft')
 if id==4 then
  check(box:GetChatType()=='WHISPER' and box:GetTellTarget()=='','missing recipient clears old recipient')
 elseif id==3 then
  check(box:GetChatType()=='PARTY' and box:GetTellTarget()==nil,'ungrouped party keeps native party channel')
 end
end
state.shift=true
box:RunScript('OnTabPressed')
check(SELECTED_CHAT_FRAME==ChatFrame5,'reverse still works with skip disabled')
state.shift=false
A.ToggleOptions()
if not TabTalkOptions:IsShown() then A.ToggleOptions() end
local skip=TabTalkOptions.skip
local master=TabTalkOptions.enabled
skip:SetChecked(true)
skip:RunScript('OnClick')
check(A.db.skipUnavailable and A.db.enabled,'skip switch does not disable addon')
master:SetChecked(false)
master:RunScript('OnClick')
check(not A.db.enabled and A.db.skipUnavailable,'master independent of skip switch')
master:SetChecked(true)
master:RunScript('OnClick')
TEST_CHECKS=TEST_CHECKS+count

-- Headers must be laid out entirely by the native implementation.
A.db.skipUnavailable=false
local oldHeader=box.header
local oldUpdate=box.UpdateHeader
local nativeHeader=false
box.UpdateHeader=function(self) nativeHeader=true; oldUpdate(self); nativeHeader=false end
box.header={SetText=function() assert(nativeHeader,'addon must not overwrite native header') end}
for _,route in ipairs({'PARTY','GROUP','RAID','RAID_WARNING','GUILD','OFFICER','INSTANCE_CHAT','INCOMING'}) do
 A.db.windows[3].route=route
 state.group,state.raid,state.guild=false,false,false
 A.RouteBox(box,3)
 local expected=route=='GROUP' and 'PARTY' or route=='INCOMING' and 'WHISPER' or route
 assert(box:GetChatType()==expected,'unavailable route retains native channel: '..route)
 assert(box:HasFocus() and box:GetText()=='unsent private draft','routing preserves input')
 TEST_CHECKS=TEST_CHECKS+2
end
box.header=oldHeader
box.UpdateHeader=oldUpdate
