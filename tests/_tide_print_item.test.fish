# RUN: %fish %s
_tide_parent_dirs

set -gx tide_prompt_pad_items true
_tide_cache_variables

set -gx tide_left_prompt_prefix ''
set -gx tide_left_prompt_separator_same_color ''
set -gx tide_left_prompt_separator_diff_color ''
set -gx tide_right_prompt_prefix ''
set -gx tide_right_prompt_separator_same_color ''
set -gx tide_right_prompt_separator_diff_color ''
set -gx tide_alpha_bg_color normal
set -gx tide_alpha_color normal
set -gx tide_beta_bg_color normal
set -gx tide_beta_color normal
set -gx _tide_color_separator_same_color ''

function _items -a side
    set -g add_prefix
    set -g _tide_side $side
    _tide_print_item alpha A
    _tide_print_item beta B
end

_tide_decolor (_items left) # CHECK:  A  B
_tide_decolor (_items right) # CHECK:  A B
