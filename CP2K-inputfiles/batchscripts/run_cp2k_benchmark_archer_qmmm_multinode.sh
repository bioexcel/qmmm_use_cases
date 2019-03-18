#!/bin/bash

# Script used to benchmark CP2K on ARCHER comparing performance of different
# versions of CP2K (e.g. PSMP build runinng in PSMP and POPT mode) on 
# multiple nodes of ARCHER. 

EXPECTED_ARGS=4
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Usage: `basename $0` Please specify the number of nodes to run on and run type (QM or MM), test number and walltime"
  echo "Usage: `basename $0` 10 QM 1 01:00:00 - runs 10 nodes, QM type, test-1 with walltime 01:00:00"
  echo "Note:    *** For short queue remember to set the walltime to < 20 mins and edit the final few lines *** "
  exit $E_BADARGS
fi

echo "Generating script to run $2 benchmark on $1 node(s) of ARCHER"
echo "Script will run the PSMP version of code with different numbers of MPI procs/threads"
echo "We can also run the POPT version on multiple nodes with an even spread of MPI procs per node"

cat << EOF > cp2k_${1}_nodes_${2}.pbs
#!/bin/bash --login
#PBS -N $2_$1_nodes
#PBS -l select=$1
#PBS -l walltime=$4
#PBS -A d118

nnodes=$1
runtype=$2
testnum=$3
# Need a lower case runtype for the inputfile names etc
if [ "\$runtype" == "QM" ]
then 
   runtype_lc="qm"
else
   runtype_lc="mm"
fi 
maxcores=\$(( \$nnodes * 24 ))
echo "Testing testing:  runtype = \$runtype runtype_lc = \$runtype_lc"

# CP2KDIR = location of your CP2K binary
# CP2KDATA_DIR = location of CP2K your data/ dir - needed for some benchmarks
# BENCHDIR = location of the original benchmark files, normally on /home
# RUNDIR needs to be on the /work filesystem so all input files etc 
# get copied here or must exist here before running the code

# Set extra preamble paths for ARCHER main machine with fionabio login
export MYHOME=/home/d118/d118/fionabio
export MYWORK=/work/d118/d118/fionabio
export CP2KDIR=\$MYHOME/BioExcel2/cp2k-6.1.0/exe/ARCHER
export CP2KDIR_PACKAGE=/usr/local/packages/cp2k/6.1.18464/exe/ARCHER
export CP2KDATA_DIR=\$MYHOME/BioExcel2/cp2k-6.1.0/data
export RUNDIR=\$MYWORK/BioExcel2/cp2k_benchmarks/QMMM/\$runtype

# For QM or MM set path to input data and benchname:
export BENCHDIR=\$MYHOME/bioexcel2/cp2k_benchmarks/Scale-\${runtype}
export benchname=test-\${testnum}

# Copy the benchmark data over to RUNDIR and the CP2K data directory over 
# as the qm benchmark needs these files to be on /work
cd \$RUNDIR
mkdir \${nnodes}_nodes
cd \${nnodes}_nodes
rsync -r --exclude=.svn \$BENCHDIR/\$benchname .
cd \$benchname

# Copy the CP2KDATA_DIR from /home file space as backend can't see this
# This is not needed for the QMMM tests but there's no harm in leaving it in
# You only need a single copy of data/ so once copied once comment out
#rsync -r --exclude=.svn \$CP2KDATA_DIR .  # creates copy of data/ in each node directory
#rsync -r --exclude=.svn \$CP2KDATA_DIR \$MYWORK/BioExcel2/cp2k_benchmarks/. # copy of data/ in the top level benchmark directory
 
# Set input file name for benchmark, this changes from one test to the other but always begins with qmmm
###export inputfile=qmmm-1.inp
inputfile=\$(ls qmmm*.inp)
echo "Using input file \$inputfile"

# Set the details for the output files. Useful if we want to add more info or other options to runs. 
export outtext1=

# Setup environment for run. CP2K was built with the GNU compilers so 
# load these and set OMP_STACKSIZE and unlimit regular stack size
module swap PrgEnv-cray PrgEnv-gnu
module load cray-fftw/3.3.6.3
export OMP_STACKSIZE=50M
ulimit -s unlimited
# Override CP2K_DATA_DIR as our copy is at:
export CP2K_DATA_DIR=/work/d118/d118/fionabio/BioExcel2/cp2k_benchmarks/data

# Running in PSMP mode with all cores on the node being used 
# We test all possible thread and MPI proc combinations. 
for nthreads in 1 2 4 6
do
   export OMP_NUM_THREADS=\$nthreads
   MPIPROCS=\$(( \$maxcores/\$nthreads ))
   MPIPROCSPERNODE=\$(( \$MPIPROCS/\$nnodes ))
   if [ \$MPIPROCSPERNODE -ge 2 ] 
   then
      MPIPROCSPERNUMANODE=\$(( \$MPIPROCSPERNODE/2 ))
   else
      MPIPROCSPERNUMANODE=1
   fi
   for run in 1 2 3
   do 
# Set names for the output files outfile* and run CP2K
      export outfile=\${runtype_lc}_\${benchname}_PSMP_\${nnodes}_nodes_\${maxcores}_cores_\${MPIPROCS}_mpiprocs_\${OMP_NUM_THREADS}_threads_run_\${run}\${outtext1}.out
      echo "Using \$maxcores cores, running on \$nnodes node(s) with \$MPIPROCS MPIPROCS and \$OMP_NUM_THREADS threads with \$MPIPROCSPERNODE MPI procs per node and \$MPIPROCSPERNUMANODE procs per NUMA node"
# For the 24 thread case we can't use the -S flag so need to handle this separately
      if [ \$nthreads -eq 24 ]
      then 
         echo "aprun -n \$MPIPROCS -N \$MPIPROCSPERNODE -d \$OMP_NUM_THREADS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile"
         aprun -n \$MPIPROCS -N \$MPIPROCSPERNODE -d \$OMP_NUM_THREADS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile
      elif [ \$nthreads -eq 1 ] # i.e. essentially a pure MPI type run use
      then 
         echo "aprun -n \$MPIPROCS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile"
         aprun -n \$MPIPROCS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile
      else  # Mixed mode runs
         echo "aprun -n \$MPIPROCS -N \$MPIPROCSPERNODE -d \$OMP_NUM_THREADS -S \$MPIPROCSPERNUMANODE \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile"
         aprun -n \$MPIPROCS -N \$MPIPROCSPERNODE -d \$OMP_NUM_THREADS -S \$MPIPROCSPERNUMANODE \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile
      fi

# Once the run is complete we need to move the Q*.ener file to a new file 
# so we can check that we get consistent output on different thread counts
# We need to use ls to find the name of the file as it varies from one run
# to another
      enerfile=\$(ls Q*.ener)
      export newenerfile=\${runtype_lc}_\${benchname}_PSMP_\${nnodes}_nodes_\${maxcores}_cores_\${MPIPROCS}_mpiprocs_\${OMP_NUM_THREADS}_threads_run_\${run}\${outtext1}.ener
      mv \$enerfile \$newenerfile 
   done 
done

# For pure MPI runs on multiple nodes use the following, here we just run on 10 nodes and allow up to 24 MPI procs per node
# We've looked at a range of processor counts from 24 upwards including powers of 2 and squares as sometimes the 
# decomposition is better for these. We don't run a single node test as we've done that elsewhere
# Also just do a single run for brevity
export OMP_NUM_THREADS=1
### To run a pure MPI test uncomment the following line and comment out "for MPIPROCS in" 
#for MPIPROCS in 240 196 192 144 128 100 96 72 64 48
for MPIPROCS in 
do
      NUMNODESUSED=\$(( ((\$MPIPROCS-1)/24 ) +1))
      NUMIDLE=\$(( \$nnodes-\$NUMNODESUSED ))
      if [ \$nnodes -lt \$NUMNODESUSED ] 
      then
          echo "Ooops, not enough resources for this run, please increase number of nodes to \$NUMNODESUSED and resubmit"
      else 
          echo "Success: we have enough nodes, \$NUMIDLE nodes are idle for this run"
      fi
   for run in 1
   do 
      export outfile=\${runtype_lc}_\${benchname}_POPT_\${nnodes}_nodes_\${maxcores}_cores_\${MPIPROCS}_mpiprocs_\${OMP_NUM_THREADS}_threads_run_\${run}\${outtext1}.out
      echo "Using \$maxcores cores, running on \$nnodes node(s) with \$MPIPROCS MPIPROCS, using \$NUMNODESUSED nodes"
      echo "aprun -n \$MPIPROCS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile"
      aprun -n \$MPIPROCS \$CP2KDIR/cp2k.psmp \$inputfile > \$outfile
      enerfile=\$(ls Q*.ener)
      export newenerfile=\${runtype_lc}_\${benchname}_POPT_\${nnodes}_nodes_\${maxcores}_cores_\${MPIPROCS}_mpiprocs_\${OMP_NUM_THREADS}_threads_run_\${run}\${outtext1}.ener
      mv \$enerfile \$newenerfile 
   done
done

EOF

echo "Submitting batchscript on $1 nodes for $2 runtype with walltime = $4"
# To test the script and execute without submitting use: 
#chmod u+x cp2k_${1}_nodes_${2}.pbs
#./cp2k_${1}_nodes_${2}.pbs
# To run on the regular queues (i.e if job takes more than 20 mins) use:
qsub cp2k_${1}_nodes_${2}.pbs
# To run on the short queue for testing (less than 20 mins) use:
#qsub -q short cp2k_${1}_nodes_${2}.pbs
