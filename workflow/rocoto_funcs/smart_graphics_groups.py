#!/usr/bin/env python
import os
from rocoto_funcs.base import get_cascade_env


def smart_graphics_groups():
    tiles_list = os.getenv('GRAPHICS_TILES', 'full').split()
    ngroups = int(os.getenv('GRAPHICS_GROUP_TOT_NUM', '1'))
    cores_per_tile = int(os.getenv('GRAPHICS_CORES_PER_TILE', '12'))
    meta_id = 'graphics'

    # Distribute tiles evenly into groups using round-robin indexing
    groups_tiles = [[] for _ in range(ngroups)]
    for idx, tile in enumerate(tiles_list):
        groups_tiles[idx % ngroups].append(tile)

    list_groups = []
    for igroup, tile_subset in enumerate(groups_tiles):
        if not tile_subset:
            continue

        task_id = meta_id if ngroups == 1 else f'{meta_id}_g{igroup:02d}'

        # Core allocation validation against allocated ppn
        nodes_spec = get_cascade_env(f"NODES_{task_id}".upper())
        if nodes_spec and 'ppn=' in nodes_spec:
            allocated_ppn = int(nodes_spec.split('ppn=')[1].split('<')[0].split(':')[0])
            cores_needed = len(tile_subset) * cores_per_tile
            assert cores_needed <= allocated_ppn, (
                f"FATAL ERROR in {task_id}: Requested {cores_needed} cores "
                f"({len(tile_subset)} tiles * {cores_per_tile}) exceeds allocated ppn {allocated_ppn} in '{nodes_spec}'!"
            )

        list_groups.append({
            'group_index': igroup,
            'task_id': task_id,
            'tiles_str': ' '.join(tile_subset),
            'cores_per_tile': cores_per_tile,
        })

    return list_groups
