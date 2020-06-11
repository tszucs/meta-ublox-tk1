#!/usr/bin/env bash
#
# Create a file containing an ext3 binary blob with the contents of a specified folder.
#

set -e
here="$(dirname $(readlink -m ${BASH_SOURCE[0]}))"

function print_help() {
    cat << EOF
Create a file containing an ext3 binary blob with the contents of a specified folder.

Usage: $0 [Options] name dir

Positional Arguments
    name        Name of the created file.
    dir         The content of this directory will be copied to the created filesystem.

Optional Arguments
    -h          Show this message and exit.
    -s size     Size of the created image file in MB. Default: 256.
EOF
}


function on_error() {
    echo -e $1 1>&2
    exit 1
}


function parse_args() {
    img_size=256
    while getopts "::hs:" opt; do
        case ${opt} in
            h)  print_help
                exit 0
                ;;
            s)  img_size=${OPTARG}
                ;;
            ?)  on_error "Error: Invalid option: -${OPTARG}"
                ;;
        esac
    done

    shift $((OPTIND-1))
    [[ $# -eq 2 ]] || on_error "Error: Missing arguments."

    img_file=$(readlink -m $1)
    img_content=$(readlink -m $2)

    [[ -d ${img_content} ]] || on_error "Error: Directory does not exist: ${img_content}"
}


function find_filepath() {
    local file="$1"
    if command -v "${file}" > /dev/null; then
        echo "${file}"
    elif test -x "/sbin/${file}"; then
        echo "/sbin/${file}"
    else
        return 1
    fi
}


# MAIN
parse_args $@

echo -e "\nCreating image file ${img_file}. Size: ${img_size}MB"

# ensure necessary tools are available
mkfs_ext3=$(find_filepath "mkfs.ext3") || on_error "Error: Program mkfs.ext3 is not available."
tune2fs=$(find_filepath "tune2fs") || on_error "Error: Program tune2fs is not available."
dd=$(find_filepath "dd") || on_error "Error: Program dd is not available."
cp2ext2=${here}/pyext2/cp2ext2.py

# create the image file and format it as ext3
${dd} if=/dev/zero of="${img_file}" bs=1024k count=${img_size}
${mkfs_ext3} -F -L rootfs "${img_file}"
${tune2fs} -c 0 -i 0 "${img_file}"

echo -e "\nCopying files to the image"

success=1
${cp2ext2} -g root -u root -m ${img_file} / ${img_content}/* || success=0

[[ ${success} -eq 0 ]] && on_error "Error: Could not copy all files to the image."
echo "Successfully copied files to the image."

exit 0
