local A=TEST_ADDON
local function check(v,msg) assert(v,msg); TEST_CHECKS=TEST_CHECKS+1 end
local function unfocus()
 for i=1,5 do _G['ChatFrame'..i].editBox:ClearFocus() end
 ACTIVE_CHAT_EDIT_BOX=nil
end
A.db.enabled=true
A.db.clickRouting=true
A.db.skipUnavailable=false
A.db.windows[3].route='PARTY'
A.db.windows[4].route='INCOMING'
A.incoming={kind='WHISPER',target='Alice'}
state.group=false
for _,im in ipairs({false,true}) do
 state.imStyle=im
 for _,id in ipairs({3,4}) do
  unfocus()
  local box=_G['ChatFrame'..id].editBox
  box:SetText('mouse draft'); box:SetCursorPosition(2); box:Hide()
  FCF_Tab_OnClick(_G['ChatFrame'..id..'Tab'],'LeftButton')
  check(box:HasFocus() and box:IsShown(),'click opens unfocused input')
  check(box:GetChatType()==(id==3 and 'PARTY' or 'WHISPER'),'click applies route')
  check(box:GetText()=='mouse draft' and box:GetCursorPosition()==2,'activation keeps draft')
  if id==4 then check(box:GetTellTarget()=='Alice','click picks whisper recipient') end
 end
end
state.imStyle=false
unfocus()
A.db.clickRouting=false
FCF_Tab_OnClick(ChatFrame3Tab,'LeftButton')
check(not ChatFrame3.editBox:HasFocus(),'disabled mouse routing leaves focus native')
A.db.clickRouting=true
FCF_Tab_OnClick(ChatFrame3Tab,'RightButton')
check(not ChatFrame3.editBox:HasFocus(),'right click does not activate input')
ChatFrame3.editBox:SetText('')
ChatFrame3.editBox.protected=true
state.combat=true
FCF_Tab_OnClick(ChatFrame3Tab,'LeftButton')
check(not ChatFrame3.editBox:HasFocus(),'protected editor not activated in combat')
ChatFrame3.editBox.protected=false
state.combat=false
