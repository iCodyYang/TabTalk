local A = TEST_ADDON
local n = 0
local function check(value, name) assert(value, name) n = n + 1 end
local route = A.db.windows[3].route
local order = table.concat(A.db.order, ",")
local fontScale = A.db.fontScale
A.SetLanguage("enUS")
check(A.Locale() == "enUS", "explicit English")
check(A.labels.PARTY == "Party", "route label translated")
check(A.labels.INCOMING == "Whisper: last incoming sender", "incoming description translated")
check(A.db.windows[3].route == route, "language change preserves saved route key")
check(table.concat(A.db.order, ",") == order, "language change preserves cycle order")
check(A.db.fontScale == fontScale, "language change preserves font preference")
local _, reason = A.Resolve({route = "PARTY"}, {group = false})
check(reason == "Not in a party", "validation reason translated")
check(TabTalkOptions.enabled.caption:GetText() == "Enable", "existing checkbox text updated live")
check(TabTalkOptions.recipientLabel:GetText() == "Character name (Name-Realm for cross-realm)", "recipient label updated")
check(TabTalkOptions.language:GetText() == "Language: English", "language picker caption")
check(TabTalkOptions.footer:GetText():find("Saved per character", 1, true), "footer translated")
check(TabTalkOptions.footer:GetText():find("1.0.0", 1, true), "stable version in footer")
for key, value in pairs(A.localeStrings) do
    check(value ~= "" and not value:find("[\228-\233]"), "English translation exists: " .. key)
    check(A.T(key) == value, "English lookup: " .. key)
end
TEST_LOCALE = "enUS"
A.SetLanguage("auto")
check(A.Locale() == "enUS" and A.labels.GUILD == "Guild", "English client auto")
TEST_LOCALE = "deDE"
A.SetLanguage("auto")
check(A.Locale() == "enUS", "other client falls back to English")
A.SetLanguage("zhCN")
check(A.FontPath() == "Fonts\\ARKai_T.ttf", "Chinese override selects CJK font")
check(A.labels.PARTY == "小队", "Chinese routes restored")
check(TabTalkOptions.enabled.caption:GetText() == "启用", "Chinese static labels restored")
TEST_LOCALE = "zhCN"
A.SetLanguage("auto")
check(A.Locale() == "zhCN", "Chinese client auto")
check(A.db.windows[3].route == route, "round trip preserves config")
local db = A.NewDB()
local existingDB = A.db
db.language = nil
db.windows[1] = {name = "Example", enabled = true, route = "GUILD", target = ""}
A.InitDB(db)
check(db.language == "auto", "existing profiles get language default")
check(db.windows[1].route == "GUILD", "profile migration preserves destination")
A.InitDB(existingDB)
TEST_CHECKS = TEST_CHECKS + n
