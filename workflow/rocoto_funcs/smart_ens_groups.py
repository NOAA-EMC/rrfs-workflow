#!/usr/bin/env python
import os


def smart_ens_groups(meta_id):
    list_group_info = []
    ens_size = int(os.getenv('ENS_SIZE', '30'))
    num_groups = int(os.getenv('NUM_ENS_GROUPS', '1'))

    # 1. Generate padded IDs (001, 002...)
    all_indices = [f'{i:03d}' for i in range(1, ens_size + 1)]

    # 2. Split indices into N groups
    k, m = divmod(len(all_indices), num_groups)
    groups = [all_indices[i * k + min(i, m): (i + 1) * k + min(i + 1, m)] for i in range(num_groups)]

    # 3. Build group info and XML dependencies
    xml_grp = ""   # Define dependency for all the groups, prepare for subsequent tasks

    for i, group_indices in enumerate(groups):
        # Create the range string: "001-015"
        range_label = f"{group_indices[0]}-{group_indices[-1]}"
        current_group_name = f"{meta_id}_{range_label}"

        xml_grp = xml_grp + f'\n    <metataskdep metatask="{current_group_name}"/>'

        # Define dependency: Batch 2 depends on Batch 1, etc.
        dependency_xml = ""
        if i > 0:
            # Dependency points to the previous range label
            prev_range = f"{groups[i-1][0]}-{groups[i-1][-1]}"
            current_group_name = f"{meta_id}_{groups[i][0]}-{groups[i][-1]}"
            dependency_xml = f'\n    <metataskdep metatask="{meta_id}_{prev_range}"/>'

        list_group_info.append({
            "members": ' '.join(group_indices),
            "batch_name": current_group_name,
            "dependency_xml": dependency_xml,
            "range": range_label  # Optional: keep the range string as a separate key
        })

    # Generate a summary string of all ranges
    ranges_summary = ", ".join([f"{g[0]}-{g[-1]}" for g in groups])
    print(f"Ensemble member {meta_id} in groups: {ranges_summary}")

    # Return a dictionary containing BOTH the list and the combined XML
    return {
        "group_list": list_group_info,
        "combined_dependency_xml": xml_grp
    }


# Example usage:
# groups = smart_ens_groups("my_experiment")
