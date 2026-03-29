if(USE_SYSTEM_STDGPU)
  find_package(stdgpu REQUIRED)
  add_library(nvblox_stdgpu ALIAS stdgpu::stdgpu)
else()
  include(FetchContent)

  # Patches to stdgpu. Using latest stdgpu (post-1.3.0) which includes CUDA 13
  # support, NOMINMAX for Windows, and CMake 4.x compat. The thrust_version_regex,
  # cuda12_6, and cuda13_0 patches are already integrated upstream.
  set(apply_patch
      git
      apply
      # Patch that exposes the "occupied" array. We need this when copying the hash.
      ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/stdgpu/stdgpu_expose_occupied.patch
      # Patch that overrides the estimated number of hash collisions by stdgpu
      # and sets the worst-case number for stability. Updated for latest stdgpu.
      ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/stdgpu/stdgpu_handle_collisions_v2.patch
      # Fix ambiguous to_address call on MSVC/NVCC
      ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/stdgpu/stdgpu_fix_to_address_ambiguity.patch)

  FetchContent_Declare(
    ext_stdgpu
    SYSTEM
    PREFIX
    stdgpu
    GIT_REPOSITORY https://github.com/stotko/stdgpu.git
    GIT_TAG 8125b92baa8e62b508623289096c26cbebc6ff9a
    PATCH_COMMAND ${apply_patch}
    UPDATE_COMMAND "")

  # stdgpu build options
  set(STDGPU_BUILD_SHARED_LIBS OFF)
  set(STDGPU_BUILD_EXAMPLES OFF)
  set(STDGPU_BUILD_TESTS OFF)
  set(STDGPU_ENABLE_CONTRACT_CHECKS OFF)
  set(STDGPU_BUILD_BENCHMARKS OFF)

  # Download the files
  FetchContent_MakeAvailable(ext_stdgpu)

  # On MSVC, stdgpu's .cpp files include Thrust headers via iterator.h which
  # cl.exe cannot parse. Compile them as CUDA instead. We must NOT apply nvblox's
  # Thrust/CUB namespace wrapping defines to stdgpu, as they cause
  # "thrust::detail is ambiguous" errors with CUDA 12.8's Thrust.
  if(MSVC)
    set_source_files_properties(
      ${ext_stdgpu_SOURCE_DIR}/src/stdgpu/impl/iterator.cpp
      ${ext_stdgpu_SOURCE_DIR}/src/stdgpu/impl/memory.cpp
      ${ext_stdgpu_SOURCE_DIR}/src/stdgpu/impl/device.cpp
      TARGET_DIRECTORY stdgpu
      PROPERTIES LANGUAGE CUDA)
    # Set C++17 and disable Thrust's architecture-dependent ABI namespace
    # which causes "thrust::detail is ambiguous" on CUDA 12.8 + MSVC.
    target_compile_options(stdgpu PRIVATE $<$<COMPILE_LANGUAGE:CXX>:/std:c++17>)
    target_compile_definitions(stdgpu PRIVATE
      THRUST_DISABLE_ABI_NAMESPACE
      THRUST_IGNORE_ABI_NAMESPACE_ERROR)
  else()
    set_nvblox_compiler_options_nowarnings(stdgpu)
  endif()
  add_library(nvblox_stdgpu INTERFACE)
  target_link_libraries(nvblox_stdgpu INTERFACE stdgpu)
  target_include_directories(
    nvblox_stdgpu INTERFACE $<BUILD_INTERFACE:${ext_stdgpu_SOURCE_DIR}/src>
                            $<INSTALL_INTERFACE:include/stdgpu>)
endif()
