# ------------------------------
# copied from https://github.com/hifiyaml/hifiyaml
# ------------------------------

import re

# load a YAML file
def load(fpath):
    data = []
    with open(fpath, 'r') as infile:
        for line in infile:
            line = line.rstrip()  # strip all trailing empty spaces
            data.append(line)
    return data


# convert a multi-line f-string to a hifiyaml block (a list of lines)
def text_to_yblock(text):
    return text.splitlines()


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
    newblock = []
    leading = True
    for line in block:
        if line.strip():
            leading = False
            newblock.append(line)
        else:
            if not leading:
                newblock.append(line)
    return newblock


# find the next line postion with the same or less indentation level
def next_pos(data, pos):
    if pos == -1:
        return len(data)

    line1 = data[pos]
    nspace, spaces, line1 = strip_indentations(line1)

    end = len(data)
    next_pos = None
    for i in range(pos + 1, end):
        line2 = data[i]
        nspace2, spaces2, line2 = strip_indentations(line2)
        if not line2 or line2.startswith("#"):
            pass  # ignore empty lines and comment lines
        elif nspace2 == nspace:  # the next same indentation level
            if line1.startswith("- "):
                next_pos = i
                break
            else:   # yaml is nice to allow not indenting '-', but it has to be indented internally
                if not line2.startswith("- "):
                    next_pos = i
                    break
        elif nspace2 < nspace:  # if no next same-indentation level, use the next less-indentation level
            next_pos = i
            break

    if next_pos is None:
        next_pos = end
    else:
        # check if there are same-level comments immediately before next_pos
        for i in range(next_pos - 1, -1, -1):
            nspacePrev, _, prev = strip_indentations(data[i])
            if nspacePrev == nspace2 and prev.startswith('#'):
                next_pos = i
            else:
                break

    # check if there are empty lines immediately before next_pos
    # (it looks like it is okay to have some empty lines for now)
    # for i in range(next_pos - 1, -1, -1):
    #    if data[i].strip():
    #        break
    #    else:
    #        next_pos = i

    return next_pos

# get the start postion of a YAML block specificed by a querystr,
#    eg: querystr = "cost function/background error/components/1/convariance/members from template"
def get_start_pos(data, querystr):
    if querystr:
        query_list = querystr.strip("/").split("/")   # strip leading and trailing / and then split
    else:
        return -1

    cur = 0
    end = len(data)
    for s in query_list:
        for i in range(cur, end):
            line = data[i].strip()
            if s.isdigit():  # search for [ or -
                line = re.sub(r'(["\']).*?\1', r'\1\1', line)  # remove all contents inside quotes
                if "[" in line:
                    print("!! Directly modfiying [....] needs further development !!")
                    exit()
                elif "- " in line:
                    nextpos = i
                    knt = int(s)
                    for j in range(0, knt):
                        nextpos = next_pos(data, nextpos)
                    cur = nextpos
                    break  # break the nest loop

            else:  # dictionary key
                if f"{s}:" in line:
                    cur = i
                    break  # break the nest loop
    # ~~~~~~~~~~~~~~~~~
    return cur


# get the content of a YAML block referred to by a querystr
def get(data, querystr):
    block = []
    pos1 = get_start_pos(data, querystr)
    pos2 = next_pos(data, pos1)
    if pos1 == -1:  # empty querystr, so dump the full YAML data
        pos1 = 0

    # get the number of indentation spaces
    nspace = strip_indentations(data[pos1])[0]

    # check if there are matching comments immediately before this YAML block
    for i in range(pos1 - 1, -1, -1):
        nspace2, _, line = strip_indentations(data[i])
        if nspace2 == nspace and line.startswith('#'):
            block.append(data[i][nspace:])
        else:
            break  # exit the loop if not a comment or different indentation level

    # copy the block referred to by the querystr
    for i in range(pos1, pos2):
        block.append(data[i][nspace:])

    return block


# dump the content of a YAML block referred to  by a querystr
def dump(data, querystr="", fpath=None):
    if fpath is not None:
        outfile = open(fpath, 'w')
    block = get(data, querystr)
    for line in block:
        if fpath is None:
            print(line)
        else:
            outfile.write(line+'\n')


# drop a YAML block specificed by a querystr and return the newdata
def drop(data, querystr):
    newdata = data.copy()  # no nesting in data, so shallow copy is enough
    pos1 = get_start_pos(data, querystr)
    if pos1 == -1:  # empty querystr, no drop action
        return

    pos2 = next_pos(data, pos1)

    # get the number of indentation spaces
    nspace = strip_indentations(data[pos1])[0]

    # check if there are matching comments immediately before this YAML block
    for i in range(pos1 - 1, -1, -1):
        nspace2, _, line = strip_indentations(data[i])
        if nspace2 == nspace and line.startswith('#'):
            pos1 = i
        else:
            break  # exit the loop if not a comment or different indentation level

    del (newdata[pos1:pos2])
    return newdata


# modify a YAML bock specified by a querystr with a newblock, return newdata
def modify(data, querystr, newblock):
    newdata = data.copy()  # no nesting in data, no shallow copy is enough
    pos1 = get_start_pos(data, querystr)
    if pos1 == -1:  # empty querystr, no modify action
        return

    pos2 = next_pos(data, pos1)

    # get the number of indentation spaces
    nspace, spaces, _ = strip_indentations(data[pos1])

    # check if there are matching comments immediately before this YAML block
    for i in range(pos1 - 1, -1, -1):
        nspace2, _, line = strip_indentations(data[i])
        if nspace2 == nspace and line.startswith('#'):
            pos1 = i
        else:
            break  # exit the loop if not a comment or different indentation level

    # strip any possible leading empty lines in newblock
    newblock = strip_leading_empty_lines(newblock)
    # align the newblock indentations to match the querystr block
    nspaceBlock = strip_indentations(newblock[0])[0]
    if nspaceBlock != nspace:
        for i, line in enumerate(newblock):
            newblock[i] = spaces + line.lstrip()

    newdata[pos1:pos2] = newblock
    return newdata
