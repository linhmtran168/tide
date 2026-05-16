function _tide_item_time
    test -n "$tide_time_format" || return
    _tide_print_item time $tide_time_icon' ' (date +$tide_time_format)
end
