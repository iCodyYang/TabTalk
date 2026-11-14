local _, A = ...
A.VERSION = "1.0.0"
A.routes = {
    {"KEEP", A.T("保持原生频道")}, {"SAY", A.T("说话")}, {"YELL", A.T("大喊")},
    {"EMOTE", A.T("表情动作")}, {"PARTY", A.T("小队")}, {"RAID", A.T("团队")},
    {"GROUP", A.T("小队 / 团队（自动）")}, {"INSTANCE_CHAT", A.T("副本 / 战场")},
    {"RAID_WARNING", A.T("团队警告")}, {"GUILD", A.T("公会")}, {"OFFICER", A.T("公会官员")},
    {"INCOMING", A.T("私聊：最后给我发消息的人")},
    {"RECENT", A.T("私聊：最近交谈的人（收 / 发）")},
    {"FIXED", A.T("私聊：固定玩家")}, {"TARGET", A.T("私聊：当前选中的玩家")},
    {"CHANNEL", A.T("公共 / 自定义频道")},
}
A.labels = {}
for _, route in ipairs(A.routes) do A.labels[route[1]] = route[2] end

function A.NewDB()
    return {version = 1, enabled = true, skipUnavailable = true,
        clickRouting = true, minimap = true, angle = 220, uiScale = 1, fontScale = 1, language = "auto",
        windows = {}, order = {}}
end

function A.InitDB(db)
    if type(db) ~= "table" then db = A.NewDB() end
    local defaults = A.NewDB()
    for key, value in pairs(defaults) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    A.db = db
    A.UpdateRouteLabels()
    return db
end

-- Stable window IDs; reject stale bindings when a slot is reused after closing.
function A.SyncWindows(windows)
    local active, order = {}, {}
    for _, window in ipairs(windows) do
        local id = window.id
        active[id] = true
        local config = A.db.windows[id]
        if type(config) ~= "table" or config.name ~= window.name then
            config = {name = window.name, enabled = true, route = "KEEP", target = ""}
            A.db.windows[id] = config
        end
        if not A.labels[config.route] then config.route = "KEEP" end
        if type(config.target) ~= "string" then config.target = "" end
    end
    local seen = {}
    for _, id in ipairs(A.db.order) do
        if active[id] and not seen[id] then order[#order + 1], seen[id] = id, true end
    end
    for _, window in ipairs(windows) do
        if not seen[window.id] then order[#order + 1] = window.id end
    end
    -- Inactive windows cannot retain private recipients and later reuse a slot.
    for id in pairs(A.db.windows) do
        if not active[id] then A.db.windows[id] = nil end
    end
    A.db.order = order
end

function A.RecordWhisper(target, kind, incoming)
    if issecretvalue and (issecretvalue(target) or issecretvalue(kind)) then return end
    if type(target) ~= "string" or target == "" then return end
    if kind ~= "WHISPER" and kind ~= "BN_WHISPER" then return end
    A.recent = {target = target, kind = kind}
    if incoming then A.incoming = A.recent end
end

-- env is a tiny adapter to live client APIs; no message bodies or timers.
function A.Resolve(config, env)
    local route, target = config.route, config.target
    if route == "KEEP" then return {kind = "KEEP"} end
    if route == "GROUP" then route = env.raid and "RAID" or "PARTY" end
    if route == "PARTY" and not env.group then return nil, A.T("尚未加入小队") end
    if (route == "RAID" or route == "RAID_WARNING") and not env.raid then
        return nil, A.T("尚未加入团队")
    end
    if route == "RAID_WARNING" and not env.raidOfficer then return nil, A.T("需要团长或助理权限") end
    if route == "INSTANCE_CHAT" and not env.instance then return nil, A.T("尚未加入副本 / 战场队伍") end
    if (route == "GUILD" or route == "OFFICER") and not env.guild then return nil, A.T("尚未加入公会") end
    if route == "OFFICER" and env.officer == false then return nil, A.T("没有官员频道发言权限") end
    if route == "INCOMING" or route == "RECENT" then
        local person
        if route == "INCOMING" then person = A.incoming else person = A.recent end
        if not person then return nil, A.T("本次登录还没有可回复的私聊") end
        return {kind = person.kind, target = person.target}
    end
    if route == "FIXED" or route == "TARGET" then
        target = route == "TARGET" and env.playerTarget or target
        if type(target) ~= "string" or target == "" then return nil, A.T("尚未指定玩家") end
        if target:find("[%s/|]") then return nil, A.T("请填写角色名，跨服用 名字-服务器") end
        return {kind = "WHISPER", target = target}
    end
    if route == "CHANNEL" then
        local id = target and target ~= "" and env.channel(target)
        if not id or id <= 0 then return nil, A.T("尚未加入所选频道") end
        return {kind = "CHANNEL", channel = id}
    end
    if not A.labels[route] then return nil, A.T("请选择发送目标") end
    if env.supported and not env.supported(route) then return nil, A.T("此客户端不支持该频道") end
    return {kind = route}
end

function A.NextWindow(current, direction, usable)
    local order, start = A.db.order, nil
    for i, id in ipairs(order) do if id == current then start = i break end end
    if not start then start = direction > 0 and 0 or 1 end
    for offset = 1, #order do
        local index = ((start - 1 + offset * direction) % #order) + 1
        local id = order[index]
        local config = A.db.windows[id]
        if config and config.enabled and (not A.db.skipUnavailable or usable(config)) then
            return id
        end
    end
end
