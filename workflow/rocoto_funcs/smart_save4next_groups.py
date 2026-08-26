#!/usr/bin/env python
import os
import sys


def smart_save4next_groups(dcCycleDef):
    # determine "cycles_by_fcst_length"
    fcst_lengths = os.getenv('FCST_LEN_HRS_CYCLES', '')
    mpasout_timelevels = os.getenv('MPASOUT_TIMELEVELS', '')
    # fcst_lengths = '72 01 03 12 01 03 12 01 03 12 01 03 72 01 03 12 01 03 12 01 03 12 01 03'  # debug
    # mpasout_timelevels = '0 1 2 3 12 15 27'  # debug

    fcst_lengths = list(map(int, fcst_lengths.split()))  # collapses spaces into one separator and ignore leading/trailing spaces
    max_fcst_length = max(fcst_lengths)
    save_timelevels = {int(x): int(x) for x in mpasout_timelevels.split() if int(x) != 0 and int(x) <= max_fcst_length}
    if len(fcst_lengths) != 24:
        print(f'FATAL ERROR: wrong FCST_LEN_HRS_CYCLES="{fcst_lengths}"')
        sys.exit()
    if len(mpasout_timelevels) == 0:
        print(f'FATAL ERROR: mpasout_timelevels is empty or contains only f0h ')
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
    #
    # check each valid save_timelevels to determine what key index in cycles_by_fcst_length_sorted it belongs to
    listSave4next = [0] * len(save_timelevels)
    for index, item in enumerate(save_timelevels):
        ptr = 0
        for pos, key in enumerate(cycles_by_fcst_length_sorted):
            if item <= key:
                ptr = pos
                break
        # ~~~~~~~~
        listSave4next[index] = ptr
    # ~~~~
    # determine how many extra save4next cycledefs are needed
    #
    cycledef_prod = dcCycleDef['prod']
    if isinstance(cycledef_prod, dict):
        cycledef_prod = cycledef_prod["cycledef"]
    setSave4next = set(listSave4next)  # remove duplicate values in a list
    for index in setSave4next:
        if index == 0:  # the first group uses the prod cycledef
            continue
        # ~~~~
        valid_hours = sorted(list(cycles_by_fcst_length_sorted.values())[index])
        for i in range(index + 1, num_cycle_groups):
            valid_hours.extend(sorted(list(cycles_by_fcst_length_sorted.values())[i]))
        valid_hours = sorted(valid_hours)
        valid_str = " ".join(f"{i}" for i in valid_hours)

        all_hours = [i for i in range(24)]
        exclude_str = ''
        if len(valid_hours) > 12:  # use exclude_hours for this situation
            exclude_hours = [x for x in all_hours if x not in set(valid_hours)]
            exclude_str = " ".join(f"{i:02d}" for i in exclude_hours)

        if exclude_str == '':
            dcCycleDef[f'save4next{index:02d}'] = {'valid_hours': f'{valid_str}', "cycledef": f'{cycledef_prod}'}
        else:  # use exclude_hours if exclude_str non-empty
            dcCycleDef[f'save4next{index:02d}'] = {'exclude_hours': f'{exclude_str}', "cycledef": f'{cycledef_prod}'}

    # ~~~~~~~~~~~~~
    # construct listGroupInfo: fhr and corresponding cycledef
    listGroupInfo = []
    for index, item in enumerate(save_timelevels):
        if listSave4next[index] == 0:
            mycycledef = "prod"
        else:
            mycycledef = f'save4next{listSave4next[index]:02d}'
        dcTmp = {"fhr": item, "cycledef": f'{mycycledef}'}
        listGroupInfo.append(dcTmp)
    # ~~~~~~~~~~~~~
    # debug:
    # print(cycles_by_fcst_length_sorted)
    # print(listSave4next)
    # print(dcCycleDef)
    # print(listGroupInfo)
    # sys.exit()
    # ~~~~~~~~~~~~~
    return listGroupInfo
