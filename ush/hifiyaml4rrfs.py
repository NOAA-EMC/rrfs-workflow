# ------------------------------
#  Guoqing.Ge@noaa.gov, Aug. 31st, 2025
# ------------------------------
import re
import sys


# load a YAML file
def load(fpath, replacements=None):
    # precompile regex to match @VAR@
    pattern = re.compile(r"@(\w+)@")

    data = []
    with open(fpath, 'r') as infile:
        for line in infile:
            line = line.rstrip()  # strip all trailing empty spaces
            if replacements:
                line = pattern.sub(lambda m: replacements.get(m.group(1), m.group(0)), line)
            data.append(line)
    return data


# convert a multi-line f-string to a hifiyaml block (a list of lines)
def text_to_yblock(text):
    return text.splitlines()


# print information for debugging purpose
def printd(*parms):
    msg = " ".join(str(p) for p in parms)
    sys.stderr.write(msg + "\n")


# strip the indetation of a given string, and return the leading space information
def strip_indentations(ystr):
    org_len = len(ystr)
    ystr = ystr.lstrip(' ')
    new_len = len(ystr)
    nspace = org_len - new_len
    spaces = ' ' * nspace
    return nspace, spaces, ystr.strip()


# strip any leading empty lines in a YAML block
# non-leading empty lines are intact,
# some may use trailing empty lines to increaset readability
def strip_leading_empty_lines(block):
    while block and block[0] == "":
        block.pop(0)


# dedent a YAML block
def dedent(block):
    # find the first non-comment line (comment indentations are often inconsistent,
    #   so we cannot rely on the comment lines to find the block indentation)
    pos = -1
    for i in range(len(block)):
        if not block[i].strip().startswith("#"):
            pos = i
            break
    if pos == -1:
        return  # no action for a block of all comment lines

    nspaceBlock = strip_indentations(block[pos])[0]
    if nspaceBlock > 0:
        for i in range(0, len(block)):
            nspace = strip_indentations(block[i])[0]
            if nspace < nspaceBlock:
                block[i] = block[i][nspace:]
            else:
                block[i] = block[i][nspaceBlock:]


# find the YAML block position of next peer or next ancestor
# querystr="" to provide backward compatibility
#   if querystr ends with ".../0/key" and "key" is in the first line
#   we need to find the next_pos based on ".../key" instead of ".../0"
def next_pos(data, pos, querystr=""):
    if pos == -1:
        return len(data)
    query_list = querystr.strip("/").split("/")

    line1 = data[pos]
    nspace, spaces, line1 = strip_indentations(line1)
    if len(query_list) >=2 and query_list[-2].isdigit() and not query_list[-1].isdigit():
        # i.e, the ".../0/key" situation
        # more complicated situations, such as a list of list (of list ...)
        # are suggested to be handled based on the first list block outside hifiyaml
        line1 = line1[2:]  # assume "- " instead of "-   " or even more spaces
        nspace += 2
        spaces += "  "

    end = len(data)
    next_pos = None
    for i in range(pos + 1, end):
        line2 = data[i]
        nspace2, spaces2, line2 = strip_indentations(line2)
        if not line2 or line2.startswith("#"):
            pass  # ignore empty lines and comment lines when finding the positions
        elif nspace2 == nspace:  # next peer, i.e. the same indentation level
            if line1.startswith("- "):  # if the querystr block is a list element, next peer will certainly be "- "
                next_pos = i
                break
            else:  # if the querystr is NOT a list element, next peer should NOT be inconsistently-indented "- "
                if not line2.startswith("- "):
                    next_pos = i
                    break
        elif nspace2 < nspace:  # next ancestor, i.e parental indentation level
            next_pos = i
            break

    if next_pos is None:
        next_pos = end
    else:
        # check if there are comment lines immediately before next_pos
        # if yes, move next_pos back until a non-comment line
        for i in range(next_pos - 1, pos, -1):
            if data[i].strip().startswith('#'):
                next_pos = i
            else:
                break

    return next_pos


# get the start postion of a YAML block specificed by a querystr or linestr
#    eg: querystr = "cost function/background error/components/1/convariance/members from template"
#        linestr = "- filter: Temporal Thinning" # to find a line contains this linestr
def get_start_pos(data, querystr="", ignore_error=False, linestr=""):
    errmsg = None
    if querystr:
        query_list = querystr.strip("/").split("/")   # strip leading and trailing / and then split
    else:
        if not linestr:  # linestr only takes effect when querystr="" and if linestr="", return
            return -1, None
        else:  # if linestr presents, create a placeholder querylist
            query_list = ["place:holder:query:list:longmont:colorado:USA"]

    cur = 0
    end = len(data)

    for s in query_list:
        found = False
        for i in range(cur, end):
            line = data[i].strip()
            if s.isdigit():  # search for [ or -
                line = re.sub(r'(["\']).*?\1', r'\1\1', line)  # remove all contents inside quotes
                if "[" in line:
                    errmsg = "!! Directly modfiying [....] needs further development !!"
                    if not ignore_error:
                        sys.stderr.write(f"{errmsg}\n")
                        sys.exit(1)
                elif "- " in line:
                    nextpos = i
                    knt = int(s)
                    for j in range(0, knt):
                        nextpos = next_pos(data, nextpos, querystr)
                    cur = nextpos
                    found = True
                    break

            else:  # dictionary key or linestr
                if (linestr and linestr in data[i]) or f"{s}:" in line:
                    cur = i
                    found = True
                    break
        if not found:
            errmsg = f"key error: '{s}' not found\n"
            if not ignore_error:
                sys.stderr.write(f"{errmsg}\n")
                sys.exit(1)
    # ~~~~~~~~~~~~~~~~~
    return cur, errmsg


# get the content of a YAML block referred to by a querystr
def get(data, querystr, do_dedent=True):
    block = []
    if querystr == "":  # empty querystr, so dump the full YAML data
        pos1 = 0
        pos2 = len(data)
    else:
        pos1, _ = get_start_pos(data, querystr)
        pos2 = next_pos(data, pos1, querystr)

    # get the number of indentation spaces
    nspace = strip_indentations(data[pos1])[0]

    # check if there are comments immediately before this YAML block
    for i in range(pos1 - 1, -1, -1):
        if data[i].strip().startswith('#'):
            pos1 = i
        else:
            break  # exit the loop if non-comment

    block = data[pos1:pos2]
    if do_dedent:
        dedent(block)
    return block


# dump the content of a YAML block referred to by a querystr
def dump(data, querystr="", fpath=None):
    if fpath is not None:
        outfile = open(fpath, 'w')
    block = get(data, querystr)  # dedented YAML block by default
    for line in block:
        if fpath is None:
            print(line)
        else:
            outfile.write(line + '\n')


# drop a YAML block specificed by a querystr
def drop(data, querystr):
    if querystr == "":
        return  # empty querystr, no drop action

    pos1, _ = get_start_pos(data, querystr)
    pos2 = next_pos(data, pos1, querystr)

    # check if there are comments immediately before this YAML block
    for i in range(pos1 - 1, -1, -1):
        if data[i].strip().startswith('#'):
            pos1 = i
        else:
            break  # exit the loop if non-comment

    del data[pos1:pos2]


# modify a YAML bock specified by a querystr with a newblock
def modify(data, querystr, newblock):
    if isinstance(newblock, str):  # if newblock is a string, convert it to a list
        newblock = [newblock]

    if querystr == "":  # empty querystr means the whole document
        return         # in this situation, hifiyaml is not needed

    # get the "querystr" YAML block start position and (end_postion+1)
    pos1, _ = get_start_pos(data, querystr)
    pos2 = next_pos(data, pos1, querystr)

    # get the number of indentation spaces in the "querystr" YAML block
    nspace, spaces, _ = strip_indentations(data[pos1])

    # check if there are comments immediately before the "querystr" YAML block
    for i in range(pos1 - 1, -1, -1):
        if data[i].strip().startswith('#'):
            pos1 = i
        else:
            break  # exit the loop if non-comment

    # strip any possible leading empty lines in the newblock
    strip_leading_empty_lines(newblock)
    # dedent the newblock to the root indentation level
    dedent(newblock)
    # align the newblock indentations to match the querystr block
    if nspace > 0:
        for i, line in enumerate(newblock):
            newblock[i] = spaces + line

    data[pos1:pos2] = newblock
