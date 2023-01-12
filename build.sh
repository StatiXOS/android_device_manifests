# !/usr/bin/env bash
#
# Copyright (c) 2012, The Linux Foundation. All rights reserved.
# Copyright (C) 2023, StatiXOS
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit

usage() {
cat <<USAGE

Usage:
    bash $0 <TARGET_PRODUCT> [OPTIONS]

Description:
    Builds Android tree for given TARGET_PRODUCT

OPTIONS:
    -c, --clean_build
        Clean build - build from scratch by removing entire out dir

    -d, --debug
        Enable debugging - captures all commands while doing the build

    -h, --help
        Display this help message

    -i, --image
        Specify image to be build/re-build (bootimg/sysimg/usrimg)

    -j, --jobs
        Specifies the number of jobs to run simultaneously (Default: 8)

    -l, --log_file
        Log file to store build logs (Default: <TARGET_PRODUCT>.log)

    -m, --module
        Module to be build

    -u, --update-api
        Update APIs

    -v, --build_variant
        Build variant (Default: userdebug)

USAGE
}

clean_build() {
    echo -e "\nINFO: Removing entire out dir. . .\n"
    m clobber
}

build_android() {
    echo -e "\nINFO: Build Android tree for $TARGET\n"
    m $@ | tee $LOG_FILE.log
}

build_bootimg() {
    echo -e "\nINFO: Build bootimage for $TARGET\n"
    m bootimage $@ | tee $LOG_FILE.log
}

build_sysimg() {
    echo -e "\nINFO: Build systemimage for $TARGET\n"
    m systemimage $@ | tee $LOG_FILE.log
}

build_usrimg() {
    echo -e "\nINFO: Build userdataimage for $TARGET\n"
    m userdataimage $@ | tee $LOG_FILE.log
}

build_module() {
    echo -e "\nINFO: Build $MODULE for $TARGET\n"
    m $MODULE $@ | tee $LOG_FILE.log
}

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

update_api() {
    echo -e "\nINFO: Updating APIs\n"
    m update-api | tee $LOG_FILE.log
}

# Set defaults
VARIANT="userdebug"
JOBS=8

# Setup getopt.
long_opts="clean_build,debug,help,image:,jobs:,log_file:,module:,"
long_opts+="update-api,build_variant:"
getopt_cmd=$(getopt -o cdhi:j:k:l:m:p:s:uv: --long "$long_opts" \
            -n $(basename $0) -- "$@") || \
            { echo -e "\nERROR: Getopt failed. Extra args\n"; usage; exit 1;}

eval set -- "$getopt_cmd"

while true; do
    case "$1" in
        -c|--clean_build) CLEAN_BUILD="true";;
        -d|--debug) DEBUG="true";;
        -h|--help) usage; exit 0;;
        -i|--image) IMAGE="$2"; shift;;
        -j|--jobs) JOBS="$2"; shift;;
        -l|--log_file) LOG_FILE="$2"; shift;;
        -m|--module) MODULE="$2"; shift;;
        -u|--update-api) UPDATE_API="true";;
        -v|--build_variant) VARIANT="$2"; shift;;
        --) shift; break;;
    esac
    shift
done

# Mandatory argument
if [ $# -eq 0 ]; then
    echo -e "\nERROR: Missing mandatory argument: TARGET_PRODUCT\n"
    usage
    exit 1
fi
if [ $# -gt 1 ]; then
    echo -e "\nERROR: Extra inputs. Need TARGET_PRODUCT only\n"
    usage
    exit 1
fi
TARGET="$1"; shift

if [ -z $LOG_FILE ]; then
    LOG_FILE=$TARGET
fi

CMD="-j $JOBS"
if [ "$DEBUG" = "true" ]; then
    CMD+=" showcommands"
fi

source build/envsetup.sh

if [ -d "device/*/$TARGET" ]; then
    echo "Device tree found"
else
    echo "Checking if tree exists in manifests"
    if test -f "device/manifests/$TARGET.xml"; then
        echo "Syncing $TARGET trees"
        # Clear older manifests
        if ![ -d .repo/local_manifests]; then
            mkdir -p .repo/local_manifests/
        else
            rm -rf .repo/local_manifests/*.xml
        fi
        cp device/manifests/$TARGET.xml .repo/local_manifests/$TARGET.xml
        repo sync --no-tags --no-clone-bundle -j${JOBS} || exit_on_error
    fi
fi

lunch statix_$TARGET-$VARIANT || exit_on_error

if [ "$CLEAN_BUILD" = "true" ]; then
    clean_build
fi

if [ "$UPDATE_API" = "true" ]; then
    update_api
fi

if [ -n "$MODULE" ]; then
    build_module "$CMD"
fi

if [ -n "$IMAGE" ]; then
    build_$IMAGE "$CMD"
fi

build_android "$CMD"
