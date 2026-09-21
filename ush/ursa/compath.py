#!/usr/bin/env python3
# Copy of prod_util 2.1.1 compath.py for Ursa: the WCOSS2 COM aliases are only used when /lfs/h1
# exists, instead of exiting, so paths resolve from $COMPATH and $COMROOT (see ecf/include/envir-p1.h).

# Purpose: Given the relative path of a COM directory, return the corresponding absolute
#          path. For COMIN paths, a search is performed in the following order:
#              1. the COMPATH variable in an envir-insensitive manner
#              2. the COM path list in an envir-sensitive manner
#              3. the production paths - success if only one match is found
#          For COMOUT directories ('-o' flag), the COMROOT variable is prepended to the
#          provided relative COM path.
# Usage:   compath [-o] [-e envir] [-v] relpath
#              where relpath may contain $NET/$ver, $NET/$ver/$envir, $NET/$ver/$envir/$RUN, or
#              $NET/$ver/$envir/$RUN.$PDY.
# Input:   /lfs/h1/ops/${envir}/config/compaths.list files, where $envir is retrieved from one of the
#          following (in order of decreasing precedence):
#              1. the command line '-e' or '--envir' switch
#              2. the input path (e.g. test/gfs/gfs.20160301 would use the
#                 test/config/comroot.list file)
#              3. the $envir environment variable
#              4. "prod"

from os import path, environ, getenv, system
from sys import exit, stderr
import re
from functools import partial

def err_exit(msg):
#    if __name__ == "__main__":
#        system('err_exit "[compath] ' + msg + '"')
#    else:
    print(msg, file=stderr)
    exit(1)

if path.exists('/lfs/h1'):
    com_aliases = { # use "<envir>" to include environment in path
        '/comh1': '/lfs/h1/ops/<envir>/com',
        '/comh2': '/lfs/h2/ops/<envir>/com',
    }
else:
    com_aliases = {}

# STRUCTURE: <envir>/<com>/<NET>/<version>/<RUN><...>
# NET and version are required
parse_compath = re.compile(r'(?P<envir>prod|para|test|canned)?/?(com/)?(?P<NET>[\w-]+)/(?P<version>v\d+\.\d+[^/]*)((?:/(?P<RUN>[\w-]+?)(?:\.(?P<PDY>2\d(?:\d\d){1,4}))?)?)?$')
parse_compath_var = re.compile(r'(/lfs/[hf][0-9]/ops/)?(?P<envir>prod|para|test|canned)?/?(com/)?(?P<NET>[\w-]+)(/?P<version>v\d+\.\d+[^/]*)?((?:/(?P<RUN>[\w-]+?)(?:\.(?P<PDY>2\d(?:\d\d){1,4}))?)?)?$')

# Function that returns a dictionary containing the NET, envir, RUN, and PDY parts of dirpath
def getparts(dirpath, iscompathvar=False):
    if iscompathvar: match_result = parse_compath_var.search(dirpath)
    else: match_result = parse_compath.search(dirpath)
    if match_result:
        dirdict = match_result.groupdict()
        dirdict['path'] = dirpath
        return dirdict
    else:
        print("WARNING: A member of the COM path list (" + dirpath + ") is not formatted correctly", file=stderr)
        return {'path': dirpath}

# Function to search for a path in a list of paths.  First, the full length will
# be searched. Then, increasingly shorter paths (with the rightmost segment removed,
# delimited by slashes and periods) will be searched until nothing is left.
def findpath(relpath_parts, dirlist_parts, envir_sensitive=True):
    pathpart_names = ('NET', 'version', 'RUN', 'PDY')
    pathpart_count = 0
    for part_name in pathpart_names:
        if relpath_parts[part_name]:
            pathpart_count += 1
        else:
            # If the pathpart is not defined for the relpath, remove all directories
            # from the dirlist where it is defined
            dirlist_parts[:] = [dir_parts for dir_parts in dirlist_parts if not dir_parts.get(part_name)]

    # Start looking at all of the significant path parts, then take one away, etc...
    for num_pathparts in range(pathpart_count, 0, -1):
        if relpath_parts[pathpart_names[num_pathparts-1]] == None:
            continue
        # Check each absolute path for a match
        for dir_parts in dirlist_parts:
            foundmatch = True
            for part in pathpart_names[0:num_pathparts]:
                # If the path part is defined in the relative path but not the absolute path, skip it for now
                if dir_parts.get(part) == None:
                    foundmatch = False
                    break
                # If the path part is defined in both the relative and absolute path but they don't match,
                # remove the absolute path from the list
                elif relpath_parts[part] != dir_parts[part] and (part != 'envir' or envir_sensitive):
                    foundmatch = False
                    dir_parts.clear()
                    break
            if foundmatch:
                match_pathparts = [ dir_parts['path'] ]
                for part in pathpart_names[num_pathparts:pathpart_count]:
                    match_pathparts.append('.' if part == 'PDY' else '/')
                    match_pathparts.append(relpath_parts[part])
                if relpath_parts['tail']:
                    match_pathparts.append(relpath_parts['tail'])
                return ''.join(match_pathparts)

def get_compath(relpath, envir=None, out=False, verbose=False):
    """!Returns the absolute path of the production COM directory represented
    by the provided relative path.

    @param relpath: The relative path of the COM directory desired.
    @param envir:   Environment of the COM paths list to use (default: $envir
                    environment variable).
    @param out:     Whether to return the location for a COMOUT (out=True) or
                    COMIN (out=False) directory.
                    COMOUT directories will always point to the current system.
    @param verbose: Whether to print the source of the returned COMROOT path to
                    stderr.
    @returns        A string containing the absolute path of the desired
                    production COM directory.
    """

    relpath = re.sub("(/v\d+\.\d+)[\d\.]*",r"\1",relpath) # chop version number down to first 2 digits

    match_result = re.match(r'(?P<envir>prod|para|test|canned)?/?(?:com/)?(?P<NET>[\w-]+)/(?P<version>v\d+\.\d+[^/]*)((?:/(?P<RUN>[\w-]+?)(?:\.(?P<PDY>2\d(?:\d\d){1,4}))?)?(?P<tail>/.+)?)?$', relpath)
    if match_result:
        relpath_parts = match_result.groupdict()
        if envir == None:
            envir = relpath_parts['envir'] if relpath_parts['envir'] else getenv('envir', 'prod')
    else:
        err_exit('The relative COM path provided (' + relpath + ') is not formatted correctly.')

    foundpath = None

    # If we are looking for a COMOUT path, use the COMROOT variable
    if out:
        try:
            foundpath = environ['COMROOT'] + '/' + relpath
            if verbose and foundpath:
                print("COMOUT path found using $COMROOT environment variable", file=stderr)
        except KeyError:
            err_exit('$COMROOT is not defined. Please define it or load the prod_envir module.')

    # Search the COMPATH environment variable for an appropriate match
    # The matching done in this case is envir-insensitive, meaning that a relpath
    # will match with directories in the dirlist from a different environment
    if not foundpath:
        compath_var = getenv('COMPATH')
        if compath_var:
            # Split COMPATH by colons and commas
            var_dirlist = [ s.strip().rstrip('/') for s in re.split(r':|,', compath_var) ]
            for i in range(len(var_dirlist)):
                for key in com_aliases.keys():
                    var_dirlist[i] = re.sub(f"^{key}",com_aliases[key],var_dirlist[i])
                env = re.findall("/(prod|para|test)/",compath_var)
                if env:
                    var_dirlist[i] = re.sub("/com/(prod|para|test)/","/com/",var_dirlist[i])
                    var_dirlist[i] = re.sub("<envir>",env[0],var_dirlist[i])
            getparts_func = partial(getparts, iscompathvar=True)
            var_dirlist_parts = list(map(getparts_func, var_dirlist))
            foundpath = findpath(relpath_parts, var_dirlist_parts, envir_sensitive=False)
            if verbose and foundpath:
                print("COMIN path found in $COMPATH environment variable", file=stderr)
        else:
            foundpath = None

    # Search the compaths list file for an appropriate match
    if not foundpath:
        compaths_filename = "/lfs/h1/ops/%s/config/compaths.list"%envir
        try:
            with open(compaths_filename, 'r') as compaths_list:
                file_dirlist = [line.strip().rstrip('/') for line in compaths_list if line and not line.startswith('#')]
            file_dirlist_parts = list(map(getparts, file_dirlist))
            foundpath = findpath(relpath_parts, file_dirlist_parts)
            if verbose and foundpath:
                print("COMIN path found in", compaths_filename, file=stderr)
        except IOError as err:
            print("WARNING: Could not find the", envir, "COM paths list at", err.filename, file=stderr)

    # Search the available COM directories.  If only one path is found, return it.
    if not foundpath:
        possible_paths = list()
        pathenvir = getparts(relpath)["envir"]
        if args.envir is None:
            envir = pathenvir
            relpath = re.sub(f"^{envir}/(com/)?","",relpath)
        for dir in set(com_aliases.values()):
            try: dir = dir.replace("<envir>",envir)
            except: pass
            fullpath = dir + '/' + relpath
            if path.exists(fullpath): possible_paths.append(fullpath)
        if len(possible_paths) == 1:
            foundpath = possible_paths[0]
            if verbose and foundpath:
                print("COMIN path found searching through the system COM paths", file=stderr)
    if foundpath:
        # Replace the matching alias (if an alias was used in the found path) in
        # com_aliases with its corresponding full path
        if com_aliases:
            pattern = re.compile("^(?:%s)(?=/)" % '|'.join(map(re.escape, com_aliases.keys())))
            foundpath = pattern.sub(lambda x: com_aliases[x.group()], foundpath, 1)

        # Print the absolute COM path
        return foundpath.replace("<envir>",envir)
    else:
        err_exit('Could not find ' + relpath)

if __name__ == "__main__":
    import argparse
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Given the relative path of a COM directory, return the corresponding absolute path according to where the data is located.')
    parser.add_argument('-o', '--out', action='store_true', help='Return a COMOUT directory')
    parser.add_argument('-e', '--envir', metavar='envir', choices=('prod', 'para', 'test', 'canned'), help='Environment of the COM paths list to use (default: $envir environment variable if set, otherwise prod)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Print the source of the returned COMROOT path to stderr')
    parser.add_argument('path', metavar='relpath', help='Relative com path; must include version number starting with "v"')
    args = parser.parse_args()

    # Parse the relative path provided as input
    print(get_compath(args.path.strip(), args.envir, args.out, args.verbose))

