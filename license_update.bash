#!/usr/bin/bash

echo "Command name is ${0}"

# Sanity Check Arguments
if [ $# -lt 2 ]
  then
    echo "Error: Incorrect Usage"
    echo "  ${0} <cur_licence> <update_licence>"
    echo "    <cur_licence>    == Existing licence file being used today."
    echo "    <update_licence> == License file containing udpdated licence FEATURE lines."

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

###################################
# Populate Variables from arguments
###################################
cur_lic="$1"
output_lic="${cur_lic}.tmp"
update_lic="$2"
debug=0

feature_cnt=$(grep -c "^FEATURE" ${cur_lic})
echo "Processing ${feature_cnt} FEATUREs from current licence file : ${cur_lic}"
echo "  Outputting to file                              : ${output_lic}"
echo "  Updating with FEATURE lines from from           : ${update_lic}"
echo ""

##################################
#Initialise some global variables
##################################

reporting_text=""
proc_feature_cnt=0
proc_feature_line=0
feature_name=""
feature_line_num=0
FEATURE_regexp="^FEATURE"

######################### 
# Functions
#########################

# Function: append_line
# 
# Purpose: Write Line to File
# 
# Parameters:
#   Arg 1 : Text to write to file
#   Arg 2 : File (to write text to)
append_line () {
  local file_to_write=$1
  local line_to_write=$2

#  echo "append_line : Number of args: $#"
#  echo "  File to write = ${file_to_write}"
#  echo "  Line to write = ${line_to_write}"

  echo "${line_to_write}" >> ${file_to_write}
}

# Function: find_feature_line
# 
# Purpose: Find first line number in licence file matching FEATURE 
# returns line number
find_feature_line () {
  local find_feat_name=$1
  local find_file_name=$2

  #echo "In function: find_feature_line()"
  #echo "      FEATURE Name : ${find_feat_name}"
  #echo "    Find File Name : ${find_file_name}"

  for match in $( grep -n " ${find_feat_name} " ${find_file_name} | grep '^[0-9]*:FEATURE' | cut -f1 -d:)
  do
    echo ${match}
    return
  done

  # No match, return 0
  echo 0
}

# Function: find_and_append_feature
# 
# Purpose: Find FEATURE in license file A and append to license file B
# 
# Parameters:
#   Arg 1 : FEATURE name to find
#   Arg 2 : License File A (file to seach)
#   Arg 3 : License File B (file to write to)
find_and_append_feature () {
  local search_feat_name=$1
  local search_file_name=$2
  local write_file_name=$3
  local search_file_line_num=$4

  if [[ ${debug} -gt 0 ]]; then echo "In function: find_and_append_feature() "; fi
  if [[ ${debug} -gt 0 ]]; then echo "      FEATURE Name : ${search_feat_name}"; fi
  if [[ ${debug} -gt 0 ]]; then echo "  Search File Name : ${search_file_name}"; fi
  if [[ ${debug} -gt 0 ]]; then echo "   Write File Name : ${write_file_name}"; fi

  local search_proc_feature_line=0
  local feature_match=0

  #TODO Optimise this function now we are arriving here having already checked that the FEATURE exists and with the line number available
  tail -n +${search_file_line_num} ${search_file_name} | tr -d '\r' | while IFS= read -r search_lic_line; do 

    if [[ ${search_proc_feature_line} -eq 0 ]]; then
      # Not currently processing a FEATURE line

      if [[ ${search_lic_line} =~ ${FEATURE_regexp} ]]; then
        # Current line is a FEATURE line...
        search_proc_feature_line=1
        if [[ ${debug} -gt 0 ]]; then echo "DEBUG SRCH:   FEATURE Match: ${search_lic_line}"; fi

        # Extract FEATURE name...
        feature_name=`echo ${search_lic_line} | cut -d' ' -f 2`
        if [[ ${debug} -gt 0 ]]; then echo "DEBUG SRCH:      FEATURE name is ${feature_name}"; fi


        if [ "${feature_name}" ==  "${search_feat_name}" ]; then
          # This is the FEATURE line we are looking for...
          feature_match=1

          # Append line to new licence
          append_line ${output_lic} "${search_lic_line}"

          if ! [[ "${search_lic_line:${#search_lic_line}-1}" == '\' ]]; then
            # Single Line FEATURE so all done. Return now...
           
            # TODO : Returning like this will leave the file handle open...
            return 1

          fi
        fi
      fi

    else
      # Processing a FEATURE line.
      if [[ ${feature_match} -eq 1 ]]; then
        # Append current line to updated licence file
        append_line ${output_lic} "${search_lic_line}"
      fi

      # ... Check if we have reached the end of the FEATURE row text
      if [[ "${search_lic_line:${#search_lic_line}-1}" == '\' ]]; then
        # Still more lines to current FEATURE row...
        search_proc_feature_line=1
      else
        if [[ ${feature_match} -eq 1 ]]; then
          # Finished processing the target FEATURE. Return....

          # TODO : Returning like this will leave the file handle open...
          return 1
        else
          # Clear the flag for processing multi-line FEATURE
          search_proc_feature_line=0
        fi
      fi
    fi

  done

  # If we get to here, the FEATURE line hasn't been found
  return 0
}

# Write to the new file
# TODO : Check if the file exists and report to user
echo "" > ${output_lic}

cat ${cur_lic} | tr -d '\r' | while IFS= read -r cur_lic_line; do 

  if [[ ${proc_feature_line} -eq 0 ]]; then
    # Not currently processing a FEATURE line

    # Check if current line is a FEATURE line...
    if [[ ${cur_lic_line} =~ ${FEATURE_regexp} ]]; then
      if [[ ${debug} -gt 0 ]]; then echo "DEBUG:   FEATURE Match: ${cur_lic_line}"; fi

      # Extract FEATURE name...
      feature_name=`echo ${cur_lic_line} | cut -d' ' -f 2`
      if [[ ${debug} -gt 0 ]]; then echo "DEBUG:      FEATURE name is ${feature_name}"; fi

      proc_feature_cnt=$((proc_feature_cnt + 1))

      # TODO : Only update if the FEATURE needs updating (i.e. Version and/or Expiry are newer)
      reporting_text="Processing FEATURE ${proc_feature_cnt}"

      # Find line number of FEATURE in licence file
      feature_line_num=$(find_feature_line ${feature_name} ${update_lic})

      if [[ ${debug} -gt 0 ]]; then echo "DEBUG:        Found FEATURE in update licence at line: ${feature_line_num}"; fi

      if [[ "${cur_lic_line:${#cur_lic_line}-1}" == '\' ]]; then
        # Multi-Line FEATURE - take no further action except set the flag to
        # indicate we are processing a FEATURE
        proc_feature_line=1

        if [[ ${feature_line_num} -eq 0 ]] ; then
          # No FEATURE line in updated license file...
          echo "WARNING: ${reporting_text} : Multi-Line FEATURE ${feature_name} does not exist in updated licence file. Keeping Original!"
          append_line ${output_lic} "${cur_lic_line}"
        fi

      else
        if [[ ${feature_line_num} -eq 0 ]] ; then
          # No FEATURE line in updated license file...
          echo "WARNING: ${reporting_text} : Single-Line FEATURE ${feature_name} does not exist in updated licence file. Keeping original!"

          ## ...Keep original!
          append_line ${output_lic} "${cur_lic_line}"
        else 
          echo "${reporting_text} : Updating FEATURE ${feature_name} ..."
          # FEATURE exists in updated licence - add it to the new licence
          find_and_append_feature ${feature_name} ${update_lic} ${output_lic} ${feature_line_num}
        fi
      fi
    else
      # Current line is not a FEATURE line - just append to output file
      append_line ${output_lic} "${cur_lic_line}"
    fi

  else
    # Processing a FEATURE line.

    # ... Check if we have reached the end of the FEATURE row text
    if [[ "${cur_lic_line:${#cur_lic_line}-1}" == '\' ]]; then
      # Still more lines to current FEATURE row...
      proc_feature_line=1

      if [[ ${feature_line_num} -eq 0 ]] ; then
        # Feature is not in updated licence - keep the original line...
        append_line ${output_lic} "${cur_lic_line}"
      fi
    else
      # End of current FEATURE line
      
      if [[ ${feature_line_num} -eq 0 ]] ; then
        # Feature is not in updated licence - keep the original line...
        append_line ${output_lic} "${cur_lic_line}"
      else
        echo "${reporting_text} : Updating FEATURE ${feature_name} ..."

        # FEATURE exists in updated licence - add it to the new licence
        find_and_append_feature ${feature_name} ${update_lic} ${output_lic} ${feature_line_num}
      fi

      # Clear Flags for next FEATURE line
      proc_feature_line=0
      feature_name=""
    fi
  fi

done

