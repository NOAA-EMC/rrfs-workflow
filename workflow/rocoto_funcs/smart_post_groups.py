#!/usr/bin/env python
import os
import sys
import math


def smart_post_groups(dcCycleDef):
    # determine "cycles_by_fcst_length"
    fcst_lengths = os.getenv('FCST_LEN_HRS_CYCLES', '')
    fcst_lengths = list(map(int, fcst_lengths.split()))  # collapses spaces into one separator and ignore leading/trailing spaces
    if len(fcst_lengths) != 24:
        print(f'FATAL ERROR: wrong FCST_LEN_HRS_CYCLES="{fcst_lengths}"')
        sys.exit()
    max_fcst_length = max(fcst_lengths)
    cycles_by_fcst_length = {}
    for index, length in enumerate(fcst_lengths):
        if length in cycles_by_fcst_length:
            cycles_by_fcst_length[length].append(index)
        else:
            cycles_by_fcst_length[length] = [index]
    cycles_by_fcst_length_sorted = dict(sorted(cycles_by_fcst_length.items()))
    #
    # construct groups based on the configuration in the exp file
    groups = []
    ngroups = int(os.getenv('POST_GROUP_TOT_NUM', '1'))
    spec = os.getenv('POST_GROUP_SPEC', '')
    if spec == "":  # automatic grouping if POST_GROUP_SPEC is non defined
        history_interval = int(os.getenv('HISTORY_INTERVAL', '1'))
        step = math.floor(max_fcst_length / ngroups + 0.5)
        for i in range(ngroups):
            bgn_hr = i * step + 1
            if i == 0:
                bgn_hr = 0
            end_hr = (i + 1) * step
            if (i + 1) == ngroups:
                end_hr = max_fcst_length
            groups.append(f'{bgn_hr}-{end_hr}-{history_interval}')
        str_groups = " ".join(f"{s}" for s in groups)
        print(f'MPASSIT/UPP automatic grouping: "{str_groups}"\n')

    else:  # POST_GROUP_SPEC is defined, has the highest priority, ignore POST_GROUP_TOT_NUM
        groups = spec.split()
        str_groups = " ".join(f"{s}" for s in groups)
        print(f'MPASSIT/UPP customized grouping: "{str_groups}"\n')

    # determine how many post cycledefs are needed
    num_post_cycledefs = 0  # the number of post cycledefs needed
    dcCycles_by_postgrp = {}  # cycles in each cycledef
    dc_iPost_cycledefs = {}  # for each entry in the "groups" list, its corresponding index in dcCycles_by_postgrp
    igroup = -1
    for key, value in cycles_by_fcst_length_sorted.items():
        for index, item in enumerate(groups):
            parts = item.split("-")
            if len(parts) == 1:
                bgn_hr = end_hr = parts[0]
            else:
                bgn_hr = parts[0]
                end_hr = parts[1]
            if key >= int(bgn_hr) and key <= int(end_hr):
                if index != igroup:  # need a new cycledef_post
                    num_post_cycledefs = num_post_cycledefs + 1
                    dcCycles_by_postgrp[num_post_cycledefs - 1] = value
                    dc_iPost_cycledefs[index] = num_post_cycledefs - 1
                    # check and define the entreis before index
                    for j in range(index):
                        if j not in dc_iPost_cycledefs:
                            dc_iPost_cycledefs[j] = num_post_cycledefs - 1
                    igroup = index
                else:  # combine cycles if using the same cycldef_post
                    dcCycles_by_postgrp[num_post_cycledefs - 1].extend(value)
                break
    # ~~~~~~~~~~~~~
    # update dcCycledef accordingly
    for i in range(num_post_cycledefs - 1):
        for j in range(i + 1, num_post_cycledefs):
            dcCycles_by_postgrp[i].extend(dcCycles_by_postgrp[j])
    #
    cycledef_prod = dcCycleDef['prod']
    if isinstance(cycledef_prod, dict):
        cycledef_prod = cycledef_prod["cycledef"]
    for index, valid_hours in dcCycles_by_postgrp.items():
        if index == 0:  # the first post group uses the prod cycledef
            continue

        valid_hours = sorted(valid_hours)
        valid_str = " ".join(f"{i}" for i in valid_hours)
        all_hours = [i for i in range(24)]
        exclude_str = ''
        if len(valid_hours) > 12:  # use exclude_hours for this situation
            exclude_hours = [x for x in all_hours if x not in set(valid_hours)]
            exclude_str = " ".join(f"{i:02d}" for i in exclude_hours)

        if exclude_str == '':
            dcCycleDef[f'post{index:02d}'] = {'valid_hours': f'{valid_str}', "cycledef": f'{cycledef_prod}'}
        else:  # use exclude_hours if exclude_str non-empty
            dcCycleDef[f'post{index:02d}'] = {'exclude_hours': f'{exclude_str}', "cycledef": f'{cycledef_prod}'}
    # ~~~~~~~~~~~~~
    # construct listGroupInfo: hours and cycledef for each post group
    listGroupInfo = []
    for index, item in enumerate(groups):
        ipos = dc_iPost_cycledefs[index]
        if ipos == 0:
            mycycledef = "prod"
        else:
            mycycledef = f'post{ipos:02d}'
        dcTmp = {"hours": f'{item}', "cycledef": f'{mycycledef}'}
        listGroupInfo.append(dcTmp)
    # ~~~~~~~~~~~~~
    # debug:
    # print(cycles_by_fcst_length_sorted, "\n")
    # print(dc_iPost_cycledefs, "\n")
    # print(dcCycleDef, "\n")
    # print(listGroupInfo)
    # sys.exit()
    # ~~~~~~~~~~~~~
    return listGroupInfo
