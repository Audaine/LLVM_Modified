# Multi-stage release configuration optimized for maximum runtime performance (O2x)
# Plain options configure the first build (Stage 1).
# BOOTSTRAP_* options configure the second build (Stage 2 - PGO instrumented).
# BOOTSTRAP_BOOTSTRAP_* options configure the third build (Stage 3 - Final Release).

function (set_final_stage_var name value type)
  if (LLVM_RELEASE_ENABLE_PGO)
    set(BOOTSTRAP_BOOTSTRAP_${name} ${value} CACHE ${type} "")
  else()
    set(BOOTSTRAP_${name} ${value} CACHE ${type} "")
  endif()
endfunction()

function (set_instrument_and_final_stage_var name value type)
  set(BOOTSTRAP_${name} ${value} CACHE ${type} "")
  if (LLVM_RELEASE_ENABLE_PGO)
    set(BOOTSTRAP_BOOTSTRAP_${name} ${value} CACHE ${type} "")
  endif()
endfunction()

# Enable Native CPU optimizations for Stage 1
set(CMAKE_C_FLAGS "-march=native -mtune=native -O3" CACHE STRING "")
set(CMAKE_CXX_FLAGS "-march=native -mtune=native -O3" CACHE STRING "")
set(LLVM_USE_STATIC_ZSTD OFF CACHE BOOL "")
if (NOT WIN32)
  set(LLVM_USE_STATIC_LIBXML2 OFF CACHE BOOL "")
endif()

# 1. Projects and Runtimes Scope
set(LLVM_RELEASE_ENABLE_LTO FULL CACHE STRING "")
set(LLVM_RELEASE_ENABLE_PGO ON CACHE BOOL "")
set(LLVM_RELEASE_ENABLE_LINK_LOCAL_RUNTIMES ON CACHE BOOL "")

set(DEFAULT_PROJECTS "bolt;clang;clang-tools-extra;lld;lldb;mlir;polly;flang")
set(DEFAULT_RUNTIMES "compiler-rt;libcxx;libcxxabi;libunwind;openmp;flang-rt")

set(LLVM_RELEASE_ENABLE_PROJECTS ${DEFAULT_PROJECTS} CACHE STRING "")
set(LLVM_RELEASE_ENABLE_RUNTIMES ${DEFAULT_RUNTIMES} CACHE STRING "")

set(LLVM_RELEASE_FINAL_STAGE_TARGETS "clang;package;check-all;check-llvm;check-clang" CACHE STRING "")
set(CMAKE_BUILD_TYPE RELEASE CACHE STRING "")

# Stage 1 Options
set(LLVM_TARGETS_TO_BUILD Native CACHE STRING "")
set(CLANG_ENABLE_BOOTSTRAP ON CACHE BOOL "")
set(STAGE1_PROJECTS "clang;lld")
set(STAGE1_RUNTIMES "compiler-rt;libcxx;libcxxabi;libunwind")
set(LLVM_ENABLE_PLUGINS OFF CACHE BOOL "Disable plugins to prevent allocator mismatch" FORCE)
set(LLVM_LINK_LLVM_SHLIB OFF CACHE BOOL "Disable shared LLVM library" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries" FORCE)

set(CLANG_BOOTSTRAP_TARGETS
  generate-profdata
  stage2
  stage2-distribution
  stage2-install-distribution
  stage2-install-distribution-toolchain
  stage2-check-all
  stage2-check-llvm
  stage2-check-clang
  CACHE STRING "")

# Stage 2 Configuration (Instrumented Stage for PGO)
set(BOOTSTRAP_CLANG_ENABLE_BOOTSTRAP ON CACHE STRING "")
set(BOOTSTRAP_CLANG_BOOTSTRAP_TARGETS ${LLVM_RELEASE_FINAL_STAGE_TARGETS} CACHE STRING "")
set(BOOTSTRAP_LLVM_BUILD_INSTRUMENTED IR CACHE STRING "")
set(BOOTSTRAP_LLVM_ENABLE_RUNTIMES "compiler-rt;libcxx;libcxxabi;libunwind" CACHE STRING "")
# Include polly in Stage 2 to instrument its execution path during PGO training
set(BOOTSTRAP_LLVM_ENABLE_PROJECTS "clang;lld;polly" CACHE STRING "")
set(BOOTSTRAP_LLVM_POLLY_LINK_INTO_TOOLS ON CACHE BOOL "")

# Stage 1 Common Config
set(LLVM_ENABLE_RUNTIMES ${STAGE1_RUNTIMES} CACHE STRING "")
set(LLVM_ENABLE_PROJECTS ${STAGE1_PROJECTS} CACHE STRING "")
set(LIBCXX_STATICALLY_LINK_ABI_IN_STATIC_LIBRARY ON CACHE STRING "")

# Stage 2 and Final Stage (Stage 3) Common Config
set_instrument_and_final_stage_var(LLVM_ENABLE_PLUGINS "OFF" BOOL)
set_instrument_and_final_stage_var(LLVM_LINK_LLVM_SHLIB "OFF" BOOL)
set_instrument_and_final_stage_var(BUILD_SHARED_LIBS "OFF" BOOL)

set_instrument_and_final_stage_var(CMAKE_POSITION_INDEPENDENT_CODE "ON" STRING)
set_instrument_and_final_stage_var(CMAKE_C_FLAGS "-march=native -mtune=native -O3" STRING)
set_instrument_and_final_stage_var(CMAKE_CXX_FLAGS "-march=native -mtune=native -O3" STRING)
set_instrument_and_final_stage_var(LLVM_ENABLE_LTO "${LLVM_RELEASE_ENABLE_LTO}" STRING)
set_instrument_and_final_stage_var(LLVM_USE_STATIC_ZSTD "OFF" BOOL)
if (NOT WIN32)
  set_instrument_and_final_stage_var(LLVM_USE_STATIC_LIBXML2 "OFF" BOOL)
endif()

if (LLVM_RELEASE_ENABLE_LTO)
  set_instrument_and_final_stage_var(LLVM_ENABLE_LLD "ON" BOOL)
  set(RUNTIMES_CMAKE_ARGS "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DLLVM_ENABLE_LLD=ON -DLLVM_ENABLE_FATLTO=ON -DLLVM_ENABLE_LTO=Full" CACHE STRING "")
endif()

if (LLVM_RELEASE_ENABLE_LINK_LOCAL_RUNTIMES)
  set_instrument_and_final_stage_var(LLVM_ENABLE_LIBCXX "ON" BOOL)
  set_instrument_and_final_stage_var(LLVM_STATIC_LINK_CXX_STDLIB "ON" BOOL)
  set(RELEASE_LINKER_FLAGS "-rtlib=compiler-rt --unwindlib=libunwind")
  if (NOT WIN32)
    set(RELEASE_LINKER_FLAGS "${RELEASE_LINKER_FLAGS} -static-libgcc")
  endif()
endif()

# Set flags for BOLT compatibility (relocations, now)
if (NOT WIN32)
  set(RELEASE_LINKER_FLAGS "${RELEASE_LINKER_FLAGS} -Wl,--emit-relocs,-znow")
endif()

if (RELEASE_LINKER_FLAGS)
  set_instrument_and_final_stage_var(CMAKE_EXE_LINKER_FLAGS ${RELEASE_LINKER_FLAGS} STRING)
  set_instrument_and_final_stage_var(CMAKE_SHARED_LINKER_FLAGS ${RELEASE_LINKER_FLAGS} STRING)
  set_instrument_and_final_stage_var(CMAKE_MODULE_LINKER_FLAGS ${RELEASE_LINKER_FLAGS} STRING)
endif()

# Final Stage Config (Stage 3)
set_final_stage_var(LLVM_ENABLE_RUNTIMES "${LLVM_RELEASE_ENABLE_RUNTIMES}" STRING)
set_final_stage_var(LLVM_ENABLE_PROJECTS "${LLVM_RELEASE_ENABLE_PROJECTS}" STRING)
# Enable BOLT instrumentation and post-link optimization on final Clang
set_final_stage_var(CLANG_BOLT "INSTRUMENT" STRING)
set_final_stage_var(LLVM_POLLY_LINK_INTO_TOOLS ON BOOL)
set_final_stage_var(CPACK_GENERATOR "TXZ" STRING)
set_final_stage_var(CPACK_ARCHIVE_THREADS "0" STRING)
set_final_stage_var(LLVM_USE_STATIC_ZSTD "OFF" BOOL)
if (NOT WIN32)
  set_final_stage_var(LLVM_USE_STATIC_LIBXML2 "OFF" BOOL)
endif()

if (LLVM_RELEASE_ENABLE_LTO)
  set_final_stage_var(LLVM_ENABLE_FATLTO "ON" BOOL)
  set_final_stage_var(CPACK_PRE_BUILD_SCRIPTS "${CMAKE_CURRENT_LIST_DIR}/release_cpack_pre_build_strip_lto.cmake" STRING)
endif()
