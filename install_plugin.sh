#! /bin/bash
# This script is used to install moodle plugins

main(){
    # Check if the script is run as root
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi

    readarray ddl < <(yq eval '.plugins.direct-downloads[]' "$config")

    # Download and unzip missing Plugins
    for plugin in "${ddl[@]}"; do
        name=$(basename <<< echo "$plugin")
        # Check if the zip file exists, download and unzip if it doesn't
        if ! [ -f "$plugindir"/"$name" ]; then
            err=$(wget "$plugin" -O "$plugindir"/"$name"  2>&1)
            if [ $? -ne 0 ]; then
                echo "Error downloading $plugin"
                echo "$err"
                exit 1
            fi

            # Create plugintype folder if it doesn't exist
            plugintype=$(echo "$name" | cut -d'_' -f1)
            [ -d "$moodledir"/"$plugintype" ] || mkdir "$moodledir"/"$plugintype"

            # Unzip the plugin
            err=$(bsdtar -xf "$plugindir"/"$name" -C "$moodledir"/"$plugintype" 2>&1)
            if [ $? -ne 0 ]; then
                echo "Error unzipping $name"
                echo "$err"
                rm "$plugindir"/"$name"
                exit 1
            fi

            chown -R www-data:www-data "$moodledir"/"$plugintype"

            # Install the Plugin
            err=$(sudo -u www-data php "$moodledir"/admin/cli/upgrade.php --non-interactive --lang=en 2>&1)
            if [ $? -ne 0 ]; then
                echo "Error installing $name"
                echo "$err"
                rm "$plugindir"/"$name"

                pluginname=$(echo "$err" | grep -oP '(?<=failed for ).*' | cut -d'_' -f 2-)
                fullpath=$moodledir/$plugintype/$pluginname
                rm -rf "${fullpath:?}"
                dep_check=$(echo "$err" | grep -q "Dependencies check failed")
            fi
        fi
    done
    [ -n "$dep_check" ] || {
        echo "Dependencies check failed. Trying to run the script again, maybe dependencies are installed now."
        $0 "$moodledir" $runs
    }
}

# CD to the directory where the script is to make sure we are in the right directory
if [[ $BASH_SOURCE = */* ]]; then
    cd -- "${BASH_SOURCE%/*}/" || exit
fi


project_path=$(cd ..; pwd -P)
LOGGER="$project_path"/scripts/logger.pl
LOGFILE="$project_path"/logs/install_plugin.log
config="$project_path"/config.yml
runs=1
runs+=$2
if (( $runs >= 5 )); then
    echo "Dependencies check failed 5 times. Exiting."
    exit 1
fi


# Create log dir and file if they don't exist
[ -d "$project_path"/logs ] || mkdir "$project_path"/logs
[ -f "$LOGFILE" ] || touch "$LOGFILE"

# Create plugin dir if it doesn't exist
[ -d "$project_path"/src/plugins ] || mkdir -p "$project_path"/src/plugins
plugindir="$project_path"/src/plugins

[ -n "$1" ] || {
    echo "Usage: $0 /path/to/moodle"
    exit 1
}

moodledir=$1

main
# main 2>&1 >> $LOGGER $LOGFILE
