# RUN: %fish %s

set -l tmp_home (mktemp -d)
set -l fns_dir (path resolve (path dirname (status -f))/../functions)

env HOME=$tmp_home XDG_CONFIG_HOME=$tmp_home/.config fish --no-config -c "
    set fish_function_path '$fns_dir' \$fish_function_path
    function uname
        echo Darwin
    end
    function tide
    end
    _tide_sub_configure --auto --style=Everforest >/dev/null 2>&1
    test \"\$tide_time_format\" = '%T'; and echo everforest-configured
    contains os \$tide_left_prompt_items; and echo everforest-left-items
"
# CHECK: everforest-configured
# CHECK: everforest-left-items

command rm -r $tmp_home
