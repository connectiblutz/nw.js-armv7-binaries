#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

chrome=0
sdk=0
arch="arm"
while [ "$1" != "" ]; do
    case $1 in
        -a | --arch )           shift
                                arch=$1
                                ;;
        -c | --chrome )         chrome=1
                                ;;
        -s | --sdk )            sdk=1
                                ;;
        * )                     exit 1
    esac
    shift
done

export WORKDIR="/usr/docker"
export NWJSDIR=${WORKDIR}/nwjs
export DEPOT_TOOLS_DIRECTORY=${WORKDIR}/depot_tools
export PATH=${PATH}:${DEPOT_TOOLS_DIRECTORY}
export LC_ALL=C.UTF-8
export GYP_CHROMIUM_NO_ACTION=0
export ARCH=$arch
export OUT_DIR="out/${ARCH}"
export DIST_DIR="out/${ARCH}"

function applyPatch {
  # See https://gist.github.com/llamasoft/33af03b73945a84d7624460d67b922ab
  ################################### Patches ####################################

  # For nwjs_sdk=false builds, some required(?) files never get built.
  # As a workaround, always use the SDK's GRIT input regardless of the flag.
  #   See: https://github.com/nwjs/chromium.src/issues/145
  cd $NWJSDIR/src
  git checkout -- chrome/browser/BUILD.gn
  patch -p1 < $SCRIPTPATH/resources.patch
}

function build {
  cd $NWJSDIR/src
  gn gen ${OUT_DIR}/nw --args="${1}"
  $NWJSDIR/src/build/gyp_chromium -I third_party/node-nw/common.gypi third_party/node-nw/node.gyp
  ninja -C ${OUT_DIR}/nw nwjs
  ninja -C ${OUT_DIR}Release node
  ninja -C ${OUT_DIR}/nw copy_node
  temp_dir=$(mktemp -d)
  OLD_PATH="${PATH}"
  export PATH="${temp_dir}:${PATH}"

  # Typically under `third_party/llvm-build/Release+Asserts/bin`, but search for it just in case.
  objcopy=$(find . -type f -name "llvm-objcopy" | head -1 | xargs -n 1 realpath)
  cat > "${temp_dir}/strip" <<STRIP_SCRIPT
#!/bin/sh
"${objcopy}" --strip-unneeded "\$@"
STRIP_SCRIPT
  chmod +x "${temp_dir}/strip"

  ninja -C ${OUT_DIR}/nw dump

  export PATH="${OLD_PATH}"
  rm -rf "${temp_dir}"

  ninja -C ${OUT_DIR}/nw dist
}

applyPatch

if [ "$sdk" = "0" ]; then

if [ "$chrome" = "0" ]; then
export GYP_DEFINES="nwjs_sdk=0 disable_nacl=1 building_nw=1 buildtype=Official clang=1 OS=linux target_arch=${ARCH} target_cpu=${ARCH} arm_float_abi=hard"
build "nwjs_sdk=false enable_nacl=false is_component_ffmpeg=true is_debug=false symbol_level=1 target_os=\"linux\" target_cpu=\"${ARCH}\" arm_float_abi=\"hard\""
dist="${WORKDIR}/${DIST_DIR}/nwjs-chromium-ffmpeg-branding"
else
export GYP_DEFINES="nwjs_sdk=0 disable_nacl=1 building_nw=1 buildtype=Official clang=1 OS=linux target_arch=${ARCH} target_cpu=${ARCHM} arm_float_abi=hard"
build "nwjs_sdk=false enable_nacl=false ffmpeg_branding=\"Chrome\" is_component_ffmpeg=true is_debug=false symbol_level=1 target_os=\"linux\" target_cpu=\"${ARCH}\" arm_float_abi=\"hard\""
dist="${WORKDIR}/${DIST_DIR}/nwjs-chrome-ffmpeg-branding"
fi

else

if [ "$chrome" = "0" ]; then
export GYP_DEFINES="nwjs_sdk=1 disable_nacl=0 building_nw=1 buildtype=Official clang=1 OS=linux target_arch=${ARCH} target_cpu=${ARCH} arm_float_abi=hard"
build "nwjs_sdk=true enable_nacl=true is_component_ffmpeg=true is_debug=false symbol_level=1 target_os=\"linux\" target_cpu=\"${ARCH}\" arm_float_abi=\"hard\""
dist="${WORKDIR}/${DIST_DIR}/nwjs-sdk-chromium-ffmpeg-branding"
else
export GYP_DEFINES="nwjs_sdk=1 disable_nacl=0 building_nw=1 buildtype=Official clang=1 OS=linux target_arch=${ARCH} target_cpu=${ARCH} arm_float_abi=hard"
build "nwjs_sdk=true enable_nacl=true ffmpeg_branding=\"Chrome\" is_component_ffmpeg=true is_debug=false symbol_level=1 target_os=\"linux\" target_cpu=\"${ARCH}\" arm_float_abi=\"hard\""
dist="${WORKDIR}/${DIST_DIR}/nwjs-sdk-chrome-ffmpeg-branding"
fi

fi

if [ -d $dist ]; then rm -r $dist; fi
mkdir -p $dist
cp ${NWJSDIR}/src/${OUT_DIR}/nw/dist/** $dist

# tar -zcvf v0.45.7.tar.gz ${DIST_DIR}/*
# docker cp 3f4cdbf38dc2:/usr/docker/v0.45.7.tar.gz .
