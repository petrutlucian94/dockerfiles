#!/bin/bash
set -o xtrace

REQUIRED_ENV_VARS=(AOSP_DIR AOSP_BRANCH)
for var in $REQUIRED_ENV_VARS; do
    MISSING_VARS=()

    if [ -z ${!a} ]; then
        MISSING_VARS+=($var)
    fi
done

if [ -z $MISSING_VARS ]; then
    echo "The following environment variables must be set: ${MISSING_VARS[@]}"
    exit 1
fi

function ensure_repo_installed () {
    # Fetch the Google "repo" tool, which is used to manage dependent git repos.
    # We'll avoid using 'which' for now, most probably it will be missing.
    if [ ! $(which repo 2> /dev/null) ]; then
        curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
        chmod a+x /usr/bin/repo;
    fi
}

function sync_aosp_tree () {
    if [ -d $AOSP_DIR ]; then
        echo "AOSP DIR already exists: $AOSP_DIR."
    fi
    mkdir -p $AOSP_DIR

    ensure_repo_installed

    pushd $AOSP_DIR

    # TODO: allow applying extra patches.
    time repo init -u https://android.googlesource.com/platform/manifest \
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
    ensure_ccache_dir

    pushd $AOSP_DIR/external/qemu
    time ./android/rebuild.sh $ANDROID_BUILD_ARGS
    # TODO: We should package it.
    echo "Finished building Android Emulator. Destination: $AOSP_DIR/external/qemu/objs"
    popd
}

set -e

sync_aosp_tree
build_emulator

set +e
