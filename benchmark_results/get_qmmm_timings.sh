#!/bin/bash

# Simple script to extract the data from the QMMM results
EXPECTED_ARGS=3
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` Input the top level directory containing the results you want to process, runtype (QM or MM) and test number"
  echo "Usage: `basename $0` ./get_qmmm_timings.sh /home/d118/d118/fionabio/bioexcel2/results/QMMM/QM QM 1"
  exit $E_BADARGS
fi

# Set up parameters:
resultdir=$1
runtype=$2
testnumber=$3
export outputfile=${runtype}_test-${testnumber}.txt
# Get a lowercase runtype for the filenames
if [ "$runtype" == "QM" ]
then 
   runtype_lc="qm"
else
   runtype_lc="mm"
fi 


echo "Outputfile = $outputfile"

# Jump to result directory
cd $resultdir

# Remove old output files
rm $outputfile

# Create array for the numbers of threads being tested: 
array_threads=(1 2 4 6)
echo "Nodes Cores" ${array_threads[@]} ${array_threads[@]} > $outputfile
for nnodes in 2 4 6 8 10 16 32 64
do

    declare -a array_cp2ktime
    declare -a array_cp2kstartup
    i=0
    ncores=$(($nnodes*24))
    for nthreads in ${array_threads[@]}
    do
	prepath=${nnodes}_nodes/test-${testnumber}
	resval_cp2k=`grep "CP2K  " ${prepath}/${runtype_lc}_test-${3}_PSMP_${nnodes}_nodes_*${nthreads}_threads_run_*.out | awk '{print($8)}'| sort -n | head  -1`
	if [ -z "$resval_cp2k" ]
	then
	    echo "$resval_cp2k is empty for $nnodes nodes and $nthreads threads, setting to NULL"
	    i=$i+1
	    array_cp2ktime[$i]="NULL"
	    array_cp2kstartup[$i]="NULL"
	    continue
	fi

	tmp2=`grep "CP2K  " ${prepath}/${runtype_lc}_test-${3}_PSMP_${nnodes}_nodes_*${nthreads}_threads_run_*.out | sort -n -k 8 | head -1 | awk '{print($1)}'`
	tmp1=`basename $tmp2`
	bestrunfile=`basename $tmp1 .out:`
	mpiprocs=`grep "message passing processes" ${prepath}/${bestrunfile}.out | awk '{print($8)}'`
	check_nthreads=`grep "Number of threads" ${prepath}/${bestrunfile}.out | awk '{print($8)}'`
	nsteps=`grep "Number of Time Steps" ${prepath}/${bestrunfile}.out | awk '{print($6)}' `

	# Do the stats for removing the startup costs
	# Sum up the nsteps-1 time steps and find out average time per steps
	nsteps_comp=$(($nsteps-1)) # Deduct 1 from number of steps
	# Compute the average time per step for last nsteps-1 steps
	averagesteptime=`tail -${nsteps} ${prepath}/${bestrunfile}.ener | awk '{print($7)}' | tail -4 | awk -v var=$nsteps_comp 'BEGIN{s=0}{s+=$1}END{print ((s)/var)}'`
	step1time=`tail -${nsteps} ${prepath}/${bestrunfile}.ener | head -1 | awk '{print($7)}'`
	startuptime=`awk -v var=$step1time -v var2=$averagesteptime 'BEGIN{print(var-var2)}'`
###	echo "Average step time = $averagesteptime, step 1 time = $step1time, startup time = $startuptime"
###	echo "For $nnodes nodes and $nthreads threads timing = $resval from file $bestrunfile check: $mpiprocs $check_nthreads $nsteps"
###	echo $mpiprocs $nthreads $resval_cp2k 
	i=$i+1
	array_cp2ktime[$i]=$resval_cp2k
	array_cp2kstartup[$i]=$startuptime
    done
    echo $nnodes $ncores ${array_cp2ktime[@]} ${array_cp2kstartup[@]} >> $outputfile
done
