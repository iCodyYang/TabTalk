# 1.0.9 原生手柄焦点分支

依据 SD 实机 taint-second-repro.log：Cycle 主动 FCF_Tab_OnClick 写入原生选择全局并在 IM 模式下恢复旧编辑框，后续进入手柄绑定栈和 SetPreferredGamepadInteractTarget 拦截。

新增 InputUtil.IsGamepadUIEnabled 分支：不调用 FCF_Tab_OnClick/ActivateChat，而显示目标窗口后调用目标原生 SetGamepadFocus（内部进入已由暴雪注册包装的 FrameShown）。由原生 FocusGamepad 选择窗口、激活目标编辑框、管理页脚与 ABXY。插件只转移草稿/光标并设置发送路由，不写原生焦点全局、不调用手柄绑定内部函数、不新注册安全包装、不绕过限制。实际 Combat addon restriction 拒绝时不调用该入口；不以普通 combat 状态一律禁用。

鼠标在手柄模式同样交原生入口。后置观察 FCFDock_SelectWindow，支持原生手柄前后标签按键；纯键鼠分支保留1.0.8逻辑。

661项模拟检查通过，其中新增手柄专用35项，覆盖正反循环、战斗记录、草稿转移、实际限制、普通战斗、原生dock路由及鼠标选取；测试在手柄分支若进入旧 FCF_Tab_OnClick 或插件 ActivateChat 路径直接失败。模拟不实现暴雪安全引擎，SD实机弹窗、ABXY返回仍待用户测试。Mac/Windows分支回归通过不等于Windows实机验收。

原生依据：
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_GamepadSharedUtility/FrameControlsManager.lua
https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua
