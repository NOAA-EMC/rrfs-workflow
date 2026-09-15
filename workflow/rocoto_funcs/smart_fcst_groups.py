#!/usr/bin/env python
import os
import sys


def smart_fcst_groups(dcCycleDef):
    # determine "cycles_by_fcst_length"
    fcst_lengths = os.getenv('FCST_LEN_HRS_CYCLES', '')
    # fcst_lengths = '72 01 03 12 01 03 12 01 03 12 01 03 72 01 03 12 01 03 12 01 03 12 01 03'  # debug
    # fcst_lengths = ('01 ' * 24).strip()  # debug

    fcst_lengths = list(map(int, fcst_lengths.split()))  # collapses spaces into one separator and ignore leading/trailing spaces
    if len(fcst_lengths) != 24:
        print(f'FATAL ERROR: wrong FCST_LEN_HRS_CYCLES="{fcst_lengths}"')
        sys.exit()
    #
    cycles_by_fcst_length = {}
    for index, length in enumerate(fcst_lengths):
        if length in cycles_by_fcst_length:
            cycles_by_fcst_length[length].append(index)
        else:
            cycles_by_fcst_length[length] = [index]
    cycles_by_fcst_length_sorted = dict(sorted(cycles_by_fcst_length.items()))
    num_cycle_groups = len(cycles_by_fcst_length_sorted)
    # ~~~~~~~~~~~~~
    # determine how many extra fcst cycledefs are needed
    # construct listGroupInfo: grp and corresponding cycledef
    cycledef_prod = dcCycleDef['prod']
    if isinstance(cycledef_prod, dict):
        cycledef_prod = cycledef_prod["cycledef"]
    listGroupInfo = []
    if num_cycle_groups == 1:  # only one fcst length, just use cycledef_prod
        dcTmp = {"grp": "fcst", "cycledef": 'prod'}
        listGroupInfo.append(dcTmp)
    else:
        for index in range(num_cycle_groups):
            valid_hours = sorted(list(cycles_by_fcst_length_sorted.values())[index])
            valid_str = " ".join(f"{i}" for i in valid_hours)

            all_hours = [i for i in range(24)]
            exclude_str = ''
            if len(valid_hours) > 12:  # use exclude_hours for this situation
                exclude_hours = [x for x in all_hours if x not in set(valid_hours)]
                exclude_str = " ".join(f"{i:02d}" for i in exclude_hours)

            # fcst, fcst_g2, fcst_g3, ...  # fcst means fcst_g1
            if index == 0:
                cycledef_name = "fcst"
            else:
                cycledef_name = f'fcst_{"h" * index}'
            grp_name = cycledef_name
            if exclude_str == '':
                dcCycleDef[cycledef_name] = {'valid_hours': f'{valid_str}', "cycledef": f'{cycledef_prod}'}
            else:  # use exclude_hours if exclude_str non-empty
                dcCycleDef[cycledef_name] = {'exclude_hours': f'{exclude_str}', "cycledef": f'{cycledef_prod}'}
            # ~~~~~
            dcTmp = {"grp": grp_name, "cycledef": f'{cycledef_name}'}
            listGroupInfo.append(dcTmp)
    # ~~~~~~~~~~~~~
    # debug:
    # print(cycles_by_fcst_length_sorted)
    # print(dcCycleDef)
    # print(listGroupInfo)
    # sys.exit()
    # ~~~~~~~~~~~~~
    return listGroupInfo
