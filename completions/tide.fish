complete tide --no-files

set -l subcommands bug-report configure reload load-theme

complete tide -x -n __fish_use_subcommand -a bug-report -d "Print info for use in bug reports"
complete tide -x -n __fish_use_subcommand -a configure -d "Run the configuration wizard"
complete tide -x -n __fish_use_subcommand -a reload -d "Reload tide configuration"
complete tide -x -n __fish_use_subcommand -a load-theme -d "Apply a preset non-interactively"

complete tide -x -n "not __fish_seen_subcommand_from $subcommands" -s h -l help -d "Print help message"
complete tide -x -n "not __fish_seen_subcommand_from $subcommands" -s v -l version -d "Print tide version"

complete tide -x -n '__fish_seen_subcommand_from bug-report' -l clean -d "Run clean Fish instance and install Tide"
complete tide -x -n '__fish_seen_subcommand_from bug-report' -l verbose -d "Print full Tide configuration"

complete tide -x -n '__fish_seen_subcommand_from load-theme' -a "lean lean_16color classic classic_16color rainbow rainbow_16color everforest"
