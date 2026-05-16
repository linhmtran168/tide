# 01 — Everforest theme for Tide

Date: 2026-05-15
Branch: `upgrade_and_refactor` (fork `linhmtran168/tide`)

## Context

User runs an Everforest-palette Starship prompt on their Mac (`~/mac_dotfiles/starship.toml`) and wants Tide on their fork to reproduce that look while keeping Tide's async rendering performance — including in large repos. The theme must be an additional, non-default preset; users keep stock Lean/Classic/Rainbow. Path substitutions (`~/Dev/github.com` → ` github`, etc.) are part of the deal.

Confirmed with the user:

- **Fork-only** — no need to keep changes upstreamable.
- Exposed **both** via the `tide configure` wizard and a direct `tide load-theme everforest` subcommand.
- Path substitutions **enabled with the Starship config's mappings seeded as defaults**.

## Approach

Build the theme on Tide's existing data-driven profile system. Profiles are bare `tide_*` assignments in `functions/tide/configure/configs/<name>.fish`, loaded by `_load_config <name>` (`functions/tide/configure/choices/all/style.fish:33-36`), which prefixes lines with `set -g fake_` for the wizard's preview flow. A finish step promotes `fake_tide_*` → `tide_*` universals (`functions/tide/configure/choices/all/finish.fish:25-37` — the `_tide_finish` function). Everforest slots in as a sibling of `lean.fish`/`classic.fish`/`rainbow.fish`.

Three small extensions to Tide's core unlock the parts stock items don't cover. Each is gated on an optional universal var that defaults to empty/unset — so existing themes and users are unaffected.

1. **`tide_pwd_substitutions`** — paired list `pattern1 replacement1 pattern2 replacement2 …`. Tiny patch to `_tide_pwd` applies the first prefix match (longest-prefix-first is the user's responsibility via ordering) against the post-`$HOME→~` path. Unset = zero behavioral change.
2. **`_tide_item_brand`** — static-text ornament. Renders only when `tide_brand_icon` is non-empty, so other themes don't have to opt out.
3. **`tide_git_status_extra_args`** — appended verbatim to the `git status --porcelain` call in `_tide_item_git`. Everforest seeds it with `--ignore-submodules=all` for monorepo speed. Tide's async rendering already keeps the visible prompt unblocked; this just cuts what the backgrounded `fish -c` actually does on `cd`.

`tide load-theme <name>` mirrors `_tide_finish`'s fake-var promotion loop directly (it's 4 lines), then runs `tide reload`. Same end state as choosing a style in the wizard.

## Files

### New

| Path | Purpose |
|---|---|
| `functions/tide/configure/configs/everforest.fish` | Theme data file: palette + glyphs + powerline shape + items list + seeded `tide_pwd_substitutions` + `tide_git_status_extra_args --ignore-submodules=all` + `tide_brand_icon ` |
| `functions/_tide_item_brand.fish` | `function _tide_item_brand; test -n "$tide_brand_icon" && _tide_print_item brand $tide_brand_icon; end` |
| `functions/_tide_sub_load-theme.fish` | New `tide load-theme <name>` subcommand. See pseudocode below. |
| `tests/_tide_item_brand.test.fish` | Littlecheck: no icon → empty output; icon set → glyph emitted (via `_tide_decolor`). |
| `tests/_tide_sub_load-theme.test.fish` | Littlecheck: unknown name → non-zero + stderr; known name → at least one expected `tide_*` universal landed. |

### Modified

| Path | Change |
|---|---|
| `functions/_tide_pwd.fish` | Inside the `eval "function _tide_pwd …"`, immediately after the existing `string replace -r '^$HOME' '~' -- $PWD` (line 10), insert a substitutions pass: iterate `$tide_pwd_substitutions` two-at-a-time, on exact match emit `<replacement>` as the lone anchored segment and `return`; on prefix match (`pattern/*`) replace just the prefix and set a `skip_pwd_icon` flag so the icon-prepending on lines 11-12 is bypassed. Deeper-segment unique-prefix truncation untouched. |
| `functions/_tide_item_git.fish` | On the `git $_set_dir_opt --no-optional-locks status --porcelain` line (~line 48), append `$tide_git_status_extra_args`. One change, no other refactor. |
| `functions/tide/configure/choices/all/style.fish` | Add `_tide_option 4 Everforest` to the menu (after line 8's existing options) and a `case Everforest` branch under the dispatch switch (around line 19+) that calls `_load_config everforest` then `_tide_display_prompt`. |
| `functions/tide.fish` | `_tide_help`: add the `load-theme` subcommand line. |
| `completions/tide.fish` | Add a `complete -c tide -n "__fish_use_subcommand"` entry for `load-theme` and `-n "__fish_seen_subcommand_from load-theme"` entries listing config names. |
| `CLAUDE.md` | Append "Themes" section: switch via `tide configure` or `tide load-theme <name>`; presets `lean classic rainbow everforest`; the three new knobs (`tide_pwd_substitutions`, `tide_git_status_extra_args`, `tide_brand_icon`). |
| `CHANGELOG.md` | New fork-specific entry under a "Fork changes" heading. |

### Not touched

- `functions/_tide_remove_unusable_items.fish` — `brand` isn't tool-dependent.
- `functions/fish_prompt.fish` — async/render path stays as-is.
- `functions/_tide_print_item.fish` — separator logic unchanged.

## Reused existing code / patterns

- **`_tide_print_item`** (`functions/_tide_print_item.fish:1-22`) for the brand item — same call pattern as every other item.
- **`_load_config`** (`functions/tide/configure/choices/all/style.fish:33-36`) — the new `tide load-theme` subcommand calls it directly. No need to reimplement; the `fake_` prefix mirror is exactly what we want.
- **`_tide_finish` promotion loop** (`functions/tide/configure/choices/all/finish.fish:30-32`):
  ```fish
  for fakeVar in (set --names | string match -r "^fake_tide.*")
      set -U (string replace 'fake_' '' $fakeVar) $$fakeVar
  end
  ```
  Inlined into `_tide_sub_load-theme` (the wizard sources the whole `finish.fish` via its choice-files glob; we don't want to drag the wizard machinery into a standalone subcommand).
- **Wizard option entry pattern** — copy the existing `_tide_option N <Label>` / `case <Label>` shape used for Lean/Classic/Rainbow in `style.fish:6-30`.
- **Rounded powerline glyphs** — same shapes as `classic.fish` (`tide_left_prompt_separator_diff_color = `, `tide_left_prompt_suffix = `, etc.). These are already what the screenshot shows.

## `_tide_sub_load-theme` pseudocode

```fish
function _tide_sub_load-theme -a name
    set -l configs_dir (dirname (status filename))/tide/configure/configs
    if not test -f $configs_dir/$name.fish
        printf 'Unknown theme: %s\nAvailable: ' $name >&2
        path basename $configs_dir/*.fish | string replace .fish '' | string join ' ' >&2
        echo >&2
        return 1
    end

    # Mirror _load_config (style.fish:33-36): source icons + theme as fake_ vars
    string replace -r '^' 'set -g fake_' $configs_dir/../icons.fish | source
    string replace -r '^' 'set -g fake_' $configs_dir/$name.fish | source

    # Mirror _tide_finish (finish.fish:30-32): promote fake_ → universal
    contains character $fake_tide_left_prompt_items || set -p fake_tide_left_prompt_items vi_mode
    for fakeVar in (set --names | string match -r "^fake_tide.*")
        set -U (string replace 'fake_' '' $fakeVar) $$fakeVar
        set -e $fakeVar
    end
    set -e $_tide_prompt_var 2>/dev/null

    tide reload
end
```

## Everforest palette → tide mapping (settled at write time)

Background segments (from `~/mac_dotfiles/starship.toml`):

| Starship segment | Tide item | bg hex | fg hex |
|---|---|---|---|
| leading gear ornament | `brand` | `273f46` | `7fbbb3` (blue) bold |
| directory | `pwd` | `3a463b` | `d3c6aa` (fg); anchors bold |
| git branch | `git` (branch) | `263f43` | `83c092` (aqua) bold |
| git state / status | `git` (dirty/staged/conflicted/upstream) | `4a3b2d` | `dbbc7f` (yellow) / `e69875` (orange) / `e67e80` (red) |
| runtime per-language | each `_tide_item_<runtime>` | `303f4a` | per starship colours: node `a7c080`, python `dbbc7f`, ruby `e67e80`, rust `e69875`, go `83c092`, java `d699b6` (disabled), terraform `d699b6` |
| cmd_duration | `cmd_duration` | `normal` | `e69875` orange |
| jobs | `jobs` | `normal` | `d699b6` purple |
| status | `status` | `normal` | `e67e80` red bold (failure) |
| time | `time` | `normal` | `9da9a0` fg_dim |
| character | `character` | — | `a7c080` success / `e67e80` error |

Shape:

- `tide_left_prompt_items = brand pwd git newline character`
- `tide_right_prompt_items = status cmd_duration jobs time`
- `tide_left_prompt_separator_diff_color = ` (rounded), `tide_left_prompt_separator_same_color = `, `tide_left_prompt_suffix = ` (round close), `tide_left_prompt_prefix = ''`
- `tide_right_prompt_separator_diff_color = `, `tide_right_prompt_separator_same_color = `, `tide_right_prompt_prefix = ` (round open), `tide_right_prompt_suffix = ''`
- `tide_prompt_transient_enabled = true`
- `tide_prompt_add_newline_before = true`
- `tide_left_prompt_frame_enabled = false`, `tide_right_prompt_frame_enabled = false`
- `tide_prompt_pad_items = true`

`tide_pwd_substitutions` seeded value (Starship parity):

```
tide_pwd_substitutions \
    "~/Dev/github.com" " github" \
    "~/Dev"            "󰲋 Dev" \
    "~/Desktop"        " Desktop" \
    "~/Documents"      " Documents" \
    "~/Downloads"      " Downloads" \
    "~"                ""
```

Order matters — longest-prefix patterns first. The patch enforces "first match wins" rather than re-sorting, so the config file's ordering is the contract. Document this in CLAUDE.md.

## Performance posture

- The visible prompt stays unblocked. All heavy work (`git status`, runtime version checks) already runs in the backgrounded `fish -c` spawned inside the eval'd `fish_prompt` (`functions/fish_prompt.fish:42-49`, `:70-72`, `:102-104`, `:129-131`). The theme has zero impact on that contract.
- Monorepo speedup comes from `tide_git_status_extra_args=--ignore-submodules=all` baked into the preset. Documented so users can append `--untracked-files=no` for even more headroom in extreme cases.
- Substitutions execute before path splitting and short-circuit on exact match → in the common deep-cd case, one `string match` per pair, exits on first hit. No extra forks.
- Brand item is a single `_tide_print_item` call — no command execution.

## Build sequence

Each step is independently verifiable. Stop and fix on red before moving on.

1. **`_tide_item_brand` + its test.** Smallest possible change; no dependency. Add `functions/_tide_item_brand.fish` and `tests/_tide_item_brand.test.fish`. Verify: `make test`. *Why first:* validates the test/print-item plumbing for the new item before everything depends on it.

2. **Patch `_tide_item_git` for `tide_git_status_extra_args`.** One-line append on the `git status --porcelain` invocation. Default empty → existing tests stay green. Verify: `make test` (`tests/_tide_item_git.test.fish` must still pass) plus a manual `cd` into a repo confirming output unchanged when the var is unset. *Why now:* trivial, removes one variable from later steps.

3. **Patch `_tide_pwd` for substitutions — test-first.** Add the new RUN/CHECK cases (see next section) to `tests/_tide_item_pwd.test.fish`. Run them — they should fail. Then patch `functions/_tide_pwd.fish` inside the `eval "function _tide_pwd …"` block until they pass. Verify: `make test`; existing pwd cases must still pass. *Why test-first:* the eval-string with `$` escaping is the highest-risk change in the whole plan and the failure modes are subtle.

4. **Author `functions/tide/configure/configs/everforest.fish`.** Pure data, no code paths. Reference the palette/shape sections above. Verify: `make lint` (catches typos), then from a fish shell after `make install` run `source functions/tide/configure/choices/all/style.fish; _load_config everforest; set | string match -er '^fake_tide_' | head` and confirm the expected `fake_tide_*` globals appear. *Why after step 3:* the file seeds `tide_pwd_substitutions` and `tide_git_status_extra_args`, so the runtime support has to exist first.

5. **`_tide_sub_load-theme.fish` + its test.** Verify: `tide load-theme everforest` in a fresh fish shell sets the expected `tide_*` universals without going through the wizard, then auto-`tide reload`s. *Why after step 4:* needs at least one valid config to load.

6. **Wizard option in `functions/tide/configure/choices/all/style.fish`.** Add `_tide_option 4 Everforest` and the `case Everforest` branch. Verify: `tide configure` → choose Everforest → preview renders the palette. *Why near the end:* the wizard preview won't show substitutions (see Decision C); verifying the standalone loader (step 5) first eliminates that as a confusion source.

7. **`functions/tide.fish` help + `completions/tide.fish` completions.** Verify: `tide --help` lists `load-theme`; `tide load-theme <TAB>` completes to `lean classic rainbow everforest`. *Why last code change:* UX polish on a working feature.

8. **Docs: `CLAUDE.md` Themes section + `CHANGELOG.md` Fork-changes entry.** No commands; read-pass review. *Why last:* summarises what shipped.

## Test cases for `_tide_pwd` substitutions

Extending `tests/_tide_item_pwd.test.fish`. Existing cases stay; append the block below, bracketed by `set tide_pwd_substitutions` / `set -e tide_pwd_substitutions` so the rest of the file is unaffected.

```fish
function _pwd
    _tide_decolor (_tide_pwd)
end

# --- substitutions OFF: regression check ---
set -e tide_pwd_substitutions
cd $HOME/Dev/github.com/foo
_pwd # CHECK: <existing default rendering — copy whatever this test currently asserts>

# --- exact match ---
set tide_pwd_substitutions "~/Dev/github.com" " github"
cd $HOME/Dev/github.com
_pwd # CHECK:  github

# --- prefix match ---
cd $HOME/Dev/github.com/foo/bar
_pwd # CHECK:  github/foo/bar

# --- empty replacement (Starship `~` -> `` parity) ---
set tide_pwd_substitutions "~" ""
cd $HOME
_pwd # CHECK:

# --- ordering: first match wins ---
set tide_pwd_substitutions \
    "~/Dev/github.com" " github" \
    "~/Dev"            "󰲋 Dev"
cd $HOME/Dev/github.com/x
_pwd # CHECK:  github/x

# Cleanup
set -e tide_pwd_substitutions
```

Implementer notes:

- `_tide_decolor` strips ANSI; output is bytes after color reset (must `funcsave`/source via `tests/test_setup.fish` first, as the existing test already does).
- `cd` mutates `$PWD`, which `_tide_pwd` reads on each call.
- `_tide_pwd` is `eval`'d once at fish-prompt-init. Re-source `functions/_tide_pwd.fish` in the test (the existing pwd test already handles this — match its pattern) so the patched body is in scope.
- The "substitutions OFF" baseline output depends on the existing test's `dist_btwn_sides` and pwd. Copy whatever the existing test currently asserts for that path as the regression baseline — do not invent a new expected value.

## Decisions on prior open questions

**A. `tide_<item>_bg_color = normal` for `cmd_duration` / `jobs` / `status` / `time` on the right prompt.**
Try `normal` first. `_tide_print_item` does `set_color $color -b $bg`; with `bg = normal` most terminals render "no background". If interactive verification (build sequence step 5) shows separator artifacts or smearing into adjacent segments, swap the offending item's bg colour to `1e2326` (everforest "crust") — close enough to terminal background to read as transparent. Document the fallback as a commented alternative inside `everforest.fish` so a future maintainer doesn't have to rediscover it.

**B. Empty replacement (`"~" -> ""`).**
The substitution pass treats an empty replacement literally: `_tide_pwd` returns an empty string and `_tide_print_item pwd ""` renders an empty pwd segment between the brand and git segments. This matches Starship's behaviour and is acceptable for v1. If the user later wants a visible marker at `$HOME`, they can change the entry to `"~" "~"` or drop the entry entirely to fall back to `tide_pwd_icon_home` rendering.

**C. Wizard preview doesn't show substitutions live.**
Accepted as v1 limitation. `_tide_pwd` reads `$tide_pwd_substitutions`, not `$fake_tide_pwd_substitutions`, so during the `tide configure` style preview the substitutions are inert. They activate only after the wizard's finish step (which runs `_tide_finish`, promoting `fake_*` → universal) — or immediately when using `tide load-theme everforest`. Documented in CLAUDE.md under the new Themes section. Not worth a second-read-path patch in `_tide_pwd` for v1.

**D. Bug-report version check now points at the fork.**
Carried over from prior commit `32a5295`. Until the fork tags a `v*` release, `tide bug-report` will say "out of date". The user has confirmed they plan to tag a release soon after this work lands; no plan change needed.

## Verification (final end-to-end before commit)

After all build-sequence steps pass:

1. **`make lint` + `make test`** — full suite green, including the new tests from steps 1, 3, 5.
2. **Baseline regression** — fresh fish shell after `make install`, default lean theme still renders correctly. Confirms none of the gated patches broke stock behaviour.
3. **Apply theme via `tide load-theme everforest`** — observe: brand glyph leads, pwd + git use the everforest segment colours, right-side has clock + cmd_duration + status + jobs. Confirm `cd ~/Dev/github.com/linhmtran168/tide` → ` github / tide`; `cd ~/Desktop` → ` Desktop`; `cd ~` → empty pwd segment (per Decision B).
4. **Apply theme via `tide configure` → Everforest** — preview shows palette/shape (substitutions inert per Decision C); finalising the wizard activates substitutions identically to step 3.
5. **Big-repo perf** — `cd` into a large repo. Visible prompt appears immediately (last-known state), then refreshes with current git status within sub-second. Confirms async path unchanged.
6. **Image diff** — terminal screenshot vs the original `~/mac_dotfiles/starship.toml` reference. Palette and shape parity.
