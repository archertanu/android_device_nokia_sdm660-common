#!/bin/bash
#
# Copyright (C) 2019-2020 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

DEVICE_COMMON=sdm660-common
VENDOR=nokia

INITIAL_COPYRIGHT_YEAR=2019

# Check host-OS before doing anything
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM='linux-x86'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM='darwin-x86'
fi

# Load extractutils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

LINEAGE_ROOT="$MY_DIR"/../../..

HELPER="$LINEAGE_ROOT"/vendor/lineage/build/tools/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

# Use prebuilts from tools-lineage
TOOLS_LINEAGE="$LINEAGE_ROOT"/prebuilts/tools-lineage/"$PLATFORM"/bin
PATCHELF="$TOOLS_LINEAGE"/patchelf

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "$1" != "" ]; do
    case $1 in
        -p | --path )           shift
                                SRC=$1
                                ;;
        -s | --section )        shift
                                SECTION=$1
                                CLEAN_VENDOR=true
                                ;;
        -n | --no-cleanup )     CLEAN_VENDOR=false
                                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

function blob_fixup() {
    case "${1}" in
    product/lib64/libdpmframework.so)
        "$PATCHELF" --add-needed "libshim_dpmframework.so" "${2}"
        ;;
    vendor/lib/hw/camera.sdm660.so)
        "$PATCHELF" --remove-needed "libMegviiFacepp.so" "${2}"
        "$PATCHELF" --remove-needed "libmegface-new.so" "${2}"
        "$PATCHELF" --add-needed "libshim_megvii.so" "${2}"
        ;;
    vendor/etc/nfcee_access.xml)
        sed -i 's|xliff="urn:oasis:names:tc:xliff:document:1.2"|android="http://schemas.android.com/apk/res/android"|' "${2}"
        ;;
    esac
}

# Initialize the helper for common device
setup_vendor "$DEVICE_COMMON" "$VENDOR" "$LINEAGE_ROOT" true $CLEAN_VENDOR

extract "$MY_DIR"/proprietary-files.txt "$SRC" "$SECTION"

# Initialize the helper for device
setup_vendor "$DEVICE" "$VENDOR" "$LINEAGE_ROOT" false $CLEAN_VENDOR

extract "$MY_DIR"/../$DEVICE/proprietary-files.txt "$SRC" "$SECTION"

"$MY_DIR"/setup-makefiles.sh
