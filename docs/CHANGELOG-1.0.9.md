# TabTalk 1.0.9 — Forever 1.60.1

- Added a native gamepad focus path, avoiding restoration of focus to the previous chat editor. Keyboard/mouse behavior retains its existing path.
- Added Combat Log as a separately configurable window in the Tab cycle.
- Restored independent master-enable and skip-unavailable options.
- Improved mouse-tab routing and input handling for unavailable destinations.
- New profiles default to Chinese, with a Chinese / EN language selector, all windows included and skipping disabled. Existing settings are preserved.

Validation: 661 Lua 5.1 mock assertions pass. The Steam Deck security-popup and ABXY changes still require in-game confirmation; mock checks do not validate Blizzard taint behavior. Fully restart the game after upgrading.

## 中文

新增原生手柄焦点切换路径，保留电脑键鼠逻辑；战斗记录可独立配置；恢复独立总开关和自动跳过选项；改进鼠标切换和不可用目标处理。新配置默认中文、所有窗口参与切换，语言入口标注 中文 / EN。保留已有角色设置。

661 项模拟检查通过，Steam Deck 弹窗和 ABXY 修正仍待实机确认。升级后请完全重启游戏。
