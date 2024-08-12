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
perp_ip_expiry="30-dec-2100"

echo "Comparing..."
echo "  Old License: ${old_lic}"
echo "  New License: ${new_lic}"
echo ""

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

old_server_num=`grep -c "^SERVER" $old_lic`
new_server_num=`grep -c "^SERVER" $new_lic`

# Summarise SERVER Information
if [[ ${old_server_num} -eq 0 ]]
then
  echo "*********************************************************************************************************************"
  echo "WARNING: Old Licence has no SERVER information. Unable to validate if new Licence has correct number of SERVER Lines."
  echo "*********************************************************************************************************************"
else
  if [[ ${new_server_num} -ne ${old_server_num} ]]
  then
    echo "***************************************************************************"
    echo "WARNING: Old Licence and New Licence have different number of SERVER lines."
    echo "***************************************************************************"
  else
    echo "**********************"
    echo "Number of SERVERs: ${new_server_num}"
    echo "**********************"
  fi
fi

# TODO : Check MAC address

# Summarise Floating / Node locked and Expiry
if [[ `grep -c "DAEMON lattice" $old_lic` -eq 0 ]]
then
  if [[ `grep -c "DAEMON lattice" $new_lic` -ne 0 ]]
  then
    echo "******************************************************************************************"
    echo "WARNING: Old licence was Node Locked. New Licence has Floating seats for Lattice FEATURES."
    echo "******************************************************************************************"
  fi
else
  if [[ `grep -c "DAEMON lattice" $new_lic` -ne 1 ]]
  then
    echo "*********************************************************************************************"
    echo "WARNING: Old licence was Floating. New licence is missing Floating licence for Lattice FEATUREs"
    echo "*********************************************************************************************"
  fi
  if [[ `grep -c "DAEMON mgcld" $new_lic` -ne 1 ]]
  then
    echo "**********************************************************************************************"
    echo "ERROR: Old licence was Floating. New licence is missing Floating licence for Modelsim FEATUREs"
    echo "**********************************************************************************************"
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

# Report Feature Lines Version Number in New Licence
echo ""
echo "Version Numbers present in new licence: $new_lic"
for version in $(fgrep "FEATURE" $new_lic | awk '{print $4}' | sort | uniq)
do
  version_num=`fgrep "FEATURE" $new_lic | awk '{print $4}' | grep -c ${version}`
  echo "  $version : ${version_num} FEATURE lines"
done

# Report Feature Lines Expiry Dates in New Licence
echo ""
echo "Expiry dates present in new licence: $new_lic"
for exp_date in $(fgrep "FEATURE" $new_lic | awk '{print $5}' | sort | uniq)
do
  exp_date_cnt=`fgrep "FEATURE" $new_lic | awk '{print $5}' | grep -c ${exp_date}`
  echo "  $exp_date : ${exp_date_cnt} FEATURE lines"
done

# Check for Perpetual FEATURE lines in original have been carried over to New License
echo ""
for exp_date in $(fgrep "FEATURE" $old_lic | awk '{print $2"#"$5}' | sort | uniq)
do
  if [[ ${exp_date} =~ .*"#${perp_ip_expiry}" ]]
  then
    perp_feature=$(echo ${exp_date} | cut -d'#' -f 1)
    new_exp_date=`fgrep -m 1 "FEATURE ${perp_feature}" ${new_lic} | cut -d' ' -f 5`
    
    if [ "${new_exp_date}" != "${perp_ip_expiry}" ]
    then
      echo "ERROR : New license has incorrect expiry date (${new_exp_date}) for perpetual FEATURE : ${perp_feature} "
    fi
  fi
done

if [[ ${new_server_num} -gt 0 ]]
then
  # Report Number of Seats in New Licence
  seat_cnt=0
  new_seats=0
  echo ""
  # TODO - try improving performance by capturing multiple fields in each fgrep return as above for perpetual expiry
  echo "Number of Seats per FEATURE present in new licence: $new_lic"
  echo " Format : Seats : <# New Seats> (<# Old_Seats>) : <Feature Name>"
  for new_lic_feature in $(fgrep "FEATURE" $new_lic | awk '{print $2}' | sort | uniq)
  do
    old_seats=`fgrep -m 1 "FEATURE ${new_lic_feature}" $old_lic | cut -d' ' -f 6 | uniq`
    new_seats=`fgrep -m 1 "FEATURE ${new_lic_feature}" $new_lic | cut -d' ' -f 6 | uniq`

    #if [[ ${old_seat_exists} -ne 0 ]] 
    if ! [[ -z ${old_seats} ]] 
    then 
      #old_seats=`fgrep -m 1 "FEATURE ${new_lic_feature}" $old_lic | cut -d' ' -f 6 | uniq`
      #new_seats=`fgrep -m 1 "FEATURE ${new_lic_feature}" $new_lic | cut -d' ' -f 6 | uniq`

      if [[ ${new_seats} -lt ${old_seats} ]]
      then
        seat_cnt=${seat_cnt}+1;
        echo "  WARNING: Seats: ${new_seats} (${old_seats}) : ${new_lic_feature} :: New Licence has less seats than old licence"
      else
        if [[ ${new_seats} -gt ${old_seats} ]]
        then
          seat_cnt=${seat_cnt}+1;
          echo "NOTE: Seats: ${new_seats} (${old_seats}) : ${new_lic_feature} :: New License has more seats than old licence"
        else
          echo "Seats: ${new_seats} (${old_seats}) : ${new_lic_feature}"
        fi
      fi
    else
      #new_seats=`fgrep -m 1 "FEATURE ${new_lic_feature}" $new_lic | cut -d' ' -f 6 | uniq`
      echo "NOTE: Seats: ${new_seats} (0) : ${new_lic_feature} :: New License has added this FEATURE"
    fi
    if [[ ${seat_cnt} -eq 10 ]]
    then
      echo "  WARNING: Too many seat count differences. Skipping..."
      break
    fi
  done

  if [[ ${seat_cnt} -eq 0 ]]
  then
    echo "  ALL FEATURE license in new licence file have ${new_seats} seats"
  fi
fi

# Clean Up
rm -rf $tmp_dir
