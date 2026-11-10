"""The retro settings: retro/config.sh (through load_config.sh) and the domain file.

Both are bash, shared with setup_retro_links.sh and the other retro scripts, so they are sourced
by bash, under the same set -eu as those scripts, and every variable is read back from it.
Environment variables still win, since the config files only set what is not set already.
"""

import os
import subprocess
import sys

# Source the settings, then print every variable as NUL-separated fields: "s", name, value for a
# string, or "a", name, count and the elements for an indexed array. Anything the config files
# print goes to stderr, so it cannot be mistaken for a setting.
_DUMP = r'''
set -eu
{
  . "$1/load_config.sh"
  . "$1/domains/${DOMAIN}.sh"
} 1>&2
for _v in $(compgen -v); do
  case ${_v} in _v|_r) continue ;; esac
  if [[ $(declare -p "${_v}" 2>/dev/null) =~ ^declare\ -[a-zA-Z]*a ]]; then
    declare -n _r=${_v}
    printf 'a\0%s\0%s\0' "${_v}" "${#_r[@]}"
    [ "${#_r[@]}" -eq 0 ] || printf '%s\0' "${_r[@]}"
    unset -n _r
  elif [[ ! $(declare -p "${_v}" 2>/dev/null) =~ ^declare\ -[a-zA-Z]*A ]]; then
    printf 's\0%s\0%s\0' "${_v}" "${!_v-}"
  fi
done
'''


class Config:
    """The settings, read with bash's ${NAME:-default} meaning: unset and empty are the same."""

    def __init__(self, scalars, arrays):
        self.scalars, self.arrays = scalars, arrays

    def __getitem__(self, name):
        """A setting that must be set (bash's set -u); it may still be empty."""
        if name not in self.scalars:
            sys.exit(f"ERROR: {name} is not set in the retro config")
        return self.scalars[name]

    def get(self, name, default=""):
        value = self.scalars.get(name, "")
        return value if value != "" else default

    def is_false(self, name):
        """True if the switch is FALSE; anything else, unset included, leaves it on."""
        return self.get(name, "TRUE") == "FALSE"

    def is_true(self, name):
        """True if the switch is TRUE; anything else, unset included, leaves it off."""
        return self.get(name, "FALSE") == "TRUE"

    def int(self, name, default):
        value = self.get(name, str(default))
        try:
            return int(value)
        except ValueError:
            sys.exit(f"ERROR: {name} must be a whole number, not '{value}'")

    def hours(self, name, default):
        """A space-separated list of hours, such as DET_COLD_START_HRS="03 15", as ints."""
        return [int(h) for h in self.get(name, default).split()]

    def array(self, name):
        return self.arrays.get(name, [])


def load_config(defs_dir):
    proc = subprocess.run(["bash", "-c", _DUMP, "load_config", defs_dir], stdout=subprocess.PIPE)
    if proc.returncode:
        sys.exit(proc.returncode)
    fields = proc.stdout.decode().split("\0")
    scalars, arrays, i = {}, {}, 0
    while i < len(fields) - 1:
        kind, name = fields[i], fields[i + 1]
        if kind == "s":
            scalars[name] = fields[i + 2]
            i += 3
        else:
            n = int(fields[i + 2])
            arrays[name] = fields[i + 3:i + 3 + n]
            i += 3 + n
    return Config(scalars, arrays)


def package_home(cfg, defs_dir):
    """PACKAGEHOME, by default the clone this script is in."""
    return cfg.get("PACKAGEHOME", os.path.normpath(os.path.join(defs_dir, "..", "..", "..")))
