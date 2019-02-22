#!/bin/bash
#SBATCH -J qmtest-1
#SBATCH -e err_%j
#SBATCH -o out_%j
#SBATCH -t 10:00:00
#SBATCH --ntasks-per-node=12
#SBATCH -N 16
#SBATCH --mem=63000
#SBATCH -p parallel

module load cp2k-env/5.1
export CP2K_DATA_DIR=/appl/chem/cp2k/data

# 16 * 12 = 192 cores

#srun cp2k.popt em.inp > em.out
#srun cp2k.popt nvt.inp > nvt.out
#srun cp2k.popt npt.inp > npt.out
srun cp2k.popt qmmm.inp > qmmm.out

