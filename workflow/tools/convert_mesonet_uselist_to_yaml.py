#!/usr/bin/env python3
"""
Convert current_mesonet_uselist.txt to mesonet_uselist.yaml for JEDI

The input file has data lines (non-comment) with columns:
  stationID  W_flag  T_flag  Td_flag  provider  ... stats ...

- W_flag  → wind
- T_flag  → temperature
- Td_flag → dewpoint
"""

import sys

IDS_PER_LINE = 20  # ~20 quoted station IDs per line


def parse_uselist(filepath):
    """Parse the mesonet uselist file, return sets of station IDs per variable."""
    wind_ids = []
    temp_ids = []
    dewpt_ids = []

    with open(filepath, 'r') as f:
        for line in f:
            # Skip comment lines
            if line.strip().startswith(';'):
                continue
            parts = line.split()
            if len(parts) < 5:
                continue

            station_id = parts[0]
            w_flag = int(parts[1])
            t_flag = int(parts[2])
            td_flag = int(parts[3])

            if w_flag == 1:
                wind_ids.append(station_id)
            if t_flag == 1:
                temp_ids.append(station_id)
            if td_flag == 1:
                dewpt_ids.append(station_id)

    return wind_ids, temp_ids, dewpt_ids


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
    input_file = "current_mesonet_uselist.txt"

    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = input_file.replace("txt", "yaml")

    wind_ids, temp_ids, dewpt_ids = parse_uselist(input_file)

    print(f"Stations with good wind: {len(wind_ids)}")
    print(f"Stations with good temperature: {len(temp_ids)}")
    print(f"Stations with good dewpoint: {len(dewpt_ids)}")

    with open(output_file, 'w') as f:
        f.write("# Mesonet use list for JEDI\n")
        f.write("# Generated from: {}\n".format(input_file))
        f.write("# Stations with flag=1 are included (use list)\n\n")
        write_flow_list(f, "wind", wind_ids)
        f.write("\n")
        write_flow_list(f, "temperature", temp_ids)
        f.write("\n")
        write_flow_list(f, "dewpoint", dewpt_ids)

    print(f"\nWritten to: {output_file}")


if __name__ == "__main__":
    main()
