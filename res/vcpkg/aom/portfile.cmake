# NASM is required to build AOM.
#
# The GitHub Actions workflow installs NASM through Chocolatey. Chocolatey may
# install the package successfully without refreshing PATH for the process that
# later runs vcpkg, so search the Chocolatey shim directory explicitly.
set(_aom_choco_bin "C:/ProgramData/chocolatey/bin")
if(DEFINED ENV{ChocolateyInstall} AND NOT "$ENV{ChocolateyInstall}" STREQUAL "")
    list(PREPEND _aom_choco_bin "$ENV{ChocolateyInstall}/bin")
endif()

find_program(NASM
    NAMES nasm.exe nasm
    HINTS ${_aom_choco_bin}
    PATH_SUFFIXES bin
    REQUIRED
)
get_filename_component(NASM_EXE_PATH "${NASM}" DIRECTORY)
vcpkg_add_to_path("${NASM_EXE_PATH}")

# Perl is required to build AOM.
# Prefer the native Strawberry Perl installed by the workflow and explicitly
# search both its normal location and Chocolatey's shim directory. This avoids
# vcpkg's old MSYS2 acquisition path, whose pinned MSYS2 package URLs return
# HTTP 404.
set(_aom_perl_hints
    "C:/Strawberry/perl/bin"
    "C:/Strawberry/c/bin"
    ${_aom_choco_bin}
)
find_program(PERL
    NAMES perl.exe perl
    HINTS ${_aom_perl_hints}
    PATH_SUFFIXES bin
    REQUIRED
)
get_filename_component(PERL_PATH "${PERL}" DIRECTORY)
vcpkg_add_to_path("${PERL_PATH}")

if(DEFINED ENV{USE_AOM_391})
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF 8ad484f8a18ed1853c094e7d3a4e023b2a92df28 # 3.9.1
        PATCHES
            aom-uninitialized-pointer.diff
            aom-avx2.diff
            aom-install.diff
    )
else()
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF d6f30ae474dd6c358f26de0a0fc26a0d7340a84c # 3.11.0
        PATCHES
            aom-uninitialized-pointer.diff
            # aom-avx2.diff
            # Can be dropped when https://bugs.chromium.org/p/aomedia/issues/detail?id=3029 is merged into the upstream
            aom-install.diff
    )
endif()

set(aom_target_cpu "")
if(VCPKG_TARGET_IS_UWP OR (VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE MATCHES "^arm"))
    # UWP + aom's assembler files result in weirdness and build failures
    # Also, disable assembly on ARM and ARM64 Windows to fix compilation issues.
    set(aom_target_cpu "-DAOM_TARGET_CPU=generic")
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" AND VCPKG_TARGET_IS_LINUX)
  set(aom_target_cpu "-DENABLE_NEON=OFF")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        ${aom_target_cpu}
        -DENABLE_DOCS=OFF
        -DENABLE_EXAMPLES=OFF
        -DENABLE_TESTDATA=OFF
        -DENABLE_TESTS=OFF
        -DENABLE_TOOLS=OFF
)

vcpkg_cmake_install()

vcpkg_copy_pdbs()

vcpkg_fixup_pkgconfig()
if(VCPKG_TARGET_IS_WINDOWS)
  vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/lib/pkgconfig/aom.pc" " -lm" "")
  if(NOT VCPKG_BUILD_TYPE)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/aom.pc" " -lm" "")
  endif()
endif()

# Move cmake configs
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

# Remove duplicate files
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include
                    ${CURRENT_PACKAGES_DIR}/debug/share)

# Handle copyright
file(INSTALL ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)

vcpkg_fixup_pkgconfig()
