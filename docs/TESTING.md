# Forever 首版验收

## 自动测试范围

`tests/run.py` 使用 Lua 5.1 编译全部插件源文件，再执行模拟游戏接口下的路由与 UI 创建断言。
`test-results.json` 是本次实际运行结果。压力测试只测核心函数，不能当作游戏内帧率 / CPU 或内存数据。
测试期间不启动游戏、不发送聊天消息、不修改用户设置、不安装其他插件。

覆盖：前后循环与回绕、排除战斗日志、默认不猜频道、严格最后来信与最近交谈区别、战网类型、秘密值保护、队伍 / 公会 / 团警条件、退出频道和频道重编号、固定 / 当前目标私聊、中文和物品链接与光标保留、不可用目标阻止误发、手动改频道、斜杠补全、IME 状态、禁用插件、受保护输入框、IM 模式失焦、原生 R / Shift-R / 战网私聊、关闭窗口再建、改名、懒创建设置面板、无插件 OnUpdate。

## 游戏中仍需完成（未验收）

1. 只启用本插件及必要插件，创建“小队”“私聊”“公会”三个原生聊天标签。用 `/tabtalk` 绑定目标。
2. 回车，Tab 连续循环并回绕，Shift + Tab 反向；确认选中的标签和原生输入框频道一致。
3. 输入中文和一条物品链接，在文字中间放光标，切换标签，确认内容、链接、光标和焦点保留。用中文输入法未上屏拼音再按 Tab，确认候选行为正常。
4. 让 A 私聊你，主动密 B；“最后给我发消息的人”应仍为 A，“最近交谈”应为 B。战网联系人同样验证。仅在确认收件人后手动发送测试内容。
5. 尚无私聊来信、退出小队、公会或公共频道时验证跳过；关闭跳过，再按回车确认不会误发到原频道。鼠标切到失效窗口也验证。
6. 测试 R、Shift-R、右键玩家私聊、物品链接输入、`/p`、`/g`、`/w` 和 `/r` 的优先级。
7. 进入和离开团队、跨区域综合频道改名、公共频道编号变化后确认路由。权限不足的官员 / 团队警告应遵从游戏规则。
8. 拖动 / 隐藏 / 恢复小地图图标；调整顺序、重命名、关闭再建窗口，重载 UI，切换角色，验证设置隔离。
9. 打开 Lua 错误记录，分别在战斗内外重复操作；确认没有受保护操作 / taint 报错。存在游戏限制时记录具体客户端版本和堆栈。
10. 原生聊天 classic / im 两种模式，以及独立未停靠窗口、临时私聊窗口分别检查。
11. 再逐个启用用户现有聊天插件，确认谁接管 Tab。若后加载插件覆盖同一个扩展点，需单独处理兼容。
12. 使用游戏自身的插件性能统计测量：空闲 60 秒、连续切换 100 次、打开 / 关闭设置后分别记录内存及 CPU。不要以模拟器数值代替游戏测量。

## 接口依据

2026-11-14 核查了本机已有插件 TOC 的 `16001` 标记，以及 Gethe 的 Forever 分支界面源码。
实现独立编写，没有打包第三方插件、库或 Blizzard 源码。

- [ChatFrameEditBox.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua)：原生 Tab 扩展点和输入框属性。
- [ChatFrameUtil.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua)：输入焦点和最近私聊目标接口。
- [FloatingChatFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua)：原生窗口选择和命名流程。
- [GuildInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua)：公会接口，编辑备注权限不等于官员聊天发言权限。

## 0.1.1 回归

实际输入框脚本触发 Tab / Shift-Tab（全局扩展删除）、不重复执行、数字 0 的 IME 标志、斜杠 / 补全委托、输入框焦点回退、圆形图标蒙版和原生边框、字体边界、字号与面板独立缩放、小屏适配。当前仍是模拟器验证，需用户游戏内重新载入确认。
