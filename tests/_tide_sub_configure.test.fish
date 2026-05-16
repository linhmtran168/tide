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
    _tide_sub_configure --auto --style=Everforest --show_time='12-hour format' >/dev/null 2>&1
    test \"\$tide_time_format\" = '%r'; and echo everforest-configured
    contains os \$tide_left_prompt_items; and echo everforest-left-items
    contains time \$tide_right_prompt_items; and echo everforest-time-item
    contains cmd_duration \$tide_right_prompt_items; and echo everforest-duration-item
"
# CHECK: everforest-configured
# CHECK: everforest-left-items
# CHECK: everforest-time-item
# CHECK: everforest-duration-item

env HOME=$tmp_home XDG_CONFIG_HOME=$tmp_home/.config fish --no-config -c "
    set fish_function_path '$fns_dir' \$fish_function_path
    function uname
        echo Darwin
    end
    function tide
    end
    _tide_sub_configure --auto --style=Everforest --show_time=No >/dev/null 2>&1
    test -z \"\$tide_time_format\"; and echo everforest-no-time-format
    not contains time \$tide_right_prompt_items; and echo everforest-no-time-item
    contains cmd_duration \$tide_right_prompt_items; and echo everforest-keeps-duration
"
# CHECK: everforest-no-time-format
# CHECK: everforest-no-time-item
# CHECK: everforest-keeps-duration

command rm -r $tmp_home
