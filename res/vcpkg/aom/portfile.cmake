# AOM requires NASM on x64 Windows.
#
# GitHub Actions + Chocolatey can install NASM successfully while the executable
# is not visible through PATH and no Chocolatey shim is created for the current
# process. Therefore search the actual Chocolatey package directory as well as
# the normal shim directory.
set(_aom_nasm_hints
    "C:/ProgramData/chocolatey/bin"
    "C:/ProgramData/chocolatey/lib/nasm/tools"
    "C:/ProgramData/chocolatey/lib/nasm.portable/tools"
)

find_program(NASM
    NAMES nasm.exe nasm
    HINTS ${_aom_nasm_hints}
)

if(NOT NASM)
    file(GLOB_RECURSE _aom_nasm_candidates
        LIST_DIRECTORIES false
        "C:/ProgramData/chocolatey/lib/nasm*/tools/nasm.exe"
        "C:/ProgramData/chocolatey/lib/nasm*/tools/**/nasm.exe"
        "C:/ProgramData/chocolatey/lib/nasm*/**/nasm.exe"
    )
    list(LENGTH _aom_nasm_candidates _aom_nasm_count)
    if(_aom_nasm_count GREATER 0)
        list(GET _aom_nasm_candidates 0 NASM)
    endif()
endif()

if(NOT NASM)
    message(FATAL_ERROR
        "Could not find NASM after checking Chocolatey shims and package directories.")
endif()

get_filename_component(_aom_nasm_dir "${NASM}" DIRECTORY)
vcpkg_add_to_path("${_aom_nasm_dir}")

# Perl is required by AOM. Prefer native Strawberry Perl and avoid vcpkg's old
# MSYS2 acquisition path.
find_program(PERL
    NAMES perl.exe perl
    HINTS
        "C:/Strawberry/perl/bin"
        "C:/Strawberry/c/bin"
        "C:/ProgramData/chocolatey/bin"
)

if(NOT PERL)
    file(GLOB_RECURSE _aom_perl_candidates
        LIST_DIRECTORIES false
        "C:/ProgramData/chocolatey/lib/strawberryperl*/**/perl.exe"
    )
    list(LENGTH _aom_perl_candidates _aom_perl_count)
    if(_aom_perl_count GREATER 0)
        list(GET _aom_perl_candidates 0 PERL)
    endif()
endif()

if(NOT PERL)
    message(FATAL_ERROR
        "Could not find Perl. Install Strawberry Perl before building AOM.")
endif()

get_filename_component(_aom_perl_dir "${PERL}" DIRECTORY)
vcpkg_add_to_path("${_aom_perl_dir}")

if(DEFINED ENV{USE_AOM_391})
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF 8ad484f8a18ed1853c094e7d3a4e023b2a92df28
        PATCHES
            aom-uninitialized-pointer.diff
            aom-avx2.diff
            aom-install.diff
    )
else()
    vcpkg_from_git(
        OUT_SOURCE_PATH SOURCE_PATH
        URL "https://aomedia.googlesource.com/aom"
        REF d6f30ae474dd6c358f26de0a0fc26a0d7340a84c
        PATCHES
            aom-uninitialized-pointer.diff
            aom-install.diff
    )
endif()

set(aom_target_cpu "")
if(VCPKG_TARGET_IS_UWP OR (VCPKG_TARGET_IS_WINDOWS AND VCPKG_TARGET_ARCHITECTURE MATCHES "^arm"))
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

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

file(REMOVE_RECURSE
    ${CURRENT_PACKAGES_DIR}/debug/include
    ${CURRENT_PACKAGES_DIR}/debug/share
)

file(INSTALL
    ${SOURCE_PATH}/LICENSE
    DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
    RENAME copyright
)
