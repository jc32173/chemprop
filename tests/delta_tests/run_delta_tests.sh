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

#
exit_with_error () {
    echo "Testing script failed on $1 with exit code $2."
}
#trap 'exit_with_error $LINENO $?' ERR

#module purge
#module load Anaconda3/5.1.0
#eval "$(conda shell.bash hook)"
#conda activate PP

#module purge
#module load Anaconda3 GNINA
#conda deactivate
#source deactivate
#source activate working

test_end_msg=\
"\n-----------"\
"\n COMPLETED "\
"\n-----------"

export PATH="/hpc/home/jwc81/repos/chemprop_code/chemprop_v205":$PATH
export PYTHONPATH="/hpc/home/jwc81/repos/chemprop_code/chemprop_v205/chemprop":$PYTHONPATH

export PYTHONPATH="/hpc/home/jwc81/repos":$PYTHONPATH
export PYTHONPATH="/hpc/home/jwc81/scripts/sys_scripts/slurm":$PYTHONPATH

echo -e "\nTesting on ChEMBL data (DeltaClassifier benchmark)...\n"

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
	       --delta \
	       -qq

echo -e ${test_end_msg}

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
                 --delta \
		 -qq

echo ""
echo "Check predictions from 'chemprop train --delta' and 'chemprop predict --delta' are the same:"
diff -sq <(awk -F, '{print $1","$5","$9}' delta/delta_preds.csv) delta/model_0/test_predictions.csv || \
(exitcode=$?
 echo "**************************"
 echo " ERROR: Check diff output"
 echo "**************************"
 exit $exitcode)
echo -e ${test_end_msg}

echo "======================================"
echo " TESTING chemprop fingerprint --delta"
echo "======================================"

chemprop fingerprint -i data/CHEMBL3710-Curated_splits_test_only.csv \
                     --smiles-columns SMILES \
                     --model-path delta/model_0/best.pt \
                     --num-workers 0 \
                     -o delta/delta_pred_fps.csv \
		     --ffn-block-index 0 \
                     --molecule-featurizers rdkit_2d \
                     --delta \
		     -qq

echo -e ${test_end_msg}

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
	       --relation-column Relation \
	       -qq

echo -e ${test_end_msg}

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
	       --relation-column Relation \
	       -qq

echo ""
echo "Check predictions from 'chemprop train --deltaclass' and 'chemprop predict --deltaclass' are the same:"
diff -sq <(awk -F, '{print $1","$5","$9","$10}' deltaclass/deltaclass_preds.csv) deltaclass/model_0/test_predictions.csv || \
(exitcode=$?
 echo "**************************"
 echo " ERROR: Check diff output"
 echo "**************************"
 exit $exitcode)
echo -e ${test_end_msg}

echo -e "\nTesting on nanoparticle data...\n"

echo "================================"
echo " TESTING chemprop train --delta"
echo "================================"

mkdir -p delta_NP
chemprop train -i data/curated_drug_loading_test.csv \
	       --smiles-columns excipient_smiles drug_smiles \
	       --target-columns "drug_loading mean" \
	       --epochs 3 \
	       --num-workers 0 \
	       --molecule-featurizers rdkit_2d \
	       --save-dir delta_NP/ \
	       --pytorch-seed 141 \
	       --task-type "regression" \
               --delta \
	       -qq

echo -e ${test_end_msg}

# TODO: Predefine test data in curated_drug_loading.csv to make predictions on same datapoints and compare results
#echo "=================================="
#echo " TESTING chemprop predict --delta"
#echo "=================================="
#
#chemprop predict -i data/curated_drug_loading_test.csv \
#                 --smiles-columns excipient_smiles drug_smiles \
#	         --target-columns "drug_loading mean" \
#                 --model-path delta_NP/model_0/best.pt \
#                 --num-workers 0 \
#                 -o delta_NP/delta_preds.csv \
#                 --molecule-featurizers rdkit_2d \
#                 --delta
#
#echo ""
#echo "Check predictions from 'chemprop train --delta' and 'chemprop predict --delta' are the same:"
#diff -sq <(awk -F, '{print $1","$5","$9}' delta_NP/delta_preds.csv) delta_NP/model_0/test_predictions.csv || \
#(exitcode=$?
# echo "**************************"
# echo " ERROR: Check diff output"
# echo "**************************"
# exit $exitcode)
#echo -e ${test_end_msg}

echo "========================================================"
echo " TESTING chemprop train --delta --delta-pairs-subsample"
echo "========================================================"

mkdir -p delta_subsample
chemprop train -i data/curated_drug_loading_test.csv \
	       --smiles-columns excipient_smiles drug_smiles \
	       --target-columns "drug_loading mean" \
	       --epochs 3 \
	       --num-workers 0 \
	       --molecule-featurizers rdkit_2d \
	       --save-dir delta_subsample/ \
	       --pytorch-seed 141 \
	       --task-type "regression" \
	       --delta-pairs-subsample 0.1 \
	       --delta |& tee delta_subsample/stdout.out

test_stdout_string="Delta model training dataset contains 26 delta pairs (generated from a training dataset of 16 individual datapoints (=256 potential total pairs))"
grep -q "${test_stdout_string}" delta_subsample/stdout.out || exitcode=$?
echo 'Check number of pairs in training set following subsampling:'
echo 'Expected: "'${test_stdout_string}'"'
echo 'Got:      "'$(grep -o "Delta model training dataset contains .*" delta_subsample/stdout.out)'"'
if [ "${exitcode}" != "" ]
then
    echo "************************************************"
    echo " ERROR: Check number of pairs after subsampling"
    echo "************************************************"
    exit $exitcode
fi
echo -e ${test_end_msg}

echo "====================================================="
echo " TESTING chemprop train --delta --delta-group-column"
echo "====================================================="

mkdir -p delta_group
chemprop train -i data/curated_drug_loading_test.csv \
	       --smiles-columns excipient_smiles drug_smiles \
	       --target-columns "drug_loading mean" \
	       --epochs 3 \
	       --num-workers 0 \
	       --molecule-featurizers rdkit_2d \
	       --save-dir delta_group/ \
	       --pytorch-seed 141 \
	       --task-type "regression" \
               --delta-group-column "Excipient" \
	       --delta |& tee delta_group/stdout.out

test_stdout_string="Delta model training dataset contains 178 delta pairs (generated from a training dataset of 16 individual datapoints (=256 potential total pairs), separated into 2 groups)"
grep -q "${test_stdout_string}" delta_group/stdout.out || exitcode=$?
echo 'Check number of pairs in training set following grouped delta pairing:'
echo 'Expected: "'${test_stdout_string}'"'
echo 'Got:      "'$(grep -o "Delta model training dataset contains .*" delta_group/stdout.out)'"'
if [ "${exitcode}" != "" ]
then
    echo "*********************************************"
    echo " ERROR: Check number of pairs after grouping"
    echo "*********************************************"
    exit $exitcode
fi
echo -e ${test_end_msg}

echo "============================================================================="
echo " TESTING chemprop train --delta --delta-group-column --delta-pairs-subsample"
echo "============================================================================="

mkdir -p delta_group_subsample
chemprop train -i data/curated_drug_loading_test.csv \
	       --smiles-columns excipient_smiles drug_smiles \
	       --target-columns "drug_loading mean" \
               --epochs 3 \
               --num-workers 0 \
               --save-dir delta_group_subsample/ \
               --pytorch-seed 141 \
               --molecule-featurizers rdkit_2d \
               --task-type "regression" \
               --delta-group-column "Excipient" \
               --delta-pairs-subsample 0.1 \
               --delta |& tee delta_group_subsample/stdout.out

test_stdout_string="Delta model training dataset contains 17 delta pairs (generated from a training dataset of 16 individual datapoints (=256 potential total pairs), separated into 2 groups)"
grep -q "${test_stdout_string}" delta_group_subsample/stdout.out || exitcode=$?
echo 'Check number of pairs in training set following grouping and subsampling:'
echo 'Expected: "'${test_stdout_string}'"'
echo 'Got:      "'$(grep -o "Delta model training dataset contains .*" delta_group_subsample/stdout.out)'"'
if [ "${exitcode}" != "" ]
then
    echo "*************************************************************"
    echo " ERROR: Check number of pairs after grouping and subsampling"
    echo "*************************************************************"
    exit $exitcode
fi
echo -e ${test_end_msg}

echo "=================================================================================="
echo " TESTING chemprop train --deltaclass --delta-group-column --delta-pairs-subsample"
echo "=================================================================================="

mkdir -p deltaclass_group_subsample
chemprop train -i data/curated_drug_loading_test.csv \
	       --smiles-columns excipient_smiles drug_smiles \
	       --target-columns "drug_loading mean" \
               --epochs 3 \
               --num-workers 0 \
               --save-dir deltaclass_group_subsample/ \
               --pytorch-seed 141 \
               --molecule-featurizers rdkit_2d \
               --task-type "regression" \
               --delta-group-column "Excipient" \
               --delta-pairs-subsample 0.2 \
               --deltaclass |& tee deltaclass_group_subsample/stdout.out

test_stdout_string="Delta model training dataset contains 35 delta pairs (generated from a training dataset of 16 individual datapoints (=256 potential total pairs), separated into 2 groups)"
grep -q "${test_stdout_string}" deltaclass_group_subsample/stdout.out || exitcode=$?
echo 'Check number of pairs in training set following grouping and subsampling:'
echo 'Expected: "'${test_stdout_string}'"'
echo 'Got:      "'$(grep -o "Delta model training dataset contains .*" deltaclass_group_subsample/stdout.out)'"'
if [ "${exitcode}" != "" ]
then
    echo "*************************************************************"
    echo " ERROR: Check number of pairs after grouping and subsampling"
    echo "*************************************************************"
    exit $exitcode
fi
echo -e ${test_end_msg}

echo "====================="
echo " ALL TESTS COMPLETED"
echo "====================="
