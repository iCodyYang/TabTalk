"""Run with Python + lupa's Lua 5.1 engine. No WoW process or account required."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import json
import time

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in sorted((ROOT / "TabTalk").glob("*.lua")):
    lua.execute("assert(loadstring(...))", path.read_text())
lua.execute((ROOT / "tests/mock_wow.lua").read_text())
namespace = lua.table()
lua.globals().TEST_ADDON = namespace
for filename in ("Locales.lua", "Core.lua", "Main.lua", "Options.lua"):
    lua.execute((ROOT / "TabTalk" / filename).read_text(), "TabTalk", namespace)
lua.execute((ROOT / "tests/test_addon.lua").read_text())
# Exercise the native secure Tab extension without replacing widget handlers.
lua.execute((ROOT / "tests/test_regressions.lua").read_text())
lua.execute((ROOT / "tests/test_locales.lua").read_text())
lua.execute((ROOT / "tests/test_security_regressions.lua").read_text())
lua.execute((ROOT / "tests/test_unavailable.lua").read_text())
lua.execute((ROOT / "tests/test_mouse.lua").read_text())
lua.execute((ROOT / "tests/test_gamepad.lua").read_text())
# Fresh-login capability fallback: no EventRegistry dependency and no unsafe
# widget-script fallback when the native Tab extension is missing.
capability_checks = 0
for missing_tab in (False, True):
    probe = LuaRuntime(unpack_returned_tuples=True)
    probe.execute((ROOT / "tests/mock_wow.lua").read_text())
    probe.execute("EventRegistry = nil")
    if missing_tab:
        probe.execute("ChatEdit_CustomTabPressed = nil")
    probe_ns = probe.table()
    probe.globals().TEST_ADDON = probe_ns
    for filename in ("Locales.lua", "Core.lua", "Main.lua", "Options.lua"):
        probe.execute((ROOT / "TabTalk" / filename).read_text(), "TabTalk", probe_ns)
    probe.execute('''for _, f in ipairs(objects) do
        if f.events.PLAYER_LOGIN then f:RunScript("OnEvent", "PLAYER_LOGIN") break end
    end
    assert(ChatFrame1.editBox:GetScript("OnEnterPressed") == ChatFrame1.editBox.nativeEnter)
    assert(ChatFrame1.editBox:GetScript("OnTabPressed") == ChatFrame1.editBox.nativeTab)
    ''')
    capability_checks += 2
    if missing_tab:
        probe.execute('''assert(ChatEdit_CustomTabPressed == nil)
        ChatFrameUtil.ActivateChat(ChatFrame1.editBox)
        assert(TEST_ADDON.Cycle(1, ChatFrame1.editBox) == false)''')
        capability_checks += 2

# Core-only stress test. These numbers are not in-game CPU or addon memory.
lua.execute('''
    function bench(n)
        local A = TEST_ADDON
        local env = A.Environment()
        for i = 1, n do
            A.NextWindow(1, 1, function(config) return A.Resolve(config, env) end)
        end
    end
    collectgarbage("collect")
''')
start = time.perf_counter()
lua.globals().bench(100000)
duration = time.perf_counter() - start
result = {
    "lua": "5.1", "assertions": lua.globals().TEST_CHECKS + capability_checks,
    "native_scripts_preserved": True,
    "native_secure_tab_extension": True,
    "core_100000_iterations_seconds": round(duration, 4),
    "note": "Mock tests only. In-game frame timing, memory, security/taint, IME and UI rendering unverified."
}
print(json.dumps(result, ensure_ascii=False, indent=2))
(ROOT / "docs/test-results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
