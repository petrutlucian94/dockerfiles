FROM opensuse:leap
RUN zypper repos | grep -q mingw || zypper -n addrepo \
    "http://download.opensuse.org/repositories/windows:/mingw:/win64/openSUSE_Leap_42.3/" mingw
RUN zypper --gpg-auto-import-keys refresh

ENV MINGW_PACKAGES \
    mingw64-binutils mingw64-cpp mingw64-cross-binutils mingw64-cross-cpp \
    mingw64-cross-gcc mingw64-cross-pkg-config mingw64-filesystem \
    mingw64-gcc mingw64-glib2 mingw64-glib2-devel mingw64-glib2-lang \
    mingw64-headers mingw64-libgcc mingw64-libgmp mingw64-libintl-devel \
    mingw64-libmpc mingw64-libmpfr mingw64-libSDL2-devel  \
    mingw64-libssp mingw64-runtime mingw64-zlib mingw64-zlib-devel mingw64-pixman-devel
ENV EXTRA_PACKAGES \
    binutils git make
#     texinfo gettext ccache python-yaml sparse
RUN zypper install -y $MINGW_PACKAGES $EXTRA_PACKAGES
# ENV FEATURES clang pyyaml

ENV DATA_DIR "/data"
ENV LOCAL_DATA "/local_data"
ENV QEMU_SRC_DIR "$DATA_DIR/qemu"
ENV BUILD_TOP_DIR "$DATA_DIR/build"
ENV QEMU_REPO_URL "https://github.com/qemu/qemu"
ENV QEMU_BRANCH "master"
ENV QEMU_TARGET_LIST "x86_64-softmmu"
ENV QEMU_DEBUG "no"
ENV QEMU_EXTRA_CFLAGS ""
ENV QEMU_EXTRA_LDFLAGS ""
ENV MAKE_JOB_COUNT "2"
ENV WHP_INCLUDE "$LOCAL_DATA/whp_include"
ENV WHP_LIB "$LOCAL_DATA/whp_lib"

ENV QEMU_CONFIGURE_EXTRA_ARGS=""
ENV QEMU_MAKE_EXTRA_ARGS=""
ENV QEMU_EXTRA_CLFAGS "-Wno-missing-braces -Wno-aggressive-loop-optimizations"

LABEL description="QEMU MINGW build image. Use this image to cross-compile \
QEMU for Windows. \
The QEMU repo clone as well as resulted builds will be stored at the path \
pointed by the DATA_DIR environment variable. Optionally, this may point \
to a mounted volume, which will speed up subsequent builds and simplify \
retrieving the output binaries."

RUN mkdir -p $LOCAL_DATA/scripts
COPY build_qemu.sh $LOCAL_DATA/scripts/
COPY whp_include $LOCAL_DATA/whp_include
COPY whp_lib $LOCAL_DATA/whp_lib

RUN chmod a+x $LOCAL_DATA/scripts/build_qemu.sh

ENTRYPOINT $LOCAL_DATA/scripts/build_qemu.sh
