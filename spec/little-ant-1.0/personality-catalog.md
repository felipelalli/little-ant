# Factory personality catalog

This file is the normative English catalog for UX-064. Each ID denotes one
logical phrase. A renderer may wrap it into one or two lines without changing
the words. The leading or trailing emoji are declared decoration and disappear
under `emoji_mode = never`; punctuation and wording remain.

These lines appear only on the result transitions named by their intent. They
never appear on a question, warning, error, evidence review, external-effect
approval, or scheduled-commitment screen.

## `focus_started`

| ID | Canonical English phrase |
|---|---|
| `focus_started.01` | 💪 Nice! Roll up your sleeves and give it a go. Come back when you're done—or when something gets in the way. 😌 |
| `focus_started.02` | 🐜 One Brick at a time. Let's put this one in place. |
| `focus_started.03` | 🚀 All right—this is the one. Give it a good run. |
| `focus_started.04` | 🔧 Tools out. See what you can move. |
| `focus_started.05` | 🌱 Small progress still counts. Start where you are. |
| `focus_started.06` | 🎯 Target chosen. Keep the first move simple. |
| `focus_started.07` | 🧭 Direction chosen. Time to explore the path. |
| `focus_started.08` | 🛠️ Let's make a dent in this one. |
| `focus_started.09` | ☕ Settle in and give this Brick some attention. |
| `focus_started.10` | 🎵 One loose end, meet some focused attention. |
| `focus_started.11` | ✨ A little focus can do a lot. Have at it. |
| `focus_started.12` | 🐾 One useful step is enough to begin. |
| `focus_started.13` | 🧱 This is the Brick for now. |
| `focus_started.14` | 🌤️ Clear enough to begin. See where it leads. |
| `focus_started.15` | 🧠 Brain on, noise down. Give it a try. |
| `focus_started.16` | 🏁 You're set. Start with the smallest useful move. |

## `work_completed`

| ID | Canonical English phrase |
|---|---|
| `work_completed.01` | 🎉 Nice work. That Brick is in place. |
| `work_completed.02` | ✅ Done and dusted. |
| `work_completed.03` | 🧱 One more Brick settled. |
| `work_completed.04` | 🌟 That moved things forward. |
| `work_completed.05` | 🐜 Tiny ant, solid progress. |
| `work_completed.06` | 🧹 One less loose end. |
| `work_completed.07` | 🎯 Right on target. |
| `work_completed.08` | 🌱 Progress made. Nicely done. |
| `work_completed.09` | 🛠️ Good work—that piece holds. |
| `work_completed.10` | ✨ Finished. Enjoy the clean edge. |
| `work_completed.11` | 📦 Wrapped up and recorded. |
| `work_completed.12` | 🥁 And that's a wrap. |
| `work_completed.13` | 🏁 Across the line. |
| `work_completed.14` | ☑️ Complete. Simple as that. |
| `work_completed.15` | 🌤️ That clears a little space. |
| `work_completed.16` | 🙌 Nicely handled. |

## `skip_acknowledged`

| ID | Canonical English phrase |
|---|---|
| `skip_acknowledged.01` | 🐜 Even ants reroute sometimes. |
| `skip_acknowledged.02` | 🧭 Noted. Let's try another direction. |
| `skip_acknowledged.03` | 🌿 Fair enough. Give this one some room. |
| `skip_acknowledged.04` | 🎈 Released for now. |
| `skip_acknowledged.05` | 🪵 No need to force this one. |
| `skip_acknowledged.06` | 🔄 Course adjusted. |
| `skip_acknowledged.07` | 🧩 Useful signal. We'll work with it. |
| `skip_acknowledged.08` | 🐾 Step around it for now. |
| `skip_acknowledged.09` | 🌦️ Conditions change. So can the route. |
| `skip_acknowledged.10` | 🧰 A different tool may help later. |
| `skip_acknowledged.11` | 🛤️ Detour accepted. |
| `skip_acknowledged.12` | 🌙 This one can rest for now. |
| `skip_acknowledged.13` | 📍 Noted. Revisit it with better footing. |
| `skip_acknowledged.14` | 🧱 Leave this Brick here; another can move. |
| `skip_acknowledged.15` | 🍃 No pushing. The route can change. |
| `skip_acknowledged.16` | 🪶 Light touch: this one waits. |

## `safe_end`

| ID | Canonical English phrase |
|---|---|
| `safe_end.01` | 🌿 Rest a little. The rock will still be here. |
| `safe_end.02` | 🐜 The ant is off duty. The Bricks can wait. |
| `safe_end.03` | 🌙 Good stopping point. See you next time. |
| `safe_end.04` | ☕ Break accepted. Come back when it suits you. |
| `safe_end.05` | 📌 Your place is saved. |
| `safe_end.06` | 🪴 Let the thought settle. |
| `safe_end.07` | 🛟 Everything is safely parked. |
| `safe_end.08` | 🌤️ Step away. The trail will still be here. |
| `safe_end.09` | 🧺 Work tucked away for now. |
| `safe_end.10` | 💤 Quiet mode: on. |
| `safe_end.11` | 🚪 Safe to leave; nothing is slipping away. |
| `safe_end.12` | 🐾 Pause here. Pick up from the same trail later. |
| `safe_end.13` | 🎒 Packed up for now. |
| `safe_end.14` | 🪵 Set it down gently. |
| `safe_end.15` | 🧘 Enough for this round. |
| `safe_end.16` | 🌱 Rest is part of the work. |

## Validation

The factory build fails if an intent has other than 16 unique IDs, if an ID is
missing, or if a phrase exists outside this file. Snapshot fixtures render all
64 phrases with emoji on and off, at wide and narrow widths, and after ANSI is
stripped. Assisted paraphrases retain the selected ID in provenance but are
not added to this catalog or replayed as factory text.
