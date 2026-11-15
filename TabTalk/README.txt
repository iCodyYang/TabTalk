TabTalk 1.0.9 — World of Warcraft: Forever (Interface 16001)

Install this TabTalk folder in _forever_/Interface/AddOns/.
Open settings with the minimap button, /tabtalk, or /ttalk.
Assign outgoing destinations to your existing chat windows.
Press Enter, then Tab / Shift+Tab to cycle forward / backward.

New profiles default to Chinese. Use the Chinese / EN
selector at the bottom right of settings to choose EN / English or Auto.
Existing per-character settings are preserved when upgrading.

No external libraries, idle polling, saved message bodies or automatic sends.
See the included Chinese instructions for additional usage details.
Copyright (c) 2026 Cody. Licensed under the MIT License; see LICENSE.txt.

1.0.9: separate top-level Enable TabTalk and skip-unavailable checkboxes.
With skipping off, unavailable tabs remain in the cycle without closing the editor.
Unavailable group destinations keep their native channel type. Missing whisper
recipients clear the old target. Only native headers are shown; the game
validates sending and may reject it if the destination is unavailable.
Ordinary combat remains supported; actual chat restrictions are respected.
Restart after updating. In-game verification remains pending.

1.0.9: Native input headers only; unjoined group channels retain their channel type.
No recipient means an empty whisper target. The game validates sending.

Mouse routing now activates an unfocused editor and applies the configured destination. Disable click routing to retain native tab behavior.

1.0.9: Combat Log has its own configurable entry in the cycle. New profiles
include all windows and disable skipping unavailable destinations by default.
Existing character preferences are preserved.

1.0.9: Gamepad mode delegates window selection and focus to the native gamepad manager; keyboard/mouse mode retains its existing path. Device verification is still required.
