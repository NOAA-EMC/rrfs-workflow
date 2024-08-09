echo "----- RRFS IO SPIKE reading at Job Finish -----"
SPIKE_Reading_file=$(ls -lart /lfs/h3/emc/rrfstemp/ecflow/ptmp/emc.lam/ecflow_rrfs/root/loads.*|tail -1|awk '{print $9}')
[[ -s $SPIKE_Reading_file ]]&& cat $SPIKE_Reading_file
echo "----------------------------------------------"

timeout 300 ecflow_client --complete  # Notify ecFlow of a normal end
trap 0                    # Remove all traps
exit 0                    # End the shell
