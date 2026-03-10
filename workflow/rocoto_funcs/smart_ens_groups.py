#!/usr/bin/env python
import os


def smart_ens_groups(meta_id):
    list_group_info = []
    ens_size = int(os.getenv('ENS_SIZE', '30'))
    num_groups = int(os.getenv('ENS_GROUP_TOT_NUM', '1'))
    ens_metadep_frac_threshold = float(os.getenv('ENS_METADEP_FRAC_THRESHOLD', '1.0'))

    # 1. Generate padded IDs (001, 002...)
    all_indices = [f'{i:03d}' for i in range(1, ens_size + 1)]

    # 2. Split indices into N groups
    k, m = divmod(len(all_indices), num_groups)
    groups = [all_indices[i * k + min(i, m): (i + 1) * k + min(i + 1, m)] for i in range(num_groups)]

    # 3. Build group info and XML dependencies
    xml_grp = ""   # Define dependency for all the groups, prepare for subsequent tasks

    for i, group_indices in enumerate(groups):
        current_group = f"{meta_id}_g{i:02d}"

        xml_grp = xml_grp + f'\n    <metataskdep metatask="{current_group}"/>'

        # Define dependency: Batch 2 depends on Batch 1, etc.
        dep_xml = ""
        if i > 0:
            # Dependency points to the previous range label
            prev_group = f"{meta_id}_g{i-1:02d}"
            dep_xml = f'\n    <metataskdep metatask="{prev_group}" threshold="{ens_metadep_frac_threshold:.1f}"/>'

        list_group_info.append({
            "ens_indices": ' '.join(group_indices),
            "group_name": current_group,
            "dep_xml": dep_xml,
        })

    # Generate a summary string of all ranges
    ranges_summary = ", ".join([f"{g[0]}-{g[-1]}" for g in groups])
    print(f"Ensemble member {meta_id} in groups: {ranges_summary}")

    # Return a dictionary containing BOTH the list and the combined XML
    return {
        "group_list": list_group_info,
        "combined_dep_xml": xml_grp
    }
