# RUN: %fish %s
_tide_parent_dirs

function _time -a format icon
    LC_TIME=en_US.UTF-8 _tide_decolor (tide_time_format="$format" tide_time_icon="$icon" _tide_item_time)
end

# None
_time '' clock # CHECK:

# 24 Hour
_time %T '' # CHECK: {{\d\d:\d\d:\d\d}}

# 12 Hour
_time %r '' # CHECK: {{\d\d:\d\d:\d\d (A|P)M}}

# Icon
_time %T clock # CHECK: clock {{\d\d:\d\d:\d\d}}
