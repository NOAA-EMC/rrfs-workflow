.. _NCQuickstart:

====================
Quick Start Guide
====================

This chapter provides a brief summary of how to build and run the RRFS-Workflow.


.. _QuickBuildRun:

Building and Running the RRFS Workflow
===============================================

   #. Clone the SRW App from GitHub:

      .. code-block:: console

         git clone -b develop https://github.com/ufs-community/ufs-srweather-app.git

   #. Check out the external repositories:

      .. code-block:: console

         cd ufs-srweather-app
         ./manage_externals/checkout_externals

   #. Set up the build environment and build the executables:

      .. code-block:: console
            
         ./devbuild.sh --platform=<machine_name>

      where ``<machine_name>`` is replaced with the name of the user's platform/system. Valid values include: ``cheyenne`` | ``gaea`` | ``hera`` | ``jet`` | ``linux`` | ``macos`` | ``noaacloud`` | ``orion`` | ``wcoss2``

   #. Load the python environment for the regional workflow. Users on Level 2-4 systems will need to use one of the existing ``wflow_<platform>`` modulefiles (e.g., ``wflow_macos``) and adapt it to their system. Then, run:

      .. code-block:: console
         
         source <path/to/etc/lmod-setup.sh/or/lmod-setup.csh> <platform>
         module use <path/to/modulefiles>
         module load wflow_<platform>

      where ``<platform>`` refers to a valid machine name. After loading the workflow, users should follow the instructions printed to the console. For example, if the output says: 

      .. code-block:: console

         Please do the following to activate conda:
            > conda activate regional_workflow
      
      then the user should run ``conda activate regional_workflow`` to activate the regional workflow environment. 

      .. note::
         If users source the *lmod-setup* file on a system that doesn't need it, it will not cause any problems (it will simply do a ``module purge``).

   #. Configure the experiment: 

      .. code-block:: console

         cd ush
         cp config.community.yaml config.yaml
      
      Users will need to open the ``config.yaml`` file and adjust the experiment parameters in it to suit the needs of their experiment (e.g., date, grid, physics suite). At a minimum, users need to modify the ``MACHINE`` parameter.
 
   #. Generate the experiment workflow. 

      .. code-block:: console

         ./generate_FV3LAM_wflow.py

   #. Run the regional workflow. There are several methods available for this step. One possible method is summarized below. 

      .. code-block:: console

         cd $EXPTDIR
         ./launch_FV3LAM_wflow.sh

      To (re)launch the workflow and check the experiment's progress:

      .. code-block:: console

         ./launch_FV3LAM_wflow.sh; tail -n 40 log.launch_FV3LAM_wflow

      The workflow must be relaunched regularly and repeatedly until the log output includes a ``Workflow status: SUCCESS`` message indicating that the experiment has finished.

