#!/usr/bin/env bash

INFILE="010_cnt_CntZlibDompressedData"
OFFSET=0

in_data_size=$(stat --printf="%s" "${INFILE}")
echo "Input data size: ${in_data_size}"

while [ $OFFSET -lt $in_data_size ]; do
  type=$(xxd -l 1 -s $(($OFFSET + 1)) "${INFILE}" | awk '{print $2}')
  name_len=$(xxd -l 2 -s $(($OFFSET + 28)) "${INFILE}" | awk '{print $2}' | awk '{split($0,a,"");print a[3]a[4]a[1]a[2]}')
  file_len=$(xxd -l 4 -s $(($OFFSET + 24)) "${INFILE}" | awk '{print $2$3}' | awk '{split($0,a,"");print a[7]a[8]a[5]a[6]a[3]a[4]a[1]a[2]}')
  name_len=$(printf "%d" "0x${name_len}")
  file_len=$(printf "%d" "0x${file_len}")

  echo "Name Length: ${name_len}"
  echo "Type: ${type}"
  echo "File Data Length: ${file_len}"

  fname=$(dd if="${INFILE}" bs=1 skip=$(($OFFSET + 30)) count=$name_len 2>/dev/null)
  echo "File Name: ${fname}"
  
  if [ "${type}" == "81" ]; then
    dd if="${INFILE}" bs=1 skip=$(($OFFSET + $name_len + 30)) count=$file_len of=$(basename "${fname}") 2>/dev/null
  fi

  OFFSET=$(($OFFSET + $name_len + 30 + $file_len))
  echo "End of part offset: ${OFFSET}"
  echo
done
