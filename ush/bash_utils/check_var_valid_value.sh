#
#-----------------------------------------------------------------------
#
# This function checks whether the specified variable contains a valid 
# value (where the set of valid values is also specified).
#
#-----------------------------------------------------------------------
#
function check_var_valid_value() {
set -x
#
#-----------------------------------------------------------------------
#
# Get the full path to the file in which this script/function is located 
# (scrfunc_fp), the name of that file (scrfunc_fn), and the directory in
# which the file is located (scrfunc_dir).
#
#-----------------------------------------------------------------------
#
  local scrfunc_fp=$( readlink -f "${BASH_SOURCE[0]}" )
  local scrfunc_fn=$( basename "${scrfunc_fp}" )
  local scrfunc_dir=$( dirname "${scrfunc_fp}" )
#
#-----------------------------------------------------------------------
#
# Get the name of this function.
#
#-----------------------------------------------------------------------
#
  local func_name="${FUNCNAME[0]}"
#
#-----------------------------------------------------------------------
#
# Check arguments.
#
#-----------------------------------------------------------------------
#
  if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then

    print_err_msg_exit "
Incorrect number of arguments specified:

  Function name:  \"${func_name}\"
  Number of arguments specified:  $#

Usage:

  ${func_name}  var_name   valid_var_values_array_name  [msg]

where the arguments are defined as follows:

  var_name:
  The name of the variable whose value we want to check for validity.

  valid_var_values_array_name:
  The name of the array containing a list of valid values that var_name
  can take on.

  msg
  Optional argument specifying the first portion of the error message to
  print out if var_name does not have a valid value.
"

  fi
#
#-----------------------------------------------------------------------
#
# Declare local variables.
#
#-----------------------------------------------------------------------
#
  local var_name \
        valid_var_values_array_name \
        var_value \
        valid_var_values_at \
        valid_var_values \
        err_msg \
        valid_var_values_str
#
#-----------------------------------------------------------------------
#
# Set local variable values.
#
#-----------------------------------------------------------------------
#
  var_name="$1"
  valid_var_values_array_name="$2"

  var_value=${!var_name}
  valid_var_values_at="$valid_var_values_array_name[@]"
  valid_var_values=("${!valid_var_values_at}")

  if [ "$#" -eq 3 ]; then
    err_msg="$3"
  else
    err_msg="\
The value specified in ${var_name} is not supported:
  ${var_name} = \"${var_value}\""
  fi
#
#-----------------------------------------------------------------------
#
# If var_value contains a dollar sign, we assume the corresponding variable 
# (var_name) is a template variable, i.e. one whose value contains a 
# reference to another variable, e.g.
#
#   MY_VAR='\${ANOTHER_VAR}'
#
# In this case, we do nothing since it does not make sense to check 
# whether var_value is a valid value (since its contents have not yet 
# been expanded).  If var_value doesn't contain a dollar sign, it must 
# contain a literal string.  In this case, we check whether it is equal 
# to one of the elements of the array valid_var_values.  If not, we 
# print out an error message and exit the calling script.
#
#-----------------------------------------------------------------------
#
  if [[ "${var_value}" != *'$'* ]]; then
    is_element_of "valid_var_values" "${var_value}" || { \
      valid_var_values_str=$(printf "\"%s\" " "${valid_var_values[@]}");
      print_err_msg_exit "\
${err_msg}
${var_name} must be set to one of the following:
  ${valid_var_values_str}"; \
    }
  fi
}

