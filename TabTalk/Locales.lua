local _, A = ...
-- One bilingual package; stable saved route keys are independent of display language.
local english = {
    ["战斗记录显示战斗事件，不是发送频道；默认保持当前输入频道，也可在这里另设发送目标。"] = "Combat Log displays combat events, not an outgoing channel. It keeps the current input channel by default; you can assign a destination here.",
    ["保持原生频道"] = "Keep native channel",
    ["说话"] = "Say",
    ["大喊"] = "Yell",
    ["表情动作"] = "Emote",
    ["小队"] = "Party",
    ["团队"] = "Raid",
    ["小队 / 团队（自动）"] = "Party / Raid (automatic)",
    ["副本 / 战场"] = "Instance / Battleground",
    ["团队警告"] = "Raid warning",
    ["公会"] = "Guild",
    ["公会官员"] = "Guild officers",
    ["私聊：最后给我发消息的人"] = "Whisper: last incoming sender",
    ["私聊：最近交谈的人（收 / 发）"] = "Whisper: most recent conversation",
    ["私聊：固定玩家"] = "Whisper: specific player",
    ["私聊：当前选中的玩家"] = "Whisper: current target",
    ["公共 / 自定义频道"] = "Public / custom channel",
    ["尚未加入小队"] = "Not in a party",
    ["尚未加入团队"] = "Not in a raid",
    ["需要团长或助理权限"] = "Raid leader or assistant required",
    ["尚未加入副本 / 战场队伍"] = "Not in an instance group",
    ["尚未加入公会"] = "Not in a guild",
    ["没有官员频道发言权限"] = "Officer chat permission required",
    ["本次登录还没有可回复的私聊"] = "No whisper contact this session",
    ["尚未指定玩家"] = "No player selected",
    ["请填写角色名，跨服用 名字-服务器"] = "Enter a character name or Name-Realm",
    ["尚未加入所选频道"] = "Not in the selected channel",
    ["请选择发送目标"] = "Choose a destination",
    ["此客户端不支持该频道"] = "Channel unsupported by this client",
    ["滚轮查看更多 · 再点选择框收起"] = "Scroll for more; click selector to close",
    ["私聊 · 最后来信"] = "Whisper: last sender",
    ["私聊 · 最近交谈"] = "Whisper: recent",
    ["私聊 · 固定玩家"] = "Whisper: player",
    ["私聊 · 当前目标"] = "Whisper: target",
    ["小队 / 团队"] = "Party / Raid",
    ["不参与 Tab 切换"] = "Excluded from Tab cycle",
    ["选择已加入的频道"] = "Choose a joined channel",
    ["|cff86d3ad当前可用|r"] = "|cff86d3adAvailable now|r",
    ["只跟随收到的私聊；你主动密别人不会改变此目标。角色私聊和战网私聊都可记录。"] = "Uses the last incoming whisper. Whispering someone else does not change this target. Supports character and Battle.net whispers.",
    ["跟随最近一次收到或发出的私聊。刷新界面 / 重新登录后重新记录。"] = "Uses the last incoming or outgoing whisper. Contacts are cleared when you reload or log out.",
    ["按频道名称保存，发言时重新查找编号。退出频道时会跳过，不会误发到同编号的其他频道。"] = "Saved by channel name, not number. If you leave the channel, it is unavailable; its old number is never reused by mistake.",
    ["使用游戏原本的输入频道；本窗口仍可参与 Tab 循环。"] = "Keeps the native input channel. This window can still be included in the Tab cycle.",
    ["切换到这个窗口后，输入框使用上面指定的发送目标。窗口显示哪些消息，仍由魔兽原生聊天设置管理。"] = "Selecting this window sets the input destination above. Message visibility is still controlled by the native chat settings.",
    ["字号"] = "Font",
    ["回车后 Tab → 下一个窗口    Shift + Tab → 上一个窗口"] = "Press Enter, then Tab: next window   /   Shift + Tab: previous",
    ["启用"] = "Enable",
    ["显示小地图图标"] = "Minimap icon",
    ["鼠标点窗口时也切频道"] = "Route on mouse selection",
    ["自动跳过不可用目标"] = "Automatically skip unavailable destinations",
    ["启用 TabTalk"] = "Enable TabTalk",
    ["目标不可用"] = "Destination unavailable",
    ["Tab 跳过当前不可用的目标（未组队、尚无私聊等）"] = "Skip unavailable destinations (no group, no whisper contact, etc.)",
    ["已有聊天窗口 · 按下列顺序循环"] = "Chat windows / cycle order",
    ["上移"] = "Up",
    ["下移"] = "Down",
    ["刷新"] = "Refresh",
    ["参与 Tab 循环"] = "Include in Tab cycle",
    ["这个窗口的默认发送目标"] = "Default outgoing destination",
    ["角色名（跨服可填写 名字-服务器）"] = "Character name (Name-Realm for cross-realm)",
    ["公共 / 自定义频道（仅列出已加入的频道）"] = "Public / custom channel (joined channels only)",
    ["|cffffc773请先在游戏中加入频道，再回来选择。|r"] = "|cffffc773Join a channel in game, then select it here.|r",
    ["面板大小"] = "Panel size",
    ["缩小"] = "Smaller",
    ["放大"] = "Larger",
    ["恢复大小"] = "Reset size",
    ["设置自动保存到当前角色 · /tabtalk 打开设置 · "] = "Saved per character / Open settings: /tabtalk / ",
    ["左键：设置\n输入时右键：下一个窗口\nShift + 右键：上一个窗口\n拖动：移动图标"] = "Left-click: settings\nRight-click while typing: next window\nShift + right-click: previous window\nDrag: move icon",
    ["语言：自动"] = "Language: Auto",
    ["语言：中文"] = "Language: Chinese",
    ["语言：English"] = "Language: English",
}
local originals = {}
for key, value in pairs(english) do originals[value] = key end
function A.Locale()
    local mode = A.db and A.db.language or "zhCN"
    if mode == "zhCN" or mode == "enUS" then return mode end
    local locale = GetLocale and GetLocale() or "enUS"
    return (locale == "zhCN" or locale == "zhTW") and "zhCN" or "enUS"
end
function A.T(key)
    if A.Locale() == "zhCN" then return key end
    return english[key] or key
end
function A.LocaleKey(value)
    if english[value] then return value end
    return originals[value]
end
function A.UpdateRouteLabels()
    if not A.routes then return end
    for _, route in ipairs(A.routes) do
        local key = A.LocaleKey(route[2]) or route[2]
        route[2] = A.T(key)
        A.labels[route[1]] = route[2]
    end
end
function A.FontPath()
    if A.Locale() == "zhCN" and GetLocale and GetLocale() ~= "zhCN" and GetLocale() ~= "zhTW" then
        return "Fonts\\ARKai_T.ttf"
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end
A.localeStrings = english
