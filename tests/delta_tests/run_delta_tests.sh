#!/bin/bash

# Resource allocation:
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=4G
#SBATCH --time=48:00:00
#SBATCH --partition=common,scavenger
# Account not needed on common or scavenger partition:
##SBATCH --account=
# Exclude specific nodes due to poor performance:
##SBATCH --exclude=dcc-gehmlab-gpu-60

##SBATCH --ntasks=1

###SBATCH -p gpu-common
###SBATCH --gres=gpu:1
###SBATCH --exclusive

# Run as an array job:
# (can also do by submitting script using command:
# sbatch --array 0-474 run_brics_array.sh)
##SBATCH --array 0-9

# Redirect stdout (-o) and stderr (-e), default is to direct both to
# "slurm-%j.out" or "slurm-%A_%a.out" for an array job:
##SBATCH -o %j.out
##SBATCH -e %j.err

# Change to directory (-D):
##SBATCH --chdir /hpc/home/jwc81/work/PEGylated_NPs_20250203

# Propogate environment variables to the compute node:
##SBATCH --export=ALL

#SBATCH --job-name=chemprop_tests

# Exit bash script if any commands return an error:
set -e

#module purge
#module load Anaconda3/5.1.0
#eval "$(conda shell.bash hook)"
#conda activate PP

#module purge
#module load Anaconda3 GNINA
#conda deactivate
#source deactivate
#source activate working

export PATH="/hpc/home/jwc81/repos/chemprop_code/chemprop_v205":$PATH
export PYTHONPATH="/hpc/home/jwc81/repos/chemprop_code/chemprop_v205/chemprop":$PYTHONPATH

export PYTHONPATH="/hpc/home/jwc81/repos":$PYTHONPATH
export PYTHONPATH="/hpc/home/jwc81/scripts/sys_scripts/slurm":$PYTHONPATH

echo "================================"
echo " TESTING chemprop train --delta"
echo "================================"

mkdir -p delta
chemprop train -i data/CHEMBL3710-Curated_splits.csv \
	       --smiles-columns SMILES \
	       --target-columns Value \
	       --splits-column Split \
	       --epochs 3 \
	       --num-workers 0 \
	       --save-dir delta/ \
	       --pytorch-seed 141 \
	       --molecule-featurizers rdkit_2d \
	       --task-type "regression" \
               --delta

echo "=================================="
echo " TESTING chemprop predict --delta"
echo "=================================="

chemprop predict -i data/CHEMBL3710-Curated_splits_test_only.csv \
               --smiles-columns SMILES \
               --target-columns Value \
               --model-path delta/model_0/best.pt \
               --num-workers 0 \
               -o delta/delta_preds.csv \
               --molecule-featurizers rdkit_2d \
               --delta

echo "Check predictions from 'chemprop train --delta' and 'chemprop predict --delta' are the same:"
diff -sq <(awk -F, '{print $1","$5","$9}' delta/delta_preds.csv) delta/model_0/test_predictions.csv || \
(exitcode=$?
 echo "**************************"
 echo " ERROR: Check diff output"
 echo "**************************"
 exit $exitcode)

echo "====================================="
echo " TESTING chemprop train --deltaclass"
echo "====================================="

mkdir -p deltaclass
chemprop train -i data/CHEMBL3710-Curated_splits.csv \
	       --smiles-columns SMILES \
	       --target-columns Value \
	       --splits-column Split \
	       --epochs 3 \
	       --num-workers 0 \
	       --save-dir deltaclass/ \
	       --pytorch-seed 141 \
	       --molecule-featurizers rdkit_2d \
	       --task-type "classification" \
	       --deltaclass \
	       --deltaclass-buffer 0.2 \
	       --relation-column Relation

echo "======================================="
echo " TESTING chemprop predict --deltaclass"
echo "======================================="

#chemprop predict -i <(cat <(head -n 1 data/CHEMBL3710-Curated_splits.csv) <(grep "test" data/CHEMBL3710-Curated_splits.csv)) \
chemprop predict -i data/CHEMBL3710-Curated_splits_test_only.csv \
               --smiles-columns SMILES \
	       --target-columns Value \
               --model-path deltaclass/model_0/best.pt \
               --num-workers 0 \
               -o deltaclass/deltaclass_preds.csv \
               --molecule-featurizers rdkit_2d \
               --deltaclass \
	       --relation-column Relation

echo "Check predictions from 'chemprop train --deltaclass' and 'chemprop predict --deltaclass' are the same:"
diff -sq <(awk -F, '{print $1","$5","$9","$10}' deltaclass/deltaclass_preds.csv) deltaclass/model_0/test_predictions.csv || \
(exitcode=$?
 echo "**************************"
 echo " ERROR: Check diff output"
 echo "**************************"
 exit $exitcode)
