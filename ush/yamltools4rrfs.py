# ---------------------------------------------------------------------------
# yamltools4jedi 0.2.4
# --------------------------------------------------------------------------
#
import hifiyaml4rrfs as hy
import os
import re
import shutil
import sys
import math


def list_to_delimited_string(lst, spaces='  ', delimiter=', ', elements_per_line=20):
    # Convert the list to a comma-separated string with the specified delimiter
    joined_string = delimiter.join(map(str, lst))
    # Split the joined string into chunks of elements_per_line
    elements = joined_string.split(delimiter)
    # Create lines of up to elements_per_line elements
    lines = [delimiter.join(elements[i:i + elements_per_line]) for i in range(0, len(elements), elements_per_line)]
    # Add a comma at the end of each line except the last line
    formatted_lines = [spaces + line + delimiter.rstrip(' ') if i < len(lines) - 1 else spaces + line for i, line in enumerate(lines)]
    # formatted_lines[0] = formatted_lines[0].lstrip(' ')
    return formatted_lines


# print information for debugging purpose
def printd(*parms):
    msg = " ".join(str(p) for p in parms)
    sys.stderr.write(msg + "\n")


def _first_yaml_content_index(data):
    return next((index for index, line in enumerate(data)
                 if line.strip() and not line.lstrip().startswith("#")), None)


# write a YAML block to a file with optional dedenting
def write_block(outfile, block, do_dedent, nspace):
    for line in block:
        if do_dedent:
            nspace2, _, line2 = hy.strip_indentations(line)
            if nspace2 < nspace and line2.startswith("#"):  # indentation-inconsistent comment lines
                line = line2
            else:
                line = line[nspace:]
        outfile.write(line + "\n")


# load the convinfo file, return dcConvInfo
def load_convinfo():
    dcConvInfo = {}
    if os.path.exists('convinfo'):
        with open('convinfo', 'r') as sfile:
            for line in sfile:
                if not line.strip().startswith("!"):
                    fields = line.split()
                    if len(fields) == 9:
                        atype = fields[0]
                        if fields[1] != '0':
                            atype += fields[1].zfill(3)
                        if fields[2] != '0':
                            atype += "_" + fields[2].zfill(3)
                        #
                        dcTMP = {
                            'iuse': fields[3],
                            'twindow': fields[4],
                            'gross': fields[5],
                            'ermax': fields[6],
                            'ermin': fields[7],
                            'msgtype': fields[8],
                        }
                        dcConvInfo[atype] = dcTMP
                    else:
                        sys.stderr.write(f"read_convinfo Warning: expected 9 fields\n{line}\n")
    return dcConvInfo


# load the satinfo file, return dcSatInfo
def load_satinfo():
    dcSatInfo = {}
    if os.path.exists('satinfo'):
        with open('satinfo', 'r') as sfile:
            for line in sfile:
                if not line.strip().startswith("!"):
                    fields = line.split()
                    if len(fields) == 11:
                        sis = fields[0]  # sensor/instr/sat
                        if sis in dcSatInfo:
                            dcSIS = dcSatInfo[sis]
                        else:
                            dcSIS = {'channels': [], 'use_flag': [], 'error0': [], 'error1': [], 'obserr_bound_max': [],
                                     'var_b': [], 'var_pg': [], 'use_flag_clddet': [], 'icloud': [], 'iaerosol': [],
                                     }
                        #
                        dcSIS['channels'].append(fields[1])           # chan
                        dcSIS['use_flag'].append(fields[2])           # iuse
                        dcSIS['error0'].append(fields[3])             # error
                        dcSIS['error1'].append(fields[4])             # error_cld
                        dcSIS['obserr_bound_max'].append(fields[5])   # ermax
                        dcSIS['var_b'].append(fields[6])              # var_b
                        dcSIS['var_pg'].append(fields[7])             # var_pg
                        dcSIS['use_flag_clddet'].append(fields[8])    # icld_det
                        dcSIS['icloud'].append(fields[9])             # iclould
                        dcSIS['iaerosol'].append(fields[10])          # iaerosol
                        dcSatInfo[sis] = dcSIS
                    else:
                        sys.stderr.write(f"load_satinfo warning: expected 11 fields\n{line}\n")
    return dcSatInfo


# load cloudy_radiance_info
def load_cloudy_radiance_info():
    dcCldRadInfo = {}
    if os.path.exists('cloudy_radiance_info'):
        with open('cloudy_radiance_info', 'r') as crfile:
            insideBlock = False
            for line in crfile:
                line = line.strip()
                if line.startswith("!"):  # skip comment lines
                    continue
                elif "::" in line:  # start or end of a block
                    if insideBlock:
                        insideBlock = False  # end of the current block
                    else:
                        insideBlock = True  # start of a new block
                        if line.startswith("obs"):
                            obstype = line[:-2].split("_")[1]
                        else:
                            obstype = None
                elif insideBlock:
                    if obstype is not None:
                        fields = line.split()
                        if len(fields) == 3 or len(fields) == 4:
                            chan = fields[0]
                            cclr = fields[1]  # CCLR, cloud amount for cleary sky
                            ccld = fields[2]  # CCLD, cloud amount for cloudy sky
                            cldval1 = fields[3] if len(fields) == 4 else None  # optional cldval1 for gmi and amsr2
                            if obstype not in dcCldRadInfo:
                                dcCldRadInfo[obstype] = {}
                            dcCldRadInfo[obstype][chan] = {"cldamt_x0": cclr, "cldamt_x1": ccld, "cldval1": cldval1}
                        else:
                            sys.stderr.write(f"load_cloudy_radiance_info warning: expected 3 fields\n{line}\n")
    return dcCldRadInfo


# determine the number of elements per line for formatting purposes
def determine_elements_per_line(n):
    target = 10 if n < 100 else 20
    nlines = max(1, round(n / target))
    return math.ceil(n / nlines)


# generate one satellite anchor block (yaml-ready anchor section for a given SIS)
def generate_sat_anchor(dcSatInfo, mysis, anchor_cat, spaces=""):
    pre_spaces = spaces + "    "  # add extra 4 spaces for anchor values
    elements_per_line = determine_elements_per_line(len(dcSatInfo[mysis][anchor_cat]))
    block = list_to_delimited_string(dcSatInfo[mysis][anchor_cat], pre_spaces, elements_per_line=elements_per_line)
    # insert the first anchor information line
    block.insert(0, f"{spaces}_anchor_{anchor_cat}: &{mysis}_{anchor_cat}")
    if anchor_cat != "channels":  # channels is a string while others are lists
        block[0] = block[0] + " ["
        block[len(block) - 1] = block[len(block) - 1] + "]"
    return block


# update one satellite anchor
# Expected anchor line format: _anchor_<cat>: &<sis>_<cat>
#   e.g., _anchor_channels: &amsua_n15_channels
def update_sat_anchor(data, dcSatInfo, anchor):
    anchor_cat = anchor[8:]  # anchor category: channels, use_flag, use_flag_clddet, error0, error1, obserr_bound_max
    pos1, errmsg = hy.get_start_pos(data, anchor, stop_on_error=False)
    if errmsg is not None:  # if "_anchor" does not exisit, just return
        return
    pos2 = hy.next_pos(data, pos1)

    _, spaces, line = hy.strip_indentations(data[pos1])
    # Extract SIS id from anchor format: _anchor_<cat>: &<sis>_<cat>
    match = re.search(r'&(.+)_' + re.escape(anchor_cat) + r'\b', line)
    if match:
        mysis = match.group(1)
    else:
        sys.stderr.write(f"WARNING: cannot parse SIS from anchor line: {line}\n")
        return
    data[pos1:pos2] = generate_sat_anchor(dcSatInfo, mysis, anchor_cat, spaces)


# update satellite anchors
def update_sat_anchors(data, dcSatInfo):
    update_sat_anchor(data, dcSatInfo, "_anchor_channels")
    update_sat_anchor(data, dcSatInfo, "_anchor_use_flag")
    update_sat_anchor(data, dcSatInfo, "_anchor_use_flag_clddet")
    update_sat_anchor(data, dcSatInfo, "_anchor_error0")
    update_sat_anchor(data, dcSatInfo, "_anchor_error1")
    update_sat_anchor(data, dcSatInfo, "_anchor_obserr_bound_max")


# Generate satellite anchors
def generate_sat_anchors(dcSatInfo, mysis, spaces=""):
    text = ""
    for anchor_cat in ["channels", "use_flag", "use_flag_clddet", "error0", "error1", "obserr_bound_max"]:
        block = generate_sat_anchor(dcSatInfo, mysis, anchor_cat, spaces)
        text += "\n".join(block) + "\n"
    return text


# generate cldamt anchor blocks (yaml-ready anchor sections for a given SIS)
def generate_cldamt_anchors(dcSatInfo, dcCldRadInfo, mysis, obstype, spaces=""):
    pre_spaces = spaces + "    "  # add extra 4 spaces for anchor values
    elements_per_line = determine_elements_per_line(len(dcSatInfo[mysis]["channels"]))
    # cldamt clear and cloudy (x0 and x1)
    list_clear, list_cloudy = [], []
    for chan in dcSatInfo[mysis]["channels"]:
        if chan in dcCldRadInfo[obstype]:
            list_clear.append(dcCldRadInfo[obstype][chan]["cldamt_x0"])
            list_cloudy.append(dcCldRadInfo[obstype][chan]["cldamt_x1"])
        else:
            list_clear.append("0.000")
            list_cloudy.append("0.000")
    block_clear = list_to_delimited_string(list_clear, pre_spaces, elements_per_line=elements_per_line)
    block_cloudy = list_to_delimited_string(list_cloudy, pre_spaces, elements_per_line=elements_per_line)
    # clear sky
    block_clear.insert(0, f"{spaces}_anchor_cldamt_x0: &{mysis}_cldamt_x0")
    block_clear[0] = block_clear[0] + " ["
    block_clear[len(block_clear) - 1] = block_clear[len(block_clear) - 1] + "]"
    # cloudy sky
    block_cloudy.insert(0, f"{spaces}_anchor_cldamt_x1: &{mysis}_cldamt_x1")
    block_cloudy[0] = block_cloudy[0] + " ["
    block_cloudy[len(block_cloudy) - 1] = block_cloudy[len(block_cloudy) - 1] + "]"
    text = "\n".join(block_clear + block_cloudy) + "\n"
    return text


# tweak observers for getkf solver or post:
#  1. if solver, change the distribution from RoundRobin to Halo
#  2. transfer the obsdataout obsfile to obsdatain
#  3. if post, remove the "reduce obs space" actions and "temporal thinning" filters
#
# WARNING: This function modifies `data` IN-PLACE.
#   You MUST pass the actual list object, NOT a slice.
#   A slice like data[i:j] creates a COPY — mutations won't propagate back.
def getkf_observer_tweak(data, getkf_type):
    if getkf_type == "solver":  # solver cannot use RoundRobin
        for i in range(0, len(data)):
            if "RoundRobin" in data[i]:
                data[i] = data[i].replace("RoundRobin", "Halo")

    # transfer the obsdataout obsfile to obsdatain
    pos, _ = hy.get_start_pos(data, "obsdataout/engine/obsfile")
    diagfile = data[pos].split(":")[1].strip()
    pos, _ = hy.get_start_pos(data, "obsdatain/engine/obsfile")
    spaces = hy.strip_indentations(data[pos])[1]
    data[pos] = f"{spaces}obsfile: data/jdiag/{diagfile}"

    # if post, remove the "reduce obs space" actions and "temporal thinning" filters
    if getkf_type == "post":
        i = 0
        while i < len(data) - 1:
            if (data[i].strip().startswith("action:") and data[i + 1].strip().startswith("name: reduce obs space")):
                del data[i:i + 2]  # delete and move to the next line
            else:
                i += 1  # if no deletion, move to the next line

        # remove the "- filter: Temporal Thinning" block
        # assume only one of this filter in each observer
        pos, errmsg = hy.get_start_pos(data, linestr="- filter: Temporal Thinning", stop_on_error=False)
        if errmsg is None and not data[pos].strip().startswith("#"):  # do nothing if not found or commented out
            next_one = hy.next_pos(data, pos)
            # check if there are comment lines immediately before this YAML block and with less or the same indentations
            nspace = hy.strip_indentations(data[pos])[0]
            for i in range(pos - 1, -1, -1):
                nspace2 = hy.strip_indentations(data[i])[0]
                if data[i].strip().startswith('#') and nspace2 <= nspace:
                    pos = i
                else:
                    break  # exit the loop if non-comment
            del data[pos:next_one]


# get all filters given a line range(pos1, pos2)
def get_all_filters(data, pos1, pos2):
    filters = []
    cur = pos1

    while cur < pos2:
        for i in range(cur, pos2):
            found = False
            if "- filter:" in data[i] and not data[i].strip().startswith("#"):
                cur = i
                found = True
                break

        # if no more "- filter:" found, break the while loop
        if not found:
            break

        category = data[cur].split(":")[1].strip()
        next_one = hy.next_pos(data, cur)

        # check if there are leading comment lines before this YAML block and with less indentation
        nspace = hy.strip_indentations(data[cur])[0]
        for i in range(cur - 1, -1, -1):
            nspace2, _, line = hy.strip_indentations(data[i])
            if nspace2 <= nspace and line.startswith('#'):
                cur = i
            else:
                break  # exit the loop if not a comment or different indentation level

        # ~~~~~~~~~~~~~~
        # get the whole block of an obs filter
        dcFilter = {
            "category": category,
            "identifier": "",
            "pos1": cur,
            "pos2": next_one,
            "block": [],
        }
        dcFilter["block"].extend(data[cur:next_one])

        identifier_pos, error = hy.get_start_pos(dcFilter["block"], "identifier/name", stop_on_error=False)
        if error is None:
            dcFilter["identifier"] = dcFilter["block"][identifier_pos].split(":", 1)[1].strip()

        filters.append(dcFilter)
        cur = next_one

    return filters


# get all observers of a JEDI YAML file, return dcObs
def get_all_obs(data, shallow=False):
    dcObs = {}
    cur = 0
    end = len(data)

    while cur < end:
        found = False
        for i in range(cur, end):
            if "- obs space:" in data[i]:
                cur = i
                found = True
                break

        # if no more "- obs space:" found, break the while loop
        if not found:
            break

        # find the "name:" line (skip any comments or blank lines after "- obs space:")
        name = None
        for ni in range(cur + 1, min(cur + 10, end)):  # search for "name:" within the next 10 lines
            stripped = data[ni].strip()
            if stripped.startswith('#') or not stripped:
                continue
            if stripped.startswith('name:'):
                name = data[ni].split(":", 1)[1].strip()
                break
        if name is None:
            name = f"unknown_obs_at_line_{cur}"
        next_one = hy.next_pos(data, cur)

        # check if this is a satellite radiance observer
        is_sat_radiance = False
        for i in range(cur, next_one):
            if "name: CRTM" in data[i]:
                is_sat_radiance = True
                break

        # get the shortest observer name
        tmp = name.split("_", 1)
        if len(tmp) > 1 and not is_sat_radiance:
            sname = tmp[1].strip()
        else:
            sname = name

        # check if there are leading comment lines before this YAML block and with less indentation
        nspace = hy.strip_indentations(data[cur])[0]
        for i in range(cur - 1, -1, -1):
            nspace2, _, line = hy.strip_indentations(data[i])
            if nspace2 <= nspace and line.startswith('#'):
                cur = i
            else:
                break  # exit the loop if not a comment or different indentation level

        # assemble one observer
        obs = {
            "name": name,
            "sname": sname,
            "is_sat_radiance": is_sat_radiance,
            "pos1": cur,
            "pos2": next_one,
            "pre filters": {},
            "filters": {},
            "prior filters": {},
            "post filters": {},
            "block": [],
        }

        if not shallow:
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


def jedi_query_to_generic(data, querystr):
    if "#" not in querystr:
        return querystr

    query = querystr.strip("#").strip()
    selector, separator, path = query.partition("#")
    if ":" in selector:
        observer_name, filter_identifier = selector.split(":", 1)
        observer_name = observer_name.strip()
        filter_identifier = filter_identifier.strip()
    else:
        observer_name = selector.strip()
        filter_identifier = ""

    observers = get_all_obs(data, shallow=not bool(filter_identifier))
    for observer_index, observer in enumerate(observers.values()):
        if observer["name"] != observer_name and observer["sname"] != observer_name:
            continue

        filter_path = ""
        if filter_identifier:
            for key in ("filters", "prior filters", "pre filters", "post filters"):
                for filter_index, observer_filter in enumerate(observer[key]):
                    if observer_filter["identifier"] == filter_identifier:
                        filter_path = f"/obs {key}/{filter_index}"
                        break
                if filter_path:
                    break
            if not filter_path:
                sys.stderr.write(f'filter identifier "{filter_identifier}" not found!\n')
                return None

        suffix = path.strip().strip("/") if separator else ""
        generic_path = f"observations/observers/{observer_index}{filter_path}"
        return f"{generic_path}/{suffix}" if suffix else generic_path

    sys.stderr.write(f'observer "{observer_name}" not found!\n')
    return None


# list all observers and their filter counts
def listobs(data):
    dcObs = get_all_obs(data, shallow=False)
    obs_text = ''
    filter_text = ''
    for name, observer in dcObs.items():
        obs_text += observer['sname'] + ', '
        filter_count = sum(len(observer[key]) for key in
                           ('pre filters', 'filters', 'prior filters', 'post filters'))
        filter_text += f'{name.ljust(35)}: {filter_count} filters\n'
    obs_text = f'{len(dcObs)} observers:\n{obs_text.rstrip(", ")}'
    print(f'{filter_text}\n\n{obs_text}\n')


# select observers to keep or remove based on their short names
def _select_observers(data, obs_str, keep_matches):
    selected = {name for name in re.split(r'[,\s]+', obs_str) if name}
    spans = []
    for observer in get_all_obs(data, shallow=True).values():
        matches = observer['sname'] in selected
        if matches != keep_matches:
            spans.append((observer['pos1'], observer['pos2']))
    for start, end in sorted(spans, reverse=True):
        del data[start:end]


# remove observers by short name
def removeobs(data, obs_str):
    _select_observers(data, obs_str, keep_matches=False)


# keep only the specified observers by short name
def keepobs(data, obs_str):
    _select_observers(data, obs_str, keep_matches=True)


# helper function to get the label of a filter (either its identifier or category)
def _filter_label(observer_filter):
    return observer_filter["identifier"] or observer_filter["category"]


def _filter_filename(key, index, observer_filter):
    category = re.sub(r"[^\w.-]+", "_", _filter_label(observer_filter)).strip("._") or "filter"
    prefix = key.replace(" ", "")[:-1]
    return f"{prefix}_{index:02}_{category}.yaml"


# helper function to parse the observer selection string into a set of short names
def _filter_observer_selection(obs_str):
    if obs_str is None:
        return None
    return {name for name in re.split(r"[,\s]+", obs_str) if name}


# list all filters for the selected observers, defaulting to all if none specified
def listfilter(data, obs_str=None):
    selected = _filter_observer_selection(obs_str)
    sections = []
    for observer in get_all_obs(data, shallow=False).values():
        if selected is not None and not {observer["name"], observer["sname"]}.intersection(selected):
            continue
        filenames = []
        for key in ("filters", "pre filters", "prior filters", "post filters"):
            filenames.extend(_filter_filename(key, index, observer_filter)[:-5]
                             for index, observer_filter in enumerate(observer[key]))
        if filenames:
            sections.append("\n".join([f"{observer['name']}:"] + filenames))
    if sections:
        print("\n\n".join(sections))


# helper function to select filters for removal or retention based on the filter string and observer selection
def _select_filters(data, filter_str, obs_str, keep_matches):
    selected_filters = {name.strip() for name in filter_str.split(",") if name.strip()}
    if not selected_filters:
        return
    selected_observers = _filter_observer_selection(obs_str)
    spans = []
    for observer in get_all_obs(data, shallow=False).values():
        if selected_observers is not None and not {observer["name"], observer["sname"]}.intersection(selected_observers):
            continue
        for key in ("filters", "pre filters", "prior filters", "post filters"):
            for observer_filter in observer[key]:
                matches = _filter_label(observer_filter) in selected_filters
                if matches != keep_matches:
                    spans.append((observer_filter["pos1"], observer_filter["pos2"]))
    for start, end in sorted(spans, reverse=True):
        del data[start:end]


# remove the specified filters for the selected observers
def removefilter(data, filter_str, obs_str=None):
    _select_filters(data, filter_str, obs_str, keep_matches=False)


# keep only the specified filters for the selected observers
def keepfilter(data, filter_str, obs_str=None):
    _select_filters(data, filter_str, obs_str, keep_matches=True)


# write out the filters for the given observer and key, and then remove them from the observer's block
def write_out_filters(key, obs, obspath, do_dedent, filterlist):
    if obs[key]:  # non-empty
        first = obs[key][0]["block"][0]
        nspace = hy.strip_indentations(first)[0]  # get the extra number of indentations
        for i, dcFilter in enumerate(obs[key]):
            filename = _filter_filename(key, i, dcFilter)
            fpath = f"{obspath}/{filename}"
            filterlist.append(filename)
            with open(fpath, 'w') as outfile:
                write_block(outfile, dcFilter["block"], do_dedent, nspace)
        # remove "key" section from the obs["block"]
        pos1, _ = hy.get_start_pos(obs["block"], f"obs {key}")
        pos2 = hy.next_pos(obs["block"], pos1)
        obs["block"][pos1 + 1:pos2] = []  # keep the "obs {key}:" line


# split a super YAML files to individual observers/filters
def split(fpath, level=1, dirname=".", do_dedent=False):
    data = hy.load(fpath)
    basename = os.path.basename(fpath)
    # dirname is the top level of the split results, default to current directory
    toppath = dirname.rstrip("/")  # remove trailing /  if any
    if toppath == ".":  # if no explicit dirname, use 'split{level}.{basename}'
        toppath = f"./split{level}.{basename}"

    # if the dir exists, find an available dir name to backup old files first
    if os.path.exists(toppath):
        knt = 1
        savedir = f'{toppath}_old{knt:04}'
        while os.path.exists(savedir):
            knt += 1
            savedir = f'{toppath}_old{knt:04}'
        shutil.move(toppath, savedir)
    os.makedirs(toppath, exist_ok=True)

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
                write_block(outfile, obs["block"], do_dedent, nspace)

    else:  # split to individual observers and filters
        for name, obs in dcObs.items():
            obspath = f"{toppath}/{name}"
            os.makedirs(obspath, exist_ok=True)

            # write out filters
            filterlist = []
            write_out_filters("filters", obs, obspath, do_dedent, filterlist)
            write_out_filters("pre filters", obs, obspath, do_dedent, filterlist)
            write_out_filters("prior filters", obs, obspath, do_dedent, filterlist)
            write_out_filters("post filters", obs, obspath, do_dedent, filterlist)
            # write out filterlist.txt
            with open(f"{obspath}/filterlist.txt", 'w') as outfile:
                for item in filterlist:
                    outfile.write(f"{item}\n")

            # write obsmain.yaml
            with open(f"{obspath}/obsmain.yaml", 'w') as outfile:
                nspace = hy.strip_indentations(obs["block"][0])[0]  # get the extra number of indentations
                write_block(outfile, obs["block"], do_dedent, nspace)

    # write main.yaml
    first_content = _first_yaml_content_index(data)
    if first_content is not None and data[first_content].lstrip().startswith("- obs space:"):
        first_observer_start = next(iter(dcObs.values()))["pos1"]
        data = data[:first_observer_start]
    else:
        pos1, _ = hy.get_start_pos(data, "observations/observers")
        pos2 = hy.next_pos(data, pos1)
        data[pos1 + 1:pos2] = []  # keep the "observers:" line
    with open(f'{toppath}/main.yaml', 'w') as outfile:
        for i in range(len(data)):
            outfile.write(data[i] + '\n')


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
  it can replicate the original YAML file splitted with do_dedent=False
    '''
    # read obslist
    obslist = []
    with open(os.path.join(dirname, "obslist.txt"), 'r') as infile:
        for line in infile:
            if line.strip():
                obslist.append(line.strip())

    # check it is level1 or level2 split
    if os.path.isfile(os.path.join(dirname, f"{obslist[0]}.yaml")):
        level = 1
    elif os.path.isdir(os.path.join(dirname, f"{obslist[0]}")):
        level = 2
    else:
        print(f"Neither {obslist[0]}.yaml nor {obslist[0]}/ found")
        return

    data = hy.load(os.path.join(dirname, "main.yaml"))
    has_yaml_content = _first_yaml_content_index(data) is not None
    if has_yaml_content:
        pos1, _ = hy.get_start_pos(data, "observations/observers")
        nspace = hy.strip_indentations(data[pos1])[0]
    else:
        nspace = 0
    if level == 1:
        # assemble individual observers
        observers = []
        for obsname in obslist:
            block = hy.load(os.path.join(dirname, f"{obsname}.yaml"))
            if not plain_pack:  # only align indentation for non-plain_pack situation
                align_indentation(nspace, block, nIndent, listIndent)
            observers.extend(block)

    elif level == 2:
        # assemble individual observers
        observers = []
        for obsname in obslist:
            obs_block = hy.load(os.path.join(dirname, f"{obsname}/obsmain.yaml"))

            filter_type = {
                "filter": "obs filters",
                "prefilter": "obs pre filters",
                "priorfilter": "obs prior filters",
                "postfilter": "obs post filters",
            }
            # read filterlist
            filterlist = []
            with open(os.path.join(dirname, f"{obsname}/filterlist.txt"), 'r') as infile:
                for line in infile:
                    if line.strip():
                        filterlist.append(line.strip())
            # assemble individual filters
            # find the first data line from the bottom
            for i in range(len(obs_block) - 1, 0, -1):
                if obs_block[i].strip() and not obs_block[i].strip().startswith("#"):
                    rev_pos = i
                    break
            nspace4flt = hy.strip_indentations(obs_block[rev_pos])[0]
            for fltfile in reversed(filterlist):  # reverse the order, so we always insert at pos+1
                flt_block = hy.load(os.path.join(dirname, f"{obsname}/{fltfile}"))
                if not plain_pack:
                    align_indentation(nspace4flt, flt_block, nIndent, listIndent)
                prefix = fltfile.split("_")[0]
                pos, _ = hy.get_start_pos(obs_block, filter_type[prefix])
                obs_block[pos + 1:pos + 1] = flt_block

            if not plain_pack:
                align_indentation(nspace, obs_block, nIndent, listIndent)
            observers.extend(obs_block)

    # write out the super YAML file
    if has_yaml_content:
        data[pos1 + 1:pos1 + 1] = observers
    else:
        data.extend(observers)
    with open(fpath, 'w') as outfile:
        for line in data:
            outfile.write(line + "\n")
