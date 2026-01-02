#!/usr/bin/env python
#
import os
import stat
from rocoto_funcs.base import header_begin, header_entities, header_end, \
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
from rocoto_funcs.save_for_next import save_for_next
from rocoto_funcs.getkf import getkf
from rocoto_funcs.recenter import recenter
from rocoto_funcs.ensmean import ensmean
from rocoto_funcs.mpassit import mpassit
from rocoto_funcs.upp import upp
from rocoto_funcs.ioda_airnow import ioda_airnow
from rocoto_funcs.ioda_bufr import ioda_bufr
from rocoto_funcs.ioda_mrms_refl import ioda_mrms_refl
from rocoto_funcs.nonvar_bufrobs import nonvar_bufrobs
from rocoto_funcs.nonvar_reflobs import nonvar_reflobs
from rocoto_funcs.nonvar_cldana import nonvar_cldana
from rocoto_funcs.prep_chem import prep_chem
from rocoto_funcs.clean import clean
from rocoto_funcs.graphics import graphics
from rocoto_funcs.misc import misc
from rocoto_funcs.hofx import hofx

# setup_xml


def setup_xml(HOMErrfs, expdir):
    if os.path.exists(f"{expdir}/config/satinfo") and os.getenv("USE_THE_LATEST_SATBIAS") is None:
        env_vars = {'USE_THE_LATEST_SATBIAS': 'TRUE'}
        os.environ.update(env_vars)
    machine = os.getenv('MACHINE').lower()
    do_deterministic = os.getenv('DO_DETERMINISTIC', 'TRUE').upper()
    do_ensemble = os.getenv('DO_ENSEMBLE', 'FALSE').upper()
    do_ensmean_post = os.getenv('DO_ENSMEAN_POST', 'FALSE').upper()
    do_chemistry = os.getenv('DO_CHEMISTRY', 'FALSE').upper()
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
                if do_chemistry == "TRUE":
                    ioda_airnow(xmlFile, expdir)
                ioda_bufr(xmlFile, expdir)
            if os.getenv("DO_RADAR_REF", "FALSE").upper() == "TRUE":
                ioda_mrms_refl(xmlFile, expdir)
            if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                nonvar_bufrobs(xmlFile, expdir)
                nonvar_reflobs(xmlFile, expdir)
            #
            if os.getenv("DO_IC_LBC", "TRUE").upper() == "TRUE":
                ungrib_ic(xmlFile, expdir)
                if "global" not in os.getenv("MESH_NAME"):
                    ungrib_lbc(xmlFile, expdir)
                ic(xmlFile, expdir)
                if "global" not in os.getenv("MESH_NAME"):
                    lbc(xmlFile, expdir)
            #
            if os.getenv("DO_SPINUP", "FALSE").upper() == "TRUE":
                prep_lbc(xmlFile, expdir)
                # spin up line
                prep_ic(xmlFile, expdir, spinup_mode=1)
                jedivar(xmlFile, expdir, do_spinup=True)
                if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                    nonvar_cldana(xmlFile, expdir, do_spinup=True)
                fcst(xmlFile, expdir, do_spinup=True)
                # prod line
                prep_ic(xmlFile, expdir, spinup_mode=-1)
                jedivar(xmlFile, expdir)
                if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                    nonvar_cldana(xmlFile, expdir)
                fcst(xmlFile, expdir)
                save_for_next(xmlFile, expdir)
            elif os.getenv("DO_FCST", "TRUE").upper() == "TRUE":
                prep_ic(xmlFile, expdir)
                if "global" not in os.getenv("MESH_NAME"):
                    prep_lbc(xmlFile, expdir)
                if do_chemistry == "TRUE":
                    prep_chem(xmlFile, expdir)
                if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
                    jedivar(xmlFile, expdir)
                if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                    nonvar_cldana(xmlFile, expdir)
                fcst(xmlFile, expdir)
                if os.getenv('DO_CYC', 'FALSE').upper() == "TRUE":
                    save_for_next(xmlFile, expdir)
            #
            if os.getenv("DO_POST", "TRUE").upper() == "TRUE":
                mpassit(xmlFile, expdir)
                upp(xmlFile, expdir)
            if os.getenv("DO_HOFX", "FALSE").upper() == "TRUE":
                hofx(xmlFile, expdir)

# ---------------------------------------------------------------------------
# assemble tasks for an ensemble experiment
        if do_ensemble == "TRUE" and os.getenv("IC_ONLY", "FALSE").upper() == "TRUE":
            ungrib_ic(xmlFile, expdir, do_ensemble=True)
            ic(xmlFile, expdir, do_ensemble=True)
        elif do_ensemble == "TRUE":
            if os.getenv("DO_IODA", "FALSE").upper() == "TRUE":
                if do_chemistry == "TRUE":
                    ioda_airnow(xmlFile, expdir)
                ioda_bufr(xmlFile, expdir)
            if os.getenv("DO_RADAR_REF", "FALSE").upper() == "TRUE":
                ioda_mrms_refl(xmlFile, expdir)
            if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                nonvar_bufrobs(xmlFile, expdir)
                nonvar_reflobs(xmlFile, expdir)
            ungrib_ic(xmlFile, expdir, do_ensemble=True)
            if "global" not in os.getenv("MESH_NAME"):
                ungrib_lbc(xmlFile, expdir, do_ensemble=True)
            ic(xmlFile, expdir, do_ensemble=True)
            if "global" not in os.getenv("MESH_NAME"):
                lbc(xmlFile, expdir, do_ensemble=True)
            prep_ic(xmlFile, expdir, do_ensemble=True)
            if "global" not in os.getenv("MESH_NAME"):
                prep_lbc(xmlFile, expdir, do_ensemble=True)
            if os.getenv("DO_RECENTER", "FALSE").upper() == "TRUE":
                recenter(xmlFile, expdir)
            if os.getenv("DO_JEDI", "FALSE").upper() == "TRUE":
                getkf(xmlFile, expdir, 'OBSERVER')
                getkf(xmlFile, expdir, 'SOLVER')
                getkf(xmlFile, expdir, 'POST')
            if os.getenv("DO_NONVAR_CLOUD_ANA", "FALSE").upper() == "TRUE":
                nonvar_cldana(xmlFile, expdir, do_ensemble=True)
            fcst(xmlFile, expdir, do_ensemble=True)
            if os.getenv('DO_CYC', 'FALSE').upper() == "TRUE":
                save_for_next(xmlFile, expdir, do_ensemble=True)
            mpassit(xmlFile, expdir, do_ensemble=True)
            upp(xmlFile, expdir, do_ensemble=True)
            if do_ensmean_post == "TRUE":
                ensmean(xmlFile, expdir)
                mpassit(xmlFile, expdir, do_ensemble=True, do_ensmean_post=True)
                upp(xmlFile, expdir, do_ensemble=True, do_ensmean_post=True)

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
    elif machine in ['gaeac6']:
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
