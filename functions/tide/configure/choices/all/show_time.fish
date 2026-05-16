function show_time
    while contains -i time $fake_tide_right_prompt_items | read -l time_index
        set -e fake_tide_right_prompt_items[$time_index]
    end

    _tide_title 'Show current time?'

    _tide_option 1 No
    _tide_display_prompt

    set -a fake_tide_right_prompt_items time

    _tide_option 2 '24-hour format'
    set -g fake_tide_time_format %T
    _tide_display_prompt

    _tide_option 3 '12-hour format'
    set -g fake_tide_time_format %r
    _tide_display_prompt

    _tide_menu (status function)
    switch $_tide_selected_option
        case No
            set -g fake_tide_time_format ''
            while contains -i time $fake_tide_right_prompt_items | read -l time_index
                set -e fake_tide_right_prompt_items[$time_index]
            end
        case '24-hour format'
            set -g fake_tide_time_format %T
        case '12-hour format'
            set -g fake_tide_time_format %r
    end
    switch $_tide_configure_style
        case lean
            _next_choice "$_tide_configure_style"/"$_tide_configure_style"_prompt_height
        case classic rainbow
            _next_choice "$_tide_configure_style"/"$_tide_configure_style"_prompt_separators
        case everforest
            _next_choice all/finish
    end
end
