#
#-----------------------------------------------------------------------
# This file defines function that sources a config file (yaml/json etc)
# into the calling shell script
#-----------------------------------------------------------------------
#

function config_to_str() {
  set -x
  echo "source_config calling python script config_utils.py start"
  $USHdir/config_utils.py -o $1 -c $2 "${@:3}"
  echo "source_config calling python script config_utils.py end"
}

#
#-----------------------------------------------------------------------
# Define functions for different file formats
#-----------------------------------------------------------------------
#
function config_to_shell_str() {
    set -x
    echo "source_config config_to_shell_str calling config_to_str start"
    config_to_str shell "$@"
    echo "source_config config_to_shell_str calling config_to_str end"
}
function config_to_ini_str() {
    set -x
    echo "source_config config_to_ini_str calling config_to_str start"
    config_to_str ini "$@"
    echo "source_config config_to_ini_str calling config_to_str end"
}
function config_to_yaml_str() {
    set -x
    echo "source_config config_to_yaml_str calling config_to_str start"
    config_to_str yaml "$@"
    echo "source_config config_to_yaml_str calling config_to_str end"
}
function config_to_json_str() {
    set -x
    echo "source_config config_to_json_str calling config_to_str start"
    config_to_str json "$@"
    echo "source_config config_to_json_str calling config_to_str end"
}
function config_to_xml_str() {
    set -x
    echo "source_config config_to_xml_str calling config_to_str start"
    config_to_str xml "$@"
    echo "source_config config_to_xml_str calling config_to_str end"
}

#
#-----------------------------------------------------------------------
# Source contents of a config file to shell script
#-----------------------------------------------------------------------
#
function source_config() {
  set -x
  echo "source_config source_config source config_to_shell_str start"
  source <( config_to_shell_str "$@" )
  echo "source_config source_config source config_to_shell_str end"

}
#
#-----------------------------------------------------------------------
# Source partial contents of a config file to shell script.
#   Only those variables needed by the task are sourced
#-----------------------------------------------------------------------
#
function source_config_for_task() {
  set -x
  source <( config_to_shell_str "${@:2}" -k "(^(?!task_)|$1).*" )

}
