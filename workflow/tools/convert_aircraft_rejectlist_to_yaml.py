#!/usr/bin/env python3
"""
Convert current_bad_aircraft.txt to aircraft_rejectlist.yaml for JEDI

The input file has data lines (non-comment, starting with ';') with columns:
  tail_number  T_flag  W_flag  R_flag  FSL_ID  MDCRS_ID  N  stats...

- T_flag = T → temperature
- W_flag = W → wind
- R_flag = R → relative_humidity

Both tail_number and MDCRS_ID (when not '--------') are added to the list,
"""

import sys

IDS_PER_LINE = 15  # IDs per line in flow-style YAML


def parse_rejectlist(filepath):
    """Parse the aircraft reject list, return lists of IDs per variable."""
    temp_ids = []
    wind_ids = []
    rh_ids = []

    with open(filepath, 'r') as f:
        for line in f:
            # Skip comment lines (start with ;)
            if line.strip().startswith(';'):
                continue
            parts = line.split()
            if len(parts) < 6:
                continue

            tail_number = parts[0]
            t_flag = parts[1]
            w_flag = parts[2]
            r_flag = parts[3]
            # parts[4] = FSL_ID (not needed)
            mdcrs_id = parts[5]

            # Collect IDs for this entry (tail + MDCRS if available)
            ids = [tail_number]
            if mdcrs_id != "--------":
                ids.append(mdcrs_id)

            if t_flag == "T":
                temp_ids.extend(ids)
            if w_flag == "W":
                wind_ids.extend(ids)
            if r_flag == "R":
                rh_ids.extend(ids)

    return temp_ids, wind_ids, rh_ids


def write_flow_list(f, key, ids):
    """Write a YAML key with a flow-style list, wrapping lines."""
    if not ids:
        f.write(f"{key}: []\n")
        return

    f.write(f"{key}: [\n")
    for i in range(0, len(ids), IDS_PER_LINE):
        chunk = ids[i:i + IDS_PER_LINE]
        line = ", ".join(f'"{sid}"' for sid in chunk)
        if i + IDS_PER_LINE < len(ids):
            line += ","
        f.write(f"  {line}\n")
    f.write("]\n")


def main():
    input_file = "current_bad_aircraft.txt"

    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = input_file.replace("txt", "yaml")

    temp_ids, wind_ids, rh_ids = parse_rejectlist(input_file)

    print(f"Temperature reject IDs: {len(temp_ids)}")
    print(f"Wind reject IDs: {len(wind_ids)}")
    print(f"Relative humidity reject IDs: {len(rh_ids)}")

    with open(output_file, 'w') as f:
        f.write("# Aircraft reject list for JEDI\n")
        f.write(f"# Generated from: {input_file}\n")
        f.write("# Contains both tail numbers and MDCRS IDs\n\n")
        write_flow_list(f, "temperature", temp_ids)
        f.write("\n")
        write_flow_list(f, "wind", wind_ids)
        f.write("\n")
        write_flow_list(f, "relative_humidity", rh_ids)

    print(f"\nWritten to: {output_file}")


if __name__ == "__main__":
    main()
