# ---------------------------------------------------------------------------
# yamltools for RRFSv2 super YAML files: |
#   may be adapted for applications other than RRFSv2
#   Aug. 31st, 2025
# --------------------------------------------------------------------------
#
import hifiyaml as hy
import os
import shutil


# get all filters given a line range(pos1, pos2)
def get_all_filters(data, pos1, pos2):
    filters = []
    cur = pos1

    while cur < pos2:
        for i in range(cur, pos2):
            if "- filter:" in data[i] and not data[i].strip().startswith("#"):
                cur = i
                break

        category = data[cur].split(":")[1].strip()
        next_one = hy.next_pos(data, cur)

        # check if there are matching comments immediately before this YAML block
        nspace = hy.strip_indentations(data[cur])[0]
        for i in range(cur - 1, -1, -1):
            nspace2, _, line = hy.strip_indentations(data[i])
            if nspace2 == nspace and line.startswith('#'):
                cur = i
            else:
                break  # exit the loop if not a comment or different indentation level

        # ~~~~~~~~~~~~~~
        # get the whole block of an obs filter
        dcFilter = {
            "category": category,
            "pos1": cur,
            "pos2": next_one,
            "block": [],
        }
        for i in range(cur, next_one):
            dcFilter["block"].append(data[i])

        filters.append(dcFilter)
        cur = next_one

    return filters


# get all observers of a JEDI YAML file
def get_all_obs(data):
    dcObs = {}
    cur = 0
    end = len(data)

    while cur < end:
        for i in range(cur, end):
            if "- obs space:" in data[i]:
                cur = i
                break

        name = data[cur + 1].split(":")[1].strip()  # "name:" is expected to follow "- obs space:"
        tmp = name.split("_")
        if len(tmp) > 1:
            sname = tmp[1].strip()
        else:
            sname = name

        next_one = hy.next_pos(data, cur)

        # check if there are matching comments immediately before this YAML block
        nspace = hy.strip_indentations(data[cur])[0]
        for i in range(cur - 1, -1, -1):
            nspace2, _, line = hy.strip_indentations(data[i])
            if nspace2 == nspace and line.startswith('#'):
                cur = i
            else:
                break  # exit the loop if not a comment or different indentation level

        # assemble one observer
        obs = {
            "name": name,
            "sname": sname,
            "pos1": cur,
            "pos2": next_one,
            "pre filters": {},
            "filters": {},
            "prior filters": {},
            "post filters": {},
            "block": [],
        }

        # get the whole block of an observer
        for j in range(cur, next_one):
            obs["block"].append(data[j])

        # assemble filters
        def assemble_filters(key):
            for i in range(cur, next_one):
                if f"obs {key}:" in data[i]:
                    pos1 = i
                    pos2 = hy.next_pos(data, pos1)
                    obs[key] = get_all_filters(data, pos1, pos2)
                    break
        assemble_filters("filters")
        assemble_filters("pre filters")
        assemble_filters("prior filters")
        assemble_filters("post filters")

        dcObs[name] = obs
        cur = next_one

    return dcObs


# write_out_filters
def write_out_filters(key, obs, obspath, clean_extra_indentations, filterlist):
    if obs[key]:
        first = obs[key][0]["block"][0]
        nspace = hy.strip_indentations(first)[0]  # get the extra number of indentations
        for i, dcFilter in enumerate(obs[key]):
            category = dcFilter["category"].replace(' ', '_')
            prefix = key.replace(' ', '')[:-1]
            fpath = f"{obspath}/{prefix}_{i:02}_{category}.yaml"
            filterlist.append(f"{prefix}_{i:02}_{category}.yaml")
            with open(fpath, 'w') as outfile:
                for line in dcFilter["block"]:
                    if clean_extra_indentations:
                        nspace2, _, line2 = hy.strip_indentations(line)
                        if nspace2 < nspace and line2.startswith("#"):  # indentation-inconsistent comment lines
                            line = line2
                        else:
                            line = line[nspace:]
                    outfile.write(line + "\n")


# split a super YAML files to individual observers/filters
def split(fpath, level=1, dirname=".", clean_extra_indentations=False):
    data = hy.load(fpath)
    basename = os.path.basename(fpath)
    # dirname is the top level of the split results, default to current directory
    dirname.rsplit("/")  # remove trailing /  if any
    toppath = f"{dirname}/split.{basename}"

    # if the dir exists, find an available dir name to backup old files first
    if os.path.exists(toppath):
        knt = 1
        savedir = f'{toppath}_old{knt:04}'
        while os.path.exists(savedir):
            knt += 1
            savedir = f'{toppath}_old{knt:04}'
        shutil.move(toppath, savedir)
    os.makedirs(toppath, exist_ok=True)

    # write head.yaml
    yhead_end = hy.get_start_pos(data, "cost function/observations/observers")
    with open(f'{toppath}/head.yaml', 'w') as outfile:
        for i in range(yhead_end + 1):
            outfile.write(data[i] + '\n')

    # write observers ( and filters if split level = 2 )
    dcObs = get_all_obs(data)
    with open(f"{toppath}/obslist.txt", 'w') as outfile:
        for name in dcObs:
            outfile.write(f"{name}\n")

    if level == 1:  # split to individual observers (filters kept intact)
        for name, obs in dcObs.items():
            fpath = f"{toppath}/{name}.yaml"
            nspace = hy.strip_indentations(obs["block"][0])[0]  # get the extra number of indentations
            with open(fpath, 'w') as outfile:
                for line in obs["block"]:
                    if clean_extra_indentations:
                        nspace2, _, line2 = hy.strip_indentations(line)
                        if nspace2 < nspace and line2.startswith("#"):  # indentation-inconsistent comment lines
                            line = line2
                        else:
                            line = line[nspace:]
                    outfile.write(line + "\n")

    else:  # split to individual observers and filters
        for name, obs in dcObs.items():
            obspath = f"{toppath}/{name}"
            os.makedirs(obspath, exist_ok=True)

            # find the the end of the observer head
            for i in range(obs["pos1"], obs["pos2"]):
                if any(x in data[i] for x in ("obs filters:", "obs pre filters:", "obs prior filters:", "obs post filters:")):
                    ohead_end = i
                    break
            # write obshead.yaml
            with open(f"{obspath}/obshead.yaml", 'w') as outfile:
                nspace = hy.strip_indentations(obs["block"][0])[0]  # get the extra number of indentations
                for i in range(obs["pos1"], ohead_end + 1):
                    line = data[i]
                    if clean_extra_indentations:
                        nspace2, _, line2 = hy.strip_indentations(line)
                        if nspace2 < nspace and line2.startswith("#"):  # indentation-inconsistent comment lines
                            line = line2
                        else:
                            line = line[nspace:]
                    outfile.write(line + "\n")

            # write out filters
            filterlist = []
            write_out_filters("filters", obs, obspath, clean_extra_indentations, filterlist)
            write_out_filters("pre filters", obs, obspath, clean_extra_indentations, filterlist)
            write_out_filters("prior filters", obs, obspath, clean_extra_indentations, filterlist)
            write_out_filters("post filters", obs, obspath, clean_extra_indentations, filterlist)
            # write out filterlist.txt
            with open(f"{obspath}/filterlist.txt", 'w') as outfile:
                for item in filterlist:
                    outfile.write(f"{item}\n")


# align the indentation in data based on a target nspace, nIdent, listIndent settings.
def align_indentation(nspace, data, nIndent, listIndent):
    nspace2 = hy.strip_indentations(data[0])[0]
    extra_num_space = 0
    if nspace2 == nspace and listIndent:
        extra_num_space = nIndent
    elif nspace2 < nspace:
        extra_num_space = nspace - nspace2
        if listIndent:
            extra_num_space += nIndent
    elif nspace2 > nspace:
        extra_num_space = nspace - nspace2
        if listIndent:
            extra_num_space += nIndent
    #
    if extra_num_space >= 0:
        for i, line in enumerate(data):
            data[i] = ' ' * extra_num_space + line
    else:
        for i, line in enumerate(data):
            data[i] = line[extra_num_space:]


# pack individual observers, filters into one super YAML file
def pack(dirname, fpath, nIndent=2, listIndent=True, plain_pack=True):
    '''
dirname: the directory of split YAML files
fpath:   the target YAML file path
nIndent: how many spaces for changing indentation level
listIndent: whether to indent lists
plain_pack: ignore all indentation settings, pack as-is;
  it can replicate the original YAML file splitted with clean_extra_indentations=False
    '''
    # read obslist
    obslist = []
    with open(os.path.join(dirname, "obslist.txt"), 'r') as infile:
        for line in infile:
            if line.strip():
                obslist.append(line.strip())

    # check it is level1 or lelve2 split
    if os.path.isfile(os.path.join(dirname, f"{obslist[0]}.yaml")):
        level = 1
    elif os.path.isdir(os.path.join(dirname, f"{obslist[0]}")):
        level = 2
    else:
        print(f"Neither {obslist[0]}.yaml nor {obslist[0]}/ found")
        return

    if level == 1:
        data = hy.load(os.path.join(dirname, "head.yaml"))
        # check if the last line of head.yaml is "observers:"
        line = data[-1]
        if "observers:" not in line:
            print("The last line of head.yaml is not 'observers:'")
            return
        # assemble individual observers
        nspace = hy.strip_indentations(line)[0]
        for obsname in obslist:
            block = hy.load(os.path.join(dirname, f"{obsname}.yaml"))
            if not plain_pack:  # only aligh indentation for non plain_pack situation
                align_indentation(nspace, block, nIndent, listIndent)
            data.extend(block)
    else:
        data = hy.load(os.path.join(dirname, "head.yaml"))
        # check if the last line of head.yaml is "observers:"
        line = data[-1]
        if "observers:" not in line:
            print("The last line of head.yaml is not 'observers:'")
            return
        # assemble individual observers
        nspace = hy.strip_indentations(line)[0]
        for obsname in obslist:
            obs_block = hy.load(os.path.join(dirname, f"{obsname}/obshead.yaml"))
            # check if the last line of obshead.yaml is "filters:"
            line = obs_block[-1]
            nspace4flt = hy.strip_indentations(line)[0]
            if "filters:" not in line:
                print(f"The last line of {obsname}/obshead.yaml is not 'filters:'")
                return
            obs_block.pop()  # remove the last "filters:" line, we will add based on pre/prior/post/regular filters

            # read filterlist
            filterlist = []
            # use the "filter_type" dictionary to mark whether the corresponding key has been added
            filter_type = {
                "filter": [0, "obs filters:"],
                "prefilter": [0, "obs pre filters:"],
                "priorfilter": [0, "obs prior filters:"],
                "postfilter": [0, "obs post filters:"],
            }
            with open(os.path.join(dirname, f"{obsname}/filterlist.txt"), 'r') as infile:
                for line in infile:
                    if line.strip():
                        filterlist.append(line.strip())
            # assemble individual filters
            for fltfile in filterlist:
                flt_block = hy.load(os.path.join(dirname, f"{obsname}/{fltfile}"))
                if not plain_pack:
                    align_indentation(nspace4flt, flt_block, nIndent, listIndent)
                prefix = fltfile.split("_")[0]
                if filter_type[prefix][0] == 0:  # first time, need to add the corresponding filter key
                    obs_block.append(' ' * nspace4flt + filter_type[prefix][1])
                    filter_type[prefix][0] = 1
                obs_block.extend(flt_block)

            if not plain_pack:
                align_indentation(nspace, obs_block, nIndent, listIndent)
            data.extend(obs_block)

    # write out the super YAML file
    with open(fpath, 'w') as outfile:
        for line in data:
            outfile.write(line + "\n")
