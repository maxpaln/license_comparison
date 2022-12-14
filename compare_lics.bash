#!/usr/bin/bash

# Sanity Check Arguments
if [ $# -lt 2 ]
  then
    echo "Error: Incorrect Usage"
    echo "  lic_compare.bash <old_licence> <new_licence>"

    exit 1
else
  if [ ! -f "$1" ]; then
    echo "File not found: $1"
    exit 1
  fi
  if [ ! -f "$2" ]; then
    echo "File not found: $2"
    exit 1
  fi
fi

old_lic="$1"
old_lic_tmp="$1.cmp"
new_lic="$2"
new_lic_tmp="$2.cmp"
tmp_dir="lic_compare_tmp"

echo $old_lic
echo $new_lic

# Check if temp dir exists - cleanup or create...
if [[ -d "$tmp_dir" ]]
then
  if [[ `ls -1 lic_compare_tmp | wc -l` -gt 0 ]]
  then
    echo "Previous temp files exist. Removing..."
    rm -r $tmp_dir/*
  fi
else
  mkdir $tmp_dir
fi

grep "FEATURE" $old_lic | awk '{print $2}' | sort | uniq > $tmp_dir/$old_lic_tmp
grep "FEATURE" $new_lic | awk '{print $2}' | sort | uniq > $tmp_dir/$new_lic_tmp

# Summarise Floating / Node locked and Expiry
if [[ `grep -c DAEMON $old_lic` -eq 0 ]]
then
  if [[ `grep -c DAEMON $new_lic` -ne 0 ]]
  then
    echo "***********************************************************"
    echo "ERROR: New Licence is Floating. Old licence was Node Locked"
    echo "***********************************************************"
  fi
else
  if [[ `grep -c "DAEMON lattice" $new_lic` -ne 1 ]]
  then
    echo "***********************************************************"
    echo "ERROR: Old licence was Floating. New licence is missing Floating licence for Lattice FEATUREs"
    echo "***********************************************************"
  fi
  if [[ `grep -c "DAEMON mgcld" $new_lic` -ne 1 ]]
  then
    echo "***********************************************************"
    echo "ERROR: Old licence was Floating. New licence is missing Floating licence for Modelsim FEATUREs"
    echo "***********************************************************"
  fi
fi

echo_feature=0
feature_diffs=0

echo ""
echo "Summary of FEATURE comparison:"
for diff_line in $(diff $tmp_dir/$old_lic_tmp $tmp_dir/$new_lic_tmp)
do
  # Report Features that have been added
  if [[ $echo_feature -eq 1 ]]
  then
    echo "  FEATURE added: $diff_line"
    feature_diffs=1
  fi

  # Report Features that have been removed
  if [[ $echo_feature -eq 2 ]]
  then
    echo "  WARNING: FEATURE removed: $diff_line"
    feature_diffs=1
  fi

  # Check if next line contains features that have been removed
  if [[ `echo $diff_line | grep -c "<"` -gt 0 ]]
  then
    echo_feature=2
  else
    # Check if next line contains features that have been added
    if [[ `echo $diff_line | grep -c ">"` -gt 0 ]]
    then
      echo_feature=1
    else
      echo_feature=0
    fi
  fi
done

if [[ ${feature_diffs} -eq 0 ]]
then
  echo "  All FEATURE lines remain present in new licence"
fi

# Report Feature Lines Expiry Dates in New Licence
echo ""
echo "Expiry dates present in new licence: $new_lic"
for exp_date in $(grep "FEATURE" $new_lic | awk '{print $5}' | sort | uniq)
do
  exp_date_cnt=`grep "FEATURE" $new_lic | awk '{print $5}' | grep -c ${exp_date}`
  echo "  $exp_date : ${exp_date_cnt} FEATURE lines"
done

# Report Feature Lines Version Number in New Licence
echo ""
echo "Version Numbers present in new licence: $new_lic"
for version in $(grep "FEATURE" $new_lic | awk '{print $4}' | sort | uniq)
do
  version_num=`grep "FEATURE" $new_lic | awk '{print $4}' | grep -c ${version}`
  echo "  $version : ${version_num} FEATURE lines"
done


# Clean Up
rm -rf $tmp_dir
