#!/usr/bin/env python
import os
import sys
import hifiyaml as hy
import yamltools4jedi as yj


def smart_superyaml(HOMErrfs, ytype):
    # make sure no "main.yaml" under parm/observers before further actions
    fmain = f'{HOMErrfs}/parm/observers/main.yaml'
    if os.path.islink(fmain):
        os.unlink(fmain)
    elif os.path.isfile(fmain):
        os.remove(fmain)
    # ~~~~
    fheader = f'../{ytype}_header.yaml'  # use a relative link
    os.symlink(fheader, fmain)
    #
    dirname = f'{HOMErrfs}/parm/observers'
    fpacked = f'{HOMErrfs}/parm/{ytype}.yaml'
    yj.pack(dirname, fpacked)
    #
    # -----------------------------------------------------------
    #  Modifications for different use cases or applications
    # -----------------------------------------------------------
    #
    data = hy.load(fpacked)
    #
    #  getkf needs to set "io pool/max pool size" to 80
    #   (note: we may need to allow configurable "max pool size" for different situations,
    #          but let's update that in a new PR)
    #
    if ytype == "getkf":
        dcObs = yj.get_all_obs(data, shallow=True)
        for name, observer in dcObs.items():
            tmp = data[observer["pos1"]:observer["pos2"]]  # a shallow copy when slicing
            pos, errmsg = hy.get_start_pos(tmp, "io pool/max pool size")
            if errmsg is None:
                absolute_pos = observer["pos1"] + pos
                data[absolute_pos] = data[absolute_pos].replace("max pool size: 1", "max pool size: 80")
    #
    # ------------------------------------------------------------------------
    # dump out the final yaml file
    hy.dump(data, fpath=fpacked)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} HOMErrfs getkf")
        sys.exit(1)
    smart_superyaml(sys.argv[1], sys.argv[2])
