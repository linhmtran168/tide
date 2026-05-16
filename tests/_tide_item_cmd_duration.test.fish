# RUN: %fish %s
_tide_parent_dirs

function _cmd_duration -a duration threshold decimals
    set -lx CMD_DURATION $duration
    set -lx tide_cmd_duration_threshold $threshold
    set -lx tide_cmd_duration_decimals $decimals
    set -lx tide_cmd_duration_icon

    _tide_decolor (_tide_item_cmd_duration)
end

function _cmd_duration_with_icon -a duration threshold decimals
    set -lx CMD_DURATION $duration
    set -lx tide_cmd_duration_threshold $threshold
    set -lx tide_cmd_duration_decimals $decimals
    set -lx tide_cmd_duration_icon timer

    _tide_decolor (_tide_item_cmd_duration)
end

_cmd_duration 2000 3000 0 # Check:
_cmd_duration 4567 3000 3 # CHECK: 4.567s
_cmd_duration 456700 3000 0 # CHECK: 7m 36s
_cmd_duration 4567000 3000 0 # CHECK: 1h 16m 7s
_cmd_duration_with_icon 4567 3000 3 # CHECK: timer 4.567s
