#!/bin/bash

TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}

BUILD_START_DATE=$(date "+$TIMESTAMP_FORMAT")
echo "Build started at $BUILD_START_DATE."

# We'll limit the stdout output, using a file for the full log.
BUILD_LOG_LNK="$BUILD_LOG_DIR/build.log"
BUILD_LOG="$BUILD_LOG_DIR/build.$BUILD_START_DATE.log"

mkdir -p $BUILD_LOG_DIR
ln -s -f $BUILD_LOG $BUILD_LOG_LNK

echo "Full log location: $BUILD_LOG_LNK"

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

set -e
set -o xtrace

REQUIRED_ENV_VARS=(AOSP_DIR AOSP_BRANCH \
                   BUILD_LOG_DIR OUTPUT_PACKAGE_DIR)
for var in $REQUIRED_ENV_VARS; do
    MISSING_VARS=()

    if [ -z ${!a} ]; then
        MISSING_VARS+=($var)
    fi
done

if [ -z $MISSING_VARS ]; then
    log_summary "The following environment variables must be set: ${MISSING_VARS[@]}"
    exit 1
fi

function ensure_repo_installed () {
    # Fetch the Google "repo" tool, which is used to manage dependent git repos.
    if [ ! $(which repo 2> /dev/null) ]; then
        curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
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

    PKG_DIR="$OUTPUT_PACKAGE_DIR/$BUILD_START_DATE"
    BUILD_ARGS="$ANDROID_BUILD_ARGS --package-dir=$PKG_DIR"

    mkdir -p $PKG_DIR

    pushd $AOSP_DIR/external/qemu
    time android/scripts/package-release.sh $BUILD_ARGS

    OUT_PACKAGES=$(find $PKG_DIR -type f)
    if [ -z $OUT_PACKAGES ]; then
        die "Build failed."
    fi

    log_summary "Finished building Android Emulator."
    log_summary "Output packages: $OUT_PACKAGES"
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
fi

set +e

# Restore fds.
exec 1>&3
exec 2>&4
