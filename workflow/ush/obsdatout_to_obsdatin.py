#!/usr/bin/env python
import sys

def process_file(input_file, output_file):
    buffer_zone = []
    in_buffer_zone = False
    obsfile_line = None
    obsdatout = False

    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if "RoundRobin" in line:
                line = line.replace("RoundRobin", "Halo")
            elif "obsdatain" in line:
                in_buffer_zone = True
                buffer_zone.append(line)
            elif in_buffer_zone:
                buffer_zone.append(line)
                if "obsdataout" in line:
                    obsdatout=True
                elif "obsfile" in line:
                  if obsdatout:
                    line = line.replace("jdiag", "data/jdiag/jdiag")
                    obsfile_line = line  # Store the obsdatout "obsfile" line

            if obsfile_line and in_buffer_zone:
                # Replace the previous obsfile line with the new one
                for i, buf_line in enumerate(buffer_zone):
                    if "obsfile" in buf_line:
                        buffer_zone[i] = obsfile_line
                        break
                # Write out the buffer zone
                for buf_line in buffer_zone:
                    outfile.write(buf_line)
                # Reset buffer and state tracking
                buffer_zone = []
                in_buffer_zone = False
                obsfile_line = None
                obsdatout = False
                continue
            
            if not in_buffer_zone:
                outfile.write(line)

# main -----------------------------------------------
args=sys.argv
nargs=len(args)-1
if nargs <2:
  print(f"{args[0]} <file1> <file2>")
  exit()
#
process_file(args[1], args[2])
