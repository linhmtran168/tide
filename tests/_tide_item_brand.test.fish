# RUN: %fish %s

function _brand
    _tide_decolor (_tide_item_brand)
end

# No icon set: nothing emitted
set -e tide_brand_icon
_brand # CHECK:

# Empty icon: nothing emitted
set -gx tide_brand_icon ''
_brand # CHECK:

# Icon set: glyph emitted
set -gx tide_brand_icon BRAND
_brand # CHECK: BRAND
