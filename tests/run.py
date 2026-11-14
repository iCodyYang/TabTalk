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
# The installed widget handler must work even if the global extension is absent.
lua.execute((ROOT / "tests/test_regressions.lua").read_text())
lua.execute((ROOT / "tests/test_locales.lua").read_text())
upstream_checked = False
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
    "lua": "5.1", "assertions": lua.globals().TEST_CHECKS,
    "direct_widget_tab_dispatch": True,
    "core_100000_iterations_seconds": round(duration, 4),
    "note": "Mock tests only. In-game frame timing, memory, security/taint, IME and UI rendering unverified."
}
print(json.dumps(result, ensure_ascii=False, indent=2))
(ROOT / "docs/test-results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
