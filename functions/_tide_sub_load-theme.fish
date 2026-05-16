function _tide_sub_load-theme -a name
    set -l configs_dir (dirname (status filename))/tide/configure/configs
    if not test -f $configs_dir/$name.fish
        printf 'Unknown theme: %s\nAvailable: ' $name >&2
        path basename $configs_dir/*.fish | string replace .fish '' | string join ' ' >&2
        echo >&2
        return 1
    end

    _tide_detect_os | read -g --line os_branding_icon os_branding_color os_branding_bg_color

    # Mirror _load_config (style.fish:33-36): source icons + theme as fake_ vars
    string replace -r '^' 'set -g fake_' <$configs_dir/../icons.fish | source
    string replace -r '^' 'set -g fake_' <$configs_dir/$name.fish | source

    # Mirror _tide_finish (finish.fish:30-37): ensure char/vi_mode, promote fake_ → universal
    contains character $fake_tide_left_prompt_items || set -p fake_tide_left_prompt_items vi_mode
    for fakeVar in (set --names | string match -r "^fake_tide.*")
        set -U (string replace 'fake_' '' $fakeVar) $$fakeVar
        set -e $fakeVar
    end
    set -e $_tide_prompt_var 2>/dev/null

    tide reload
end
