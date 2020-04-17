#!/bin/bash

#
# constants
#
phoenicis_dir=~/.Phoenicis/
containers_dir="$phoenicis_dir/containers/"
engines_dir="$phoenicis_dir/engines/"
engines_wine_dir="$engines_dir/wine/"
wine_prefixes_dir="$containers_dir/wineprefix/"
phoenicis_cfg="phoenicis.cfg"
wine_log="wine.log"

#
# handle command line options
#
usage="$(basename "$0") [-h] shortcut -- runs the given Phoenicis shortcut

Options:
    -h  show this help text"

while getopts ':h' option; do
    case "$option" in
        h) echo "$usage"
           exit
           ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "$usage"
    exit 1
fi

shortcut_file="$1"

#
# parse shortcut json
#
type=`jq -r '.type' "$shortcut_file"`
if [ $type != "WINE" ]; then
    echo "Unsupported type: '$type'!"
    exit 1
fi
wine_prefix=`jq -r '.winePrefix' "$shortcut_file"`
executable=`jq -r '.executable' "$shortcut_file"`
arguments=`jq -r '.arguments | if type=="string" then [.] else . end | join(" ")' "$shortcut_file"`
environment=`jq -r '.environment | to_entries[] | "\(.key)=\(.value)"' "$shortcut_file"`
working_dir=`jq -r '.workingDirectory' "$shortcut_file"`

wine_prefix_dir="$wine_prefixes_dir/$wine_prefix"

#
# parse phoenicis.cfg
#
phoenicis_cfg_file="$wine_prefix_dir/$phoenicis_cfg"
wine_distribution=`jq -r '.wineDistribution' "$phoenicis_cfg_file"`
wine_version=`jq -r '.wineVersion' "$phoenicis_cfg_file"`
wine_architecture=`jq -r '.wineArchitecture' "$phoenicis_cfg_file"`

#
# set environment
#
wine_dir="$engines_wine_dir/$wine_distribution-linux-$wine_architecture/$wine_version/"
ld_path=""
if [ $wine_architecture == "amd64" ]; then
    ld_path="$wine_dir/lib64:$wine_dir/lib:$LD_LIBRARY_PATH"
else
    ld_path="$wine_dir/lib:$LD_LIBRARY_PATH"
fi
export LD_LIBRARY_PATH="$ld_path"
export WINEPREFIX="$wine_prefix_dir"
export $environment

#
# run
#
wine_bin=""
if [ $wine_architecture == "amd64" ]; then
    wine_bin="$wine_dir/bin/wine64"
else
    wine_bin="$wine_dir/bin/wine"
fi
cd "$working_dir"
$wine_bin "$executable" $arguments &> "$wine_prefix_dir/$wine_log"
