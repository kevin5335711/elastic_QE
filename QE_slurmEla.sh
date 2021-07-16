#!/bin/sh
#sed_anchor01
#SBATCH --output=Opt-Chg+6-bcc-Fe.sout
#SBATCH --job-name=Opt-Chg+6-bcc-Fe
#SBATCH --nodes=1
#~ ##SBATCH --ntasks-per-node=12 
#SBATCH --partition=AMD24
#SBATCH --exclude=node18,node20

export LD_LIBRARY_PATH=/opt/mpich-3.3.2/lib:/opt/intel/mkl/lib/intel64:$LD_LIBRARY_PATH
export PATH=/opt/mpich-3.3.2/bin:$PATH
#sed_anchor02
mpiexec /opt/QEGCC_MPICH3.3.2/bin/pw.x -in Opt-Chg+6-bcc-Fe.in




