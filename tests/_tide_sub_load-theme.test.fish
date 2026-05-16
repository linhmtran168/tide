# RUN: %fish %s

# --- Unknown theme: non-zero exit + stderr lists known themes ---
# Safe to run directly in parent: error path returns before any `set -g/-U`.
set -l err_file (mktemp)
_tide_sub_load-theme nonexistent 2>$err_file
test $status -ne 0; and echo unknown-nonzero # CHECK: unknown-nonzero
string match -q "*Unknown theme: nonexistent*" <$err_file; and echo error-names-name # CHECK: error-names-name
string match -q "*everforest*" <$err_file; and echo lists-everforest # CHECK: lists-everforest
string match -q "*lean*" <$err_file; and echo lists-lean # CHECK: lists-lean
command rm $err_file

# --- Known theme: load everforest in an isolated fish so the `set -U`s land
# in a throwaway HOME and never reach the dev's real universals.
set -l tmp_home (mktemp -d)
set -l fns_dir (path resolve (path dirname (status -f))/../functions)

env HOME=$tmp_home fish -c "
    set fish_function_path '$fns_dir' \$fish_function_path
    function uname
        echo Darwin
    end
    function tide
    end
    _tide_sub_load-theme everforest >/dev/null 2>&1
    test \"\$tide_git_status_extra_args\" = '--ignore-submodules=all'; and echo git-args-set
    test -n \"\$tide_brand_icon\"; and echo brand-icon-set
    test \"\$tide_os_icon\" = ''; and echo os-icon-set
    contains os \$tide_left_prompt_items; and echo os-in-left-items
    contains -- '~' \$tide_pwd_substitutions; and echo subs-pair-set
" 2>/dev/null
# CHECK: git-args-set
# CHECK: brand-icon-set
# CHECK: os-icon-set
# CHECK: os-in-left-items
# CHECK: subs-pair-set

command rm -r $tmp_home
