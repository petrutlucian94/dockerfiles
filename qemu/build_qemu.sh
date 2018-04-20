#!/bin/bash
set -o xtrace

REQUIRED_ENV_VARS=(QEMU_SRC_DIR BUILD_TOP_DIR QEMU_REPO_URL \
                   QEMU_BRANCH QEMU_TARGET_LIST MAKE_JOB_COUNT \
                   WHP_INCLUDE WHP_LIB MAKE_JOB_COUNT)
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

function git_clone_pull () {
    local url=$1
    local path=$2
    local ref=${3:-"master"}

    pushd .

    if [ ! -d $path ]; then
        git clone $url $path
        cd $path
    else
        cd $path

        git remote set-url origin $url
        git reset --hard
        git clean -f -d
        git fetch
    fi

    git checkout $ref

    if [ ! -z $(git tag | grep $ref) ]; then
        echo "Got tag $branch instead of a branch."
        echo "Skipping doing a pull."
    else
        if [ ! -z $(git log -1 --pretty=format:"%H" | grep $ref) ]
        then
            echo "Got a commit id instead of a branch."
            echo "Skipping doing a pull."
        else
            git pull
        fi
    fi

    popd
}

function ensure_build_dir () {
    mkdir -p $DATA_DIR
    if [ ! -z $(echo $QEMU_DEBUG | grep -i "y") ]; then
        QEMU_BUILD_DIR="$BUILD_TOP_DIR/debug"
    else
        QEMU_BUILD_DIR="$BUILD_TOP_DIR/release"
    fi
    export QEMU_BUILD_DIR=$QEMU_BUILD_DIR

    mkdir -p $QEMU_BUILD_DIR
}

function configure_qemu () {
    ensure_build_dir
    pushd $QEMU_BUILD_DIR

    QEMU_CONFIGURE_ARGS=()
    QEMU_CONFIGURE_ARGS+=("--target-list=$QEMU_TARGET_LIST")
    QEMU_CONFIGURE_ARGS+=($QEMU_CONFIGURE_EXTRA_ARGS)

    CROSS_PREFIX=x86_64-w64-mingw32-
    # We'll enforce WHPX for Windows builds
    QEMU_CONFIGURE_ARGS+=("--enable-whpx")
    QEMU_EXTRA_CFLAGS="-I$WHP_INCLUDE $QEMU_EXTRA_CFLAGS"
    QEMU_EXTRA_CFLAGS="-Wno-unknown-pragmas -Wno-undef $QEMU_EXTRA_CFLAGS"
    QEMU_EXTRA_LDFLAGS="-L$WHP_LIB $QEMU_EXTRA_LDFLAGS"

    if [ ! -z $(echo $QEMU_DEBUG | grep -i "y") ]; then
        QEMU_CONFIGURE_ARGS+=("--enable-debug")
    fi

    QEMU_CONFIGURE_ARGS+=("--cross-prefix=$CROSS_PREFIX")
    QEMU_CONFIGURE_ARGS+=("--extra-cflags=$QEMU_EXTRA_CFLAGS")
    QEMU_CONFIGURE_ARGS+=("--extra-ldflags=$QEMU_EXTRA_LDFLAGS")

    "$QEMU_SRC_DIR/configure" "${QEMU_CONFIGURE_ARGS[@]}" || \
         ( tail -n 30 $QEMU_BUILD_DIR/config.log && exit 1 )

    popd
}

function build_qemu () {
    pushd $QEMU_BUILD_DIR
    make -j $MAKE_JOB_COUNT $QEMU_MAKE_EXTRA_ARGS
    echo "Finished building QEMU. Destination: $QEMU_BUILD_DIR"
    popd
}

set -e

git_clone_pull $QEMU_REPO_URL $QEMU_SRC_DIR $QEMU_BRANCH

# windres segfault workaround
sed -i -e 's/IDI_ICON1/\/\/ IDI_ICON1/g' $QEMU_SRC_DIR/version.rc

configure_qemu
build_qemu

set +e
