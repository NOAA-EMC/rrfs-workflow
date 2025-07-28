#!/usr/bin/env python
#
import os
import stat
from rocoto_funcs.base import header_begin, header_entities, header_end, source, \
    wflow_begin, wflow_log, wflow_cycledefs, wflow_end
from rocoto_funcs.smart_cycledefs import smart_cycledefs
from rocoto_funcs.ungrib_ic import ungrib_ic
from rocoto_funcs.ungrib_lbc import ungrib_lbc
from rocoto_funcs.ic import ic
from rocoto_funcs.lbc import lbc
from rocoto_funcs.prep_ic import prep_ic
from rocoto_funcs.prep_lbc import prep_lbc
from rocoto_funcs.jedivar import jedivar
from rocoto_funcs.fcst import fcst
from rocoto_funcs.save_fcst import save_fcst
from rocoto_funcs.getkf import getkf
from rocoto_funcs.recenter import recenter
from rocoto_funcs.mpassit import mpassit
from rocoto_funcs.upp import upp
from rocoto_funcs.ioda_bufr import ioda_bufr
from rocoto_funcs.ioda_mrms_refl import ioda_mrms_refl
from rocoto_funcs.clean import clean
from rocoto_funcs.graphics import graphics
from rocoto_funcs.misc import misc

# setup_xml


def setup_xml(HOMErrfs, expdir):
    # source the config cascade
    if os.path.exists(f"{expdir}/config/satinfo") and os.getenv("USE_THE_LATEST_SATBIAS") is None:
        env_vars = {'USE_THE_LATEST_SATBIAS': 'true'}
        os.environ.update(env_vars)
    machine = os.getenv('MACHINE').lower()
    do_deterministic = os.getenv('DO_DETERMINISTIC', 'true').upper()
    do_ensemble = os.getenv('DO_ENSEMBLE', 'false').upper()
    #
    source(f"{HOMErrfs}/workflow/config_resources/config.{machine}")
    source(f"{HOMErrfs}/workflow/config_resources/config.base")
    realtime = os.getenv('REALTIME', 'false')
    if realtime.upper() == "TRUE":
        source(f"{HOMErrfs}/workflow/config_resources/config.realtime")
    #
    # create cycledefs smartly
    dcCycledef = smart_cycledefs()

    fPath = f"{expdir}/rrfs.xml"
    with open(fPath, 'w') as xmlFile:
        header_begin(xmlFile)
        header_entities(xmlFile, expdir)
        header_end(xmlFile)
        wflow_begin(xmlFile)
        log_fpath = f'&LOGROOT;/&RUN;.@Y@m@d/@H/&WGF;/&RUN;.log'
        wflow_log(xmlFile, log_fpath)
        wflow_cycledefs(xmlFile, dcCycledef)

# ---------------------------------------------------------------------------
# assemble tasks for a deterministic experiment
        if do_deterministic == "TRUE":
            if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
                ioda_bufr(xmlFile, expdir)
            if os.getenv("DO_RADAR_REF", "FALSE").upper() == "TRUE":
                ioda_mrms_refl(xmlFile, expdir)
            #
            if os.getenv("DO_IC_LBC", "TRUE").upper() == "TRUE":
                ungrib_ic(xmlFile, expdir)
                ungrib_lbc(xmlFile, expdir)
                ic(xmlFile, expdir)
                lbc(xmlFile, expdir)
            #
            if os.getenv("DO_SPINUP", "FALSE").upper() == "TRUE":
                prep_lbc(xmlFile, expdir)
                # spin up line
                prep_ic(xmlFile, expdir, spinup_mode=1)
                jedivar(xmlFile, expdir, do_spinup=True)
                fcst(xmlFile, expdir, do_spinup=True)
                # prod line
                prep_ic(xmlFile, expdir, spinup_mode=-1)
                jedivar(xmlFile, expdir)
                fcst(xmlFile, expdir)
                save_fcst(xmlFile, expdir)
            elif os.getenv("DO_FCST", "TRUE").upper() == "TRUE":
                prep_ic(xmlFile, expdir)
                prep_lbc(xmlFile, expdir)
                if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
                    jedivar(xmlFile, expdir)
                fcst(xmlFile, expdir)
                save_fcst(xmlFile, expdir)
            #
            if os.getenv("DO_POST", "TRUE").upper() == "TRUE":
                mpassit(xmlFile, expdir)
                upp(xmlFile, expdir)

# ---------------------------------------------------------------------------
# assemble tasks for an ensemble experiment
        if do_ensemble == "TRUE" and os.getenv("IC_ONLY", "FALSE").upper() == "TRUE":
            ungrib_ic(xmlFile, expdir, do_ensemble=True)
            ic(xmlFile, expdir, do_ensemble=True)
        elif do_ensemble == "TRUE":
            if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
                ioda_bufr(xmlFile, expdir)
            if os.getenv("DO_RADAR_REF", "FALSE").upper() == "TRUE":
                ioda_mrms_refl(xmlFile, expdir)
            ungrib_ic(xmlFile, expdir, do_ensemble=True)
            ungrib_lbc(xmlFile, expdir, do_ensemble=True)
            ic(xmlFile, expdir, do_ensemble=True)
            lbc(xmlFile, expdir, do_ensemble=True)
            prep_ic(xmlFile, expdir, do_ensemble=True)
            prep_lbc(xmlFile, expdir, do_ensemble=True)
            if os.getenv("DO_RECENTER", "FALSE").upper() == "TRUE":
                recenter(xmlFile, expdir)
            if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
                getkf(xmlFile, expdir, 'OBSERVER')
                getkf(xmlFile, expdir, 'SOLVER')
                getkf(xmlFile, expdir, 'POST')
            fcst(xmlFile, expdir, do_ensemble=True)
            save_fcst(xmlFile, expdir, do_ensemble=True)
            mpassit(xmlFile, expdir, do_ensemble=True)
            upp(xmlFile, expdir, do_ensemble=True)

# ---------------------------------------------------------------------------
        if os.getenv("DO_CLEAN", 'FALSE').upper() == "TRUE":  # write out the clean task if needed, usually for realtime runs
            clean(xmlFile, expdir)
        if os.getenv("DO_MISC", 'FALSE').upper() == "TRUE":
            misc(xmlFile, expdir)
        if os.getenv("DO_GRAPHICS", 'FALSE').upper() == "TRUE":
            graphics(xmlFile, expdir)
        #
        wflow_end(xmlFile)
# ---------------------------------------------------------------------------

    fPath = f"{expdir}/run_rocoto.sh"
    extra = ""
    if machine in ['orion', 'hercules']:
        extra = "\nmodule load contrib"
    elif machine in ['gaea']:
        extra = "\nmodule use /ncrc/proj/epic/rocoto/modulefiles"
    elif machine in ['wcoss2']:
        extra = "\nmodule use /apps/ops/test/nco/modulefiles/core"
    elif machine in ['derecho']:
        extra = "\nsource /etc/profile.d/z00_modules.sh\nmodule use /glade/work/epicufsrt/contrib/derecho/modulefiles"
    with open(fPath, 'w') as rocotoFile:
        text = \
            f'''#!/usr/bin/env bash
source /etc/profile{extra}
module load rocoto
cd {expdir}
rocotorun -w rrfs.xml -d rrfs.db
'''
        rocotoFile.write(text)

    # set run_rocoto.sh to be executable
    st = os.stat(fPath)
    os.chmod(fPath, st.st_mode | stat.S_IEXEC)

    print(f'rrfs.xml and run_rocoto.sh created at:\n  {expdir}')
# end of setup_xml
