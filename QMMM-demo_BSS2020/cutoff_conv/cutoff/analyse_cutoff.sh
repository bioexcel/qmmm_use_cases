#!/bin/bash
 
cutoffs="150 200 250 300 350 400 450 500 550 600 650 700 800 900" 
 
input_file=cp2k.inp
output_file=cp2k.out
plot_file=cutoff_data.dat
 
rel_cutoff=60
 
echo "# Grid cutoff vs total energy" > $plot_file
echo "# REL_CUTOFF = $rel_cutoff" >> $plot_file
echo -n "# Cutoff (Ry) | Total Energy (Ha) | Total QMMM (Ha)" >> $plot_file
grid_header=true
for ii in $cutoffs ; do
    work_dir=cutoff-${ii}
    total_energy=$(grep -e '^[ \t]*Total energy:' $work_dir/$output_file | tail -1 |  awk '{print $3}')
    total_qmmm=$(grep -e 'Total FORCE_EVAL ' $work_dir/$output_file | awk '{print $9}')
    ngrids=$(grep -e '^[ \t]*QS| Number of grid levels:' $work_dir/$output_file | \
             awk '{print $6}')
    if $grid_header ; then
        for ((igrid=1; igrid <= ngrids; igrid++)) ; do
            printf " | NG on grid %d" $igrid >> $plot_file
        done
        printf "\n" >> $plot_file
        grid_header=false
    fi
    printf "%10.2f  %15.10f %15.10f" $ii $total_energy $total_qmmm >> $plot_file
    for ((igrid=1; igrid <= ngrids; igrid++)) ; do
        grid=$(grep -e '^[ \t]*count for grid' $work_dir/$output_file | \
               awk -v igrid=$igrid '(NR == igrid){print $5}')
        printf "  %6d" $grid >> $plot_file
    done
    printf "\n" >> $plot_file
done
