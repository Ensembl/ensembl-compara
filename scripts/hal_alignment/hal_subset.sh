#!/usr/bin/env bash
set -e

if [[ $# -ne 4 ]]
then
    echo "Usage: $0 INPUT_HAL SUBTREE_ROOT_FILE DROP_LIST_FILE OUTPUT_HAL"
    exit 1;
fi

input_hal="$1"
subtree_root_file="$2"
drop_list_file="$3"
output_hal="$4"

output_basename=$(basename "${output_hal}" .hal)

tmp_dir=$(mktemp -d "${output_basename}.tmp.XXXXXXXXXX")
trap "rm -fr $tmp_dir" EXIT

subtree_root_genome=$(head -1 "$subtree_root_file")
subset_hal_path="${tmp_dir}/${output_basename}.subset.hal"
halExtract --root ${subtree_root_genome} ${input_hal} "${subset_hal_path}"

while read -r genome
do halRemoveGenome "$subset_hal_path" "$genome"
done < "$drop_list_file"

# Repack the subset HAL file to save space.
repack_hal_path="${tmp_dir}/${output_basename}.repack.hal"
h5repack "$subset_hal_path" "$repack_hal_path"

halValidate "$repack_hal_path"

# With subsetting and validation done, write the final HAL file.
mv "$repack_hal_path" "$output_hal"
