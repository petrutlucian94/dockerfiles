#!/bin/bash

TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}

BUILD_START_DATE=$(date "+$TIMESTAMP_FORMAT")
echo "Build started at $BUILD_START_DATE."

# We'll limit the stdout output, using a file for the full log.
BUILD_LOG="$BUILD_LOG_DIR/build.log"

mkdir -p $BUILD_LOG_DIR
echo "Full log location: $BUILD_LOG"

# Save original fds.
exec 3>&1
exec 4>&2

exec 1> $BUILD_LOG 2>&1

function log_message () {
    echo -e "[$(date "+$TIMESTAMP_FORMAT")] $@"
}

function log_summary () {
    # Use this function to log certain build events, both to the
    # original stdout, as well as the log file.
    log_message "$@" >&3
    log_message "$@"
}

trap err_trap ERR
function err_trap () {
    local r=$?
    set +o xtrace

    log_message "${0##*/} failed. Full log in $BUILD_LOG"
    tail -n 15 $BUILD_LOG >&3

    exit $r
}

function die () {
    set +o xtrace
    log_summary "$@ Full log in $BUILD_LOG"
    exit 1
}

set -eE
set -o xtrace

REQUIRED_ENV_VARS=(AOSP_DIR AOSP_BRANCH \
                   BUILD_LOG_DIR OUTPUT_PACKAGE_DIR \
                   UNITTESTS_ARCHIVE_NAME)
for var in $REQUIRED_ENV_VARS; do
    MISSING_VARS=()

    if [ -z ${!a} ]; then
        MISSING_VARS+=($var)
    fi
done

if [ -z $MISSING_VARS ]; then
    log_summary "The following environment variables must " \
                "be set: ${MISSING_VARS[@]}"
    exit 1
fi

# We'll try to use the same volume as much as possible.
TMP_PKG_DIR="$OUTPUT_PACKAGE_DIR/ae_build_tmp"
log_summary "Using temporary dir: $TMP_PKG_DIR"
rm -rf $TMP_PKG_DIR
mkdir -p $TMP_PKG_DIR

function ensure_repo_installed () {
    # Fetch the Google "repo" tool, which is
    # used to manage dependent git repos.
    if [ ! $(which repo 2> /dev/null) ]; then
        REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"
        curl $REPO_URL > /usr/bin/repo
        chmod a+x /usr/bin/repo;
    fi
}

function sync_aosp_tree () {
    log_summary "Preparing AOSP tree."

    if [ -d $AOSP_DIR ]; then
        echo "AOSP DIR already exists: $AOSP_DIR."
    fi
    mkdir -p $AOSP_DIR

    ensure_repo_installed

    pushd $AOSP_DIR

    # TODO: allow applying extra patches.
    time repo init \
        -u https://android.googlesource.com/platform/manifest \
        -b $AOSP_BRANCH --depth=1
    time repo sync --current-branch

    popd
}

function ensure_ccache_dir () {
    if [ ! -z $CCACHE_DIR ]; then
        mkdir -p $CCACHE_DIR
    else
        echo "CCACHE_DIR not set, disabling ccache."
        export CCACHE_DISABLE="1"
    fi
}

function build_emulator () {
    log_summary "Starting build."

    ensure_ccache_dir

    # Let's make it easier to identify the output package.
    # We'll explicitly set those values, using the defaults.
    PKG_PREFIX="android-emulator"
    PKG_REVISION=$(date +%Y%m%d)
    EXPECTED_AE_PACKAGE="$TMP_PKG_DIR/$PKG_PREFIX-$PKG_REVISION-windows.tar.bz2"

    BUILD_ARGS="$ANDROID_BUILD_ARGS --package-dir=$TMP_PKG_DIR"
    BUILD_ARGS="$BUILD_ARGS --package-prefix=$PKG_PREFIX"
    BUILD_ARGS="$BUILD_ARGS --revision=$PKG_REVISION"

    pushd $AOSP_DIR/external/qemu
    time android/scripts/package-release.sh $BUILD_ARGS

    OUT_PACKAGES=$(find $TMP_PKG_DIR -type f)
    # We'll log all the resulted files, maybe the "package-release.sh script"
    # will change at some point.
    log_summary "Finished building Android Emulator."
    log_summary "Output packages: $OUT_PACKAGES"

    if [ ! -f $EXPECTED_AE_PACKAGE ]; then
        die "Build failed. Could not find expected emulator package:" \
            "$EXPECTED_AE_PACKAGE."
    fi

    AE_PACKAGE="$OUTPUT_PACKAGE_DIR/$EMULATOR_ARCHIVE_NAME"
    mv $EXPECTED_AE_PACKAGE $AE_PACKAGE
    log_summary "Android emulator archive: $AE_PACKAGE"

    popd
}

function package_unitests () {
    log_summary "Packaging unit tests."

    UNITTESTS_PACKAGE_ARCHIVE="$OUTPUT_PACKAGE_DIR/$UNITTESTS_ARCHIVE_NAME"

    pushd $AOSP_DIR/external/qemu/objs
    TMP_FILE_LIST=$(mktemp)
    find . -name "*unittests*" | grep -v "/build" > $TMP_FILE_LIST
    # Those libs get explicity omitted when packaging the emulator,
    # while being required by some of the unit tests.
    find . -name "*emugl_test_shared_library*" | \
        grep -v "/build" >> $TMP_FILE_LIST

    tar -czf $UNITTESTS_PACKAGE_ARCHIVE -T $TMP_FILE_LIST

    log_summary "Android Emulator unit tests archive:" \
                "$UNITTESTS_PACKAGE_ARCHIVE"

    rm -f "$TMP_FILE_LIST"
    popd
}

if [ $SKIP_SYNC_AOSP == "1"]; then
    log_summary "Skipped syncing AOSP tree."
else
    sync_aosp_tree
fi

if [ $SKIP_BUILD == "1" ]; then
    log_summary "Skipped building the emulator."
else
    build_emulator
    package_unitests
fi

rm -rf $TMP_PKG_DIR
set +e

# Restore fds.
exec 1>&3
exec 2>&4
