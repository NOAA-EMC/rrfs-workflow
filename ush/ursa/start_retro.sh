#!/bin/bash
#
# Start an RRFS retro on Ursa in one go: steps B-D of the run instructions (links and suite
# definitions, the ecflow server, loading and beginning both suites). Settings come from
# ecf/defs/ursa_config.sh; edit that first (step A).
#
# Usage: ush/ursa/start_retro.sh [--hold] [--reload]
#   --hold    start everything with the RRFS suite suspended, so nothing is submitted until you
#             run "ecflow_client --resume /para"; use the pause to suspend what you want to skip
#             (see "Run less than the whole retro" in the instructions)
#   --reload  the suites are already loaded: delete and reload them. Their state is lost, so the
#             retro starts over from RETRO_START.
#
# Run from any Ursa login node. The server runs on uecflow01 at the port the ecflow module gives
# you (1500 + uid) unless ECF_PORT is already set.
#
set -eu

repo=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
hold=NO
reload=NO
for arg in "$@"; do
  case ${arg} in
    --hold)   hold=YES ;;
    --reload) reload=YES ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: ${arg} (try --help)" >&2; exit 1 ;;
  esac
done
step() { printf '\n=== %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# shellcheck source=/dev/null
. "${repo}/ecf/defs/ursa_config.sh"
if ! type module >/dev/null 2>&1; then source /etc/profile; fi
module load "ecflow/${ECFLOW_VER}" >/dev/null 2>&1 || die "cannot load ecflow/${ECFLOW_VER}"
export ECF_HOST=${ECFLOW_HOST}
export ECF_PORT=${ECF_PORT:-$((1500 + $(id -u)))}
echo "repo:   ${repo}"
echo "server: ${ECF_HOST}:${ECF_PORT}   ECF_HOME: ${ECF_HOME}"
echo "retro:  ${RETRO_START} to ${RETRO_END}"

# Decide about the suites before changing anything, so a refusal leaves everything as it was
ping_ok() { ecflow_client --ping >/dev/null 2>&1; }
suite_loaded() { ecflow_client --get_state "/$1" >/dev/null 2>&1; }
if ping_ok && { suite_loaded "${RRFS_SUITE}" || suite_loaded prod_clone; } && [ "${reload}" != YES ]; then
  die "suites are already loaded on ${ECF_HOST}:${ECF_PORT}. Re-running would lose their state;
       pass --reload if that is what you want, or use ecflow_client/rrfsstat to work with them."
fi

step "B: links and suite definitions"
log=${ECF_HOME}/start_retro.setup.log
mkdir -p "${ECF_HOME}" "${OUTPUTDIR}" "${DEV_PTMP}" "${DEV_DATAROOT}"
# setup_ecf_links.sh must run from ecf/ and is verbose; keep its output in a log
(cd "${repo}/ecf" && ./setup_ecf_links.sh > "${log}" 2>&1) || die "setup_ecf_links.sh failed; see ${log}"
echo "links and generated job cards: done (log: ${log})"
(cd "${repo}/ecf" && ./defs/make_ursa_def.sh | head -1)
"${repo}/ush/prod_clone/make_retro_def.sh" | head -1

step "C: ecflow server"
if ping_ok; then
  echo "a server is already running on ${ECF_HOST}:${ECF_PORT}; using it"
else
  # setsid gives the server its own session: a plain "nohup ... &" keeps the ssh session open for
  # as long as the server runs. The timeout is a backstop; whether the server answers is what counts.
  timeout 60 ssh -n -o BatchMode=yes "${ECF_HOST}" "bash -lc 'module load ecflow/${ECFLOW_VER} >/dev/null 2>&1; \
    cd ${ECF_HOME} && setsid -f nohup ecflow_server --port ${ECF_PORT} > ${ECF_HOME}/ecflow_server.out 2>&1 < /dev/null'" \
    || echo "(ssh returned $?; checking whether the server came up anyway)"
  for _ in $(seq 1 30); do ping_ok && break; sleep 2; done
  ping_ok || die "the server did not answer on ${ECF_HOST}:${ECF_PORT}; see ${ECF_HOME}/ecflow_server.out"
  echo "server started"
fi
# a new server starts HALTED and schedules nothing until this; harmless on a running one
ecflow_client --restart

step "D: load and begin the suites"
if [ "${reload}" = YES ]; then
  for s in "${RRFS_SUITE}" prod_clone; do
    suite_loaded "${s}" && ecflow_client --delete=force yes "/${s}" && echo "deleted /${s}"
  done
fi
# a state file left from an earlier retro would make the driver think it had already started
rm -f "${ECF_HOME}/retro_prod_clone_state.json"
ecflow_client --load "${repo}/ecf/defs/rrfs_ursa.def"
ecflow_client --load "${repo}/ush/prod_clone/ecf/defs_retro.def"
# --begin clears ordinary suspensions and submits whatever is already free (e.g. the cleanup
# tasks), but a suite with "defstatus suspended" comes up suspended, so nothing in it can submit.
# The retro driver still runs meanwhile and releases the first family, which then waits.
if [ "${hold}" = YES ]; then
  ecflow_client --alter change defstatus suspended "/${RRFS_SUITE}"
fi
ecflow_client --begin "${RRFS_SUITE}"
ecflow_client --begin prod_clone
if [ "${hold}" = YES ]; then
  echo "/${RRFS_SUITE} is SUSPENDED: nothing will be submitted until you run"
  echo "  ecflow_client --resume /${RRFS_SUITE}"
fi

step "Running"
cat <<EOF
Suites /${RRFS_SUITE} and /prod_clone are loaded and begun on ${ECF_HOST}:${ECF_PORT}.
$( [ "${hold}" = YES ] && echo "/${RRFS_SUITE} is suspended (--hold); resume it to start submitting." || echo "The retro driver releases the first family within a minute." )

Watch it:  ${repo}/ush/ursa/rrfsstat          (or ${ECF_HOME}/rrfs_status.txt)
     GUI:  ecflow_ui, server ${ECF_HOST} port ${ECF_PORT}
    Logs:  ${ECF_HOME}/${RRFS_SUITE}/primary/<DD>/rrfs/v1.0/<cyc>/<wgf>/<family>/<task>.1
    Stop:  ecflow_client --suspend /${RRFS_SUITE}      (pause everything, keep state)
EOF
