#!/bin/bash -l
#SBATCH -t 00:30:00
#SBATCH -J mm-1
#SBATCH -p test
#SBATCH -o ocp2k.%j
#SBATCH -e ecp2k.%j
#SBATCH -N 8
#SBATCH --no-requeue

(( ncores = SLURM_NNODES * 24 ))
export CP2K_DATA_DIR=/appl/chem/cp2k/data

module load cp2k/5.1-gnu-elpa

# 8 nodes, 24 cores per node = 192 processes
# choose parameters carefully

#aprun -n 192 cp2k.popt em.inp > em.out
#aprun -n 192 cp2k.popt nvt.inp > nvt.out
#aprun -n 192 cp2k.popt npt.inp > npt.out
aprun -n 192 cp2k.popt qmmm-1.inp > qmmm-1.out
