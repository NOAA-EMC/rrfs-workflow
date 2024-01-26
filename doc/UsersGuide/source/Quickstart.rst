.. _NCQuickstart:

====================
Quick Start Guide
====================

This chapter provides a brief summary of how to build and run the RRFS-Workflow.


.. _QuickBuildRun:

Building RRFS workflow
===============================================

   #. Clone the ``dev-sci`` branch of the RRFS-Workflow from GitHub:

      .. code-block:: console

         git clone -b dev-sci https://github.com/NOAA-EMC/rrfs-workflow.git

   #. Check out the external components:

      .. code-block:: console

         cd rrfs-workflow/sorc
         ./manage_externals/checkout_externals

   #. Set up the build environment and build the executables:

      .. code-block:: console
            
         ./app_build.sh

      Alternatively, the above command can be followed by the platform (machine) name as follows:

      .. code-block:: console
            
         ./app_build.sh --platform=<machine>

      where ``<machine>`` is ``wcoss2``, ``hera``, ``jet``, ``orion``, or ``hercules``.

   #. Move to the home directory (rrfs-workflow):

      .. code-block:: console

         cd ..

Engineering Test: Non-DA
===============================================

   #. Load the python environment:

      * On WCOSS2:

      .. code-block:: console
         
         source versions/run.ver
         module use modulefiles
         module load wflow_wcoss2

      * On Hera | Jet | Orion | Hercules:

      .. code-block:: console
         
         module use modulefiles
         module load wflow_<machine>
         conda activate workflow_tools

      where ``<machine>`` is ``hera``, ``jet``, ``orion``, or ``hercules``.

   #. Copy the pre-defined configuration file: 

      .. code-block:: console

         cd ush
         cp sample_configs/non-DA_eng/config.nonDA.<format>.<machine>.sh config.sh
      
      where ``<format>`` is ``grib2`` or ``netcdf``, and ``<machine>`` is ``wcoss2``, ``hera``, ``jet``, ``orion``, or ``hercules``. Note that you may need to change ``ACCOUNT``, ``STMP``, or ``PTMP`` in the configuration file ``config.sh``.

   #. Generate the experiment workflow:

      .. code-block:: console

         ./generate_FV3LAM_wflow.sh

   #. Launch the workflow:

      .. code-block:: console

         cd ../../expt_dirs/test_nonDA
         ./launch_FV3LAM_wflow.sh

      .. note::
         The workflow tasks will be submitted every three minutes by ``cron`` until the log output includes a ``Workflow status: SUCCESS`` message if you did not modify the following parameters in the configuration file:

      .. code-block:: console

         USE_CRON_TO_RELAUNCH="TRUE"
         CRON_RELAUNCH_INTVL_MNTS="03"


Engineering Test: DA
===============================================

   #. Load the python environment:

      * On WCOSS2:

      .. code-block:: console
         
         source versions/run.ver
         module use modulefiles
         module load wflow_wcoss2

      * On Hera | Jet | Orion | Hercules :

      .. code-block:: console
         
         module use modulefiles
         module load wflow_<machine>
         conda activate workflow_tools

      where ``<machine>`` is ``hera``, ``jet``, ``orion``, or ``hercules``. 

   #. Copy the pre-defined configuration file: 

      .. code-block:: console

         cd ush
         cp sample_configs/DA_eng/config.DA.<type>.<machine>.sh config.sh
      
      where ``<type>`` is ``para`` with ``<machine>`` is ``wcoss2``, or ``<type>`` is ``retro`` or ``ens`` with ``<machine>`` is ``hera``. Note that you may need to change ``ACCOUNT`` in the configuration file ``config.sh``.

      .. note::
         For the real-time (``para``) test run on WCOSS2, you should replace ``DATE_FIRST_CYCL``, ``DATE_LAST_CYCL``, ``CYCLEMONTH``, and ``CYCLEDAY`` with those of Today's date.

   #. Generate the experiment workflow:

      .. code-block:: console

         ./generate_FV3LAM_wflow.sh

   #. Launch the workflow:

      .. code-block:: console

         cd ../../expt_dirs/rrfs_test_da
         ./run_rocoto.sh

   #. Launch the following tasks as needed:

      * On WCOSS2: with ``config.DA.para.wcoss2.sh`` (in case of today=20230726)

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260000 -t get_extrn_lbcs
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260600 -t get_extrn_lbcs
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261200 -t get_extrn_lbcs
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261800 -t get_extrn_lbcs (only when data is available)
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260300 -t get_extrn_ics 
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307261500 -t get_extrn_ics (only when data is available)

      Note that you may need to run ``rocotoboot`` for the task ``prep_cyc_spinup`` at 04z sequentially only if it is not launched:

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202307260400 -t prep_cyc_spinup

      * On Hera: with ``config.DA.retro.hera.sh`` (in case of cycle_date=20230611)

      If you want to run beyond ``11z``, you should launch the ``get_extrn_lbcs`` tasks for ``12z`` and ``18z`` and the ``get_extrn_ics`` task for ``15z`` manually:

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306111200 -t get_extrn_lbcs
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306111800 -t get_extrn_lbcs
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306111500 -t get_extrn_ics

      Once both ``make_lbcs`` and ``make_ics`` tasks are complete, launch the ``prep_cyc_spinup`` task for ``03z`` manually:

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306110300 -t prep_cyc_spinup

      Keep monitoring and launching the workflow if ``USE_CRON_TO_RELAUNCH`` was NOT set to ``TRUE`` in ``config.sh``. If ``USE_CRON_TO_RELAUNCH`` was set to ``TRUE``, you should remove the crontab line manually once all tasks are complete.

      .. code-block:: console

         ./run_rocoto.sh

      * On Hera: with ``config.DA.ens.hera.sh`` (in case of cycle_date=20230610)

      Once the ``save_restart_ensinit_mem000X`` tasks are complete, launch the following tasks for ``06z`` manually:

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306100600 -t prep_cyc_spinup_ensinit_mem0001
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306100600 -t prep_cyc_spinup_ensinit_mem0002
         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306100600 -t prep_cyc_spinup_ensinit_mem0003

      Once the above three tasks are complete, launch the ``run_recenter_spinup`` task for ``06z`` manually:

      .. code-block:: console

         rocotoboot -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 -c 202306100600 -t run_recenter_spinup

      Keep monitoring and launching the workflow if ``USE_CRON_TO_RELAUNCH`` was NOT set to ``TRUE`` in ``config.sh``:

      .. code-block:: console

         ./run_rocoto.sh

      .. note::
         You should manually launch the above tasks for ``18z`` as well (due to the incorrect path to the dependency ``nonvarcldana_complete.txt``).

   #. Check the status of your run with ``rocotostat``:

      .. code-block:: console

         rocotostat -w FV3LAM_wflow.xml -d FV3LAM_wflow.db -v 10 > test.log

