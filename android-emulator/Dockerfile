FROM opensuse:42.3
RUN zypper --gpg-auto-import-keys refresh

ENV EXTRA_PACKAGES \
    tar openssl binutils git make which curl \
    python-xml python-pyOpenSSL \
    ccache
#     texinfo gettext ccache python-yaml sparse
RUN zypper install -y $EXTRA_PACKAGES
# ENV FEATURES clang pyyaml

ENV DATA_DIR "/data"
ENV LOCAL_DATA "/local_data"
ENV AOSP_DIR "$DATA_DIR/aosp"
ENV OUTPUT_PACKAGE_DIR "$DATA_DIR/packages"
ENV AOSP_BRANCH "emu-master-dev"
ENV CCACHE_DIR "$DATA_DIR/ccache"
ENV BUILD_LOG_DIR "/data/log"
# ENV CCACHE_DISABLE "1"

# We'll leave the default build args here, making them easy to override.
# ENV ANDROID_BUILD_ARGS="--verbose --mingw --min-build --no-tests"
ENV ANDROID_BUILD_ARGS="--host=windows-x86_64,windows-x86 \
                        --no-tests --verbose"

LABEL description="Android Emulator MINGW build image. Use this image to cross-compile \
Android Emulator for Windows. \
The AOSP (Android Open Source Project) tree well as resulted builds will be stored at the path \
pointed by the DATA_DIR environment variable. Optionally, this may point \
to a mounted volume, which will speed up subsequent builds and simplify \
retrieving the output binaries."

RUN mkdir -p $LOCAL_DATA/scripts
COPY build_emulator.sh $LOCAL_DATA/scripts/

RUN chmod a+x $LOCAL_DATA/scripts/build_emulator.sh

ENTRYPOINT $LOCAL_DATA/scripts/build_emulator.sh
