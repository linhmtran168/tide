# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Tide is a pure-Fish prompt distributed as a Fisher plugin. This is a fork of [IlanCosman/tide](https://github.com/IlanCosman/tide) on `linhmtran168/tide`; upstream releases follow the `v6.x` tag scheme and the current version lives in `functions/tide.fish` (`tide --version`). The plugin targets Fish 4.x and a Nerd Font.

Layout follows Fisher conventions, no build step:

- `functions/` — autoloaded; one file per function (`_tide_item_*`, `_tide_sub_*`, `_tide_<helper>`, plus user-facing `tide.fish` / `fish_prompt.fish` / `fish_mode_prompt.fish`).
- `conf.d/_tide_init.fish` — install / update / uninstall event handlers (`_tide_init_install`, etc.).
- `completions/tide.fish` — `tide` subcommand completions.
- `tests/*.test.fish` — one test per prompt item.
- `tools/` — release / asset helper scripts (not used in normal dev).

## Common commands

Everything goes through the Makefile, which sets `SHELL := /usr/bin/env fish`, so run targets from a shell that has `fish` on `PATH`.

| Command | What it does |
|---|---|
| `make` / `make all` | `fmt` + `lint` + `install` + `test` |
| `make fmt` | `fish_indent --write **.fish` |
| `make lint` | `fish --no-execute` on every `.fish` file |
| `make install` | Installs the plugin via Fisher from the current checkout (`fisher install .`) — this overwrites your local Tide install |
| `make test` | Downloads `littlecheck.py`, ensures `clownfish` (provides `mock`) is installed, then runs `python3 littlecheck.py --progress tests/**.test.fish` |
| `make clean` | Removes `littlecheck.py` |

User-facing entry points (run inside an interactive fish shell after `make install`):

- `tide configure` — interactive wizard; the primary way end users customize the prompt.
- `tide reload` — re-runs `_tide_remove_unusable_items` + `_tide_cache_variables`; required after editing `tide_left_prompt_items` / `tide_right_prompt_items` universal vars.
- `tide bug-report` — dumps Fish version, terminal, OS, locale, and current Tide vars. Ask users to paste this when triaging an issue. `tide bug-report --check` is the silent variant the install handler uses to surface warnings.

Run a single test file:

```fish
# One-time per machine:
make install                                 # also installs the plugin into ~/.config/fish
fisher install IlanCosman/clownfish          # provides the `mock` builtin
fish tests/test_setup.fish                   # funcsave's _tide_decolor + writes tests' conf.d

# Per run (the Makefile does these for you under `make test`):
_tide_remove_unusable_items
_tide_cache_variables
python3 littlecheck.py --progress tests/_tide_item_bun.test.fish
```

`make install` mutates your real Fish config (it's a real Fisher install, not a sandbox). Prefer running it in a throwaway shell / VM if you don't want your prompt swapped. CI runs `make test` on `macos-latest` and `ubuntu-latest` (`.github/workflows/CI.yml`), plus fish syntax-check, fish format-check, and Mega-Linter for markdown/YAML.

## Tests: how they work

Tests use [Littlecheck](https://github.com/ridiculousfish/littlecheck) (a `RUN`/`CHECK` driver) and [Clownfish](https://github.com/IlanCosman/clownfish) (`mock` builtin for stubbing commands). The standard shape:

```fish
# RUN: %fish %s
_tide_parent_dirs

function _bun
    _tide_decolor (_tide_item_bun)
end

mock bun --version "echo 1.1.39"
set -lx tide_bun_icon 

_bun # CHECK:                # expects empty output (no marker file present)
touch bun.lock
_bun # CHECK:  1.1.39       # expects icon + version
```

Notes that bite:

- `_tide_decolor` is `funcsave`d by `tests/test_setup.fish` (lands in `~/.config/fish/functions/_tide_decolor.fish`) and strips ANSI; always wrap item output through it before a `# CHECK:`. If a test fails with "command not found: _tide_decolor", you skipped `fish tests/test_setup.fish`.
- `# CHECK:` matches a single line of stdout. The space between `CHECK:` and the expected text is mandatory.
- Items that read parent-dir markers (`_tide_item_bun`, `node`, `python`, …) need `_tide_parent_dirs` to have been called in the test, and the marker file must exist under `$PWD` (use `mktemp -d` + `cd`).
- Use `mock <cmd> <args> "<fish body>"` to stub external CLIs — never rely on the host having the tool installed.

## Prompt architecture

Read this before editing prompt internals — the hot path is unusual.

**Init.** `conf.d/_tide_init.fish` registers Fisher event handlers. On first install it sources `_tide_sub_configure`, runs `_load_config lean`, then optionally launches `tide configure`.

**Per-shell setup.** `functions/fish_prompt.fish` runs the first time the prompt fires. It:

1. Calls `_tide_remove_unusable_items` to drop items whose CLI isn't on `PATH` (`type --query`), writing the filtered lists into universal vars `_tide_left_items` / `_tide_right_items`. **This is why adding a new tool-dependent item also requires editing the hard-coded list inside `_tide_remove_unusable_items.fish`** — if you skip that, the item will appear even on machines without the tool, and inversely, it will be silently dropped when present unless the CLI name matches the item name (see the `switch $item` block for the exceptions: `distrobox`, `nix_shell`, `python`).
2. Calls `_tide_cache_variables` and `_tide_parent_dirs` to precompute colors/markers.
3. `eval`s one of four template strings (1-line vs 2-line × transient vs not) to define the real `fish_prompt` / `fish_right_prompt`. Branching happens once at load time, not per prompt.

**Async rendering.** The generated `fish_prompt` doesn't compute its own output. It launches a backgrounded `fish -c "... set _tide_prompt_$fish_pid (_tide_2_line_prompt)"`, `disown`s it, and kills the previous background pid. An `--on-variable _tide_prompt_$fish_pid` handler (`_tide_refresh_prompt`) sets `_tide_repaint` and calls `commandline -f repaint`. The visible prompt is whatever the last completed background job stored. This is the whole reason it feels snappy — keep this contract intact when touching `fish_prompt.fish`.

**Items.** Each `_tide_item_<name>` echoes via `_tide_print_item <name> <text>`, which looks up `tide_<name>_bg_color` / `tide_<name>_color` and emits the right separator based on `$_tide_side` (left/right) and the previous item's color. Item-side state (`$prev_bg_color`, `$add_prefix`) is global within a single prompt render.

**Subcommands.** `tide <sub>` dispatches to `_tide_sub_<sub>` (see `functions/tide.fish`). Existing subcommands: `configure`, `reload`, `bug-report`. After mutating `tide_*_prompt_items` universal vars, users must run `tide reload` for the new items to be filtered + cached.

## Themes

Themes are data files at `functions/tide/configure/configs/<name>.fish` — bare `tide_*` assignments. Available presets: `lean`, `classic`, `rainbow`, `everforest` (fork-only).

Two ways to activate a theme:

- `tide configure` — interactive wizard. Step 1 (Prompt Style) lists the four presets. Lean/Classic/Rainbow route through the standard `prompt_colors` → `show_time` → … flow. Everforest skips the 16-color step (it has no `_16color` variant) and jumps to `show_time` directly.
- `tide load-theme <name>` — non-interactive. Sources `<name>.fish` + `icons.fish` as `fake_tide_*` vars, then promotes them to `tide_*` universals (mirror of `_tide_finish`) and calls `tide reload`. Unknown names exit 1 with the available list on stderr.

The Everforest preset depends on three opt-in knobs added in this fork. Each defaults to unset, so other themes / existing users see zero behavior change:

- `tide_pwd_substitutions` — paired list `pattern1 replacement1 pattern2 replacement2 …`. `_tide_pwd` applies the **first prefix match** (longest patterns first is your responsibility — ordering is the contract) against the post-`$HOME→~` path. Exact match emits the replacement as a single anchored segment; prefix match replaces the prefix and skips the leading pwd icon. Read in `_tide_pwd` (universal vars only — the wizard's `fake_*` preview does **not** see substitutions live; they activate after `_tide_finish` or `tide load-theme`).
- `tide_git_status_extra_args` — appended verbatim to the `git status --porcelain` call in `_tide_item_git`. Everforest seeds `--ignore-submodules=all` for monorepo speed. Async render already keeps the visible prompt unblocked; this cuts what the backgrounded `fish -c` actually does on `cd`.
- `tide_brand_icon` — when non-empty, `_tide_item_brand` emits it via `_tide_print_item brand $tide_brand_icon`. Static-text ornament, no command execution. Not in `_tide_remove_unusable_items` because it doesn't depend on a CLI.

When adding a new preset:

1. New `functions/tide/configure/configs/<name>.fish` — bare `tide_*` assignments.
2. Add a `_tide_option N <Label>` + `case <Label>` branch in `functions/tide/configure/choices/all/style.fish`, routing via `_next_choice` to whichever downstream step makes sense (most presets → `all/prompt_colors`; a fixed-palette preset → `all/show_time`).
3. Append the name to the static list in `completions/tide.fish` (`__fish_seen_subcommand_from load-theme`).
4. Update the `load-theme` help line in `_tide_help` (`functions/tide.fish`).

## Code conventions (from CONTRIBUTING.md, enforced by review)

- `test` over `[...]`; `&&` / `||` over `and` / `or`. For non-trivial branching use `if`/`else if`/`else`.
- Naming: everything `snake_case`. User-facing → `tide_…`. Internal → `_tide_…`. Items → `_tide_item_<name>`. Subcommands → `_tide_sub_<name>`.
- Prefer pipes to command substitution when no extra command is required.
- Indent: 4 spaces in `.fish`, 2 spaces in `json`/`md`/`yml`, tabs in `Makefile` (`.editorconfig`).
- Markdown/YAML formatting is Prettier-driven and checked by Mega-Linter.

## Adding a new prompt item (checklist)

1. `functions/_tide_item_<name>.fish` — output via `_tide_print_item <name> …`.
2. `tests/_tide_item_<name>.test.fish` — RUN/CHECK with mocked CLI.
3. If it depends on a CLI tool, add `<name>` (and its CLI names if different) to the loop in `functions/_tide_remove_unusable_items.fish`.
4. Define `tide_<name>_bg_color`, `tide_<name>_color`, and any `tide_<name>_icon` defaults — usually inside `_tide_sub_configure`'s `_load_config` profiles.
5. Add it to `tide_left_prompt_items` / `tide_right_prompt_items` defaults if it ships on by default.

## Release (from CONTRIBUTING.md)

Bump the version in `functions/tide.fish`, set the date in `CHANGELOG.md`, commit titled with the version, tag, push. `release.yml` slices `CHANGELOG.md` into release notes and publishes via `softprops/action-gh-release`.

## Non-ASCII safety

Item files and tests embed Nerd Font glyphs (e.g. `tide_bun_icon `). When editing those lines, verify the bytes survived (`cat`, `hexdump -C | head`) — corrupted glyphs only surface in a terminal and won't fail lint.
