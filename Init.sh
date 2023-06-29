#!/bin/sh
#
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
utildir="$basedir"/ush/bash_utils

# set the pre-commit hook
echo -e "#!/bin/sh" > $basedir/.git/hooks/pre-commit
chmod +x $basedir/.git/hooks/pre-commit
echo -e "ush/bash_utils/preCommit">>$basedir/.git/hooks/pre-commit

$utildir/make_agent_link_for_fix
touch $basedir/fix/INIT_DONE
