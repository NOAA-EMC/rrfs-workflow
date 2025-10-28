#!/usr/bin/env bash
# shellcheck disable=SC1091
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "${run_dir}" || exit
source detect_machine.sh
source linter_get_EXEC_DIR.sh

rm -rf "${run_dir}/output.linter_shellcheck"
#shellcheck disable=SC2046
find $(paste -s -d ' ' shellcheck_include_dirs.txt) -maxdepth 1 -type f \
  -not -name "shellcheck_include_dirs.txt" -not -name "obs_type_all" \
  -not -name "output.linter_shellcheck" -not -name "obsdatout_to_obsdatin.py" \
  -print0 | xargs -0 "${EXEC_DIR}/shellcheck" --color=always >> output.linter_shellcheck

echo -e "Use the following command to check the colorful shellcheck results:\n"
echo "less -R ${run_dir}/output.linter_shellcheck"
