# AOM port override for GitHub Actions Windows builds.
#
# Do not require NASM on Windows. The CI runner repeatedly reports that NASM
# cannot be located even after installation. Building AOM with the generic CPU
# target disables the x86 assembly path and therefore removes the NASM
# dependency. This is slower than an optimized SIMD build, but is portable and
# suitable for producing the Windows package.
#
# Perl is still required by parts of the AOM build tooling. Prefer a native
# Strawberry Perl installation and avoid vcpkg's old MSYS2 acquisition path.
find_program(PERL
    NAMES perl.exe perl
    HINTS
        "C:/Strawberry/perl/bin"
        "C:/Strawberry/c/bin"
        "C:/ProgramData/chocolatey/bin"
)

if(NOT PERL)
    message(FATAL_ERROR
        "Could not find native Perl. Install Strawberry Perl before building AOM.")
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

# Force the generic implementation on Windows so AOM does not enter the x86
# assembly/NASM configuration path.
set(aom_target_cpu "")
if(VCPKG_TARGET_IS_WINDOWS)
    set(aom_target_cpu "-DAOM_TARGET_CPU=generic")
elseif(VCPKG_TARGET_IS_UWP)
    set(aom_target_cpu "-DAOM_TARGET_CPU=generic")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" AND VCPKG_TARGET_IS_LINUX)
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
