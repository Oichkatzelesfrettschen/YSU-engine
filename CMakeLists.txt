cmake_minimum_required(VERSION 3.16)
project(YSUEngine VERSION 1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# ════════════════════════════════════════════════════════════════
# Build type defaults
# ════════════════════════════════════════════════════════════════
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_C_FLAGS_RELEASE "-O2")
set(CMAKE_C_FLAGS_DEBUG   "-g -O0 -fsanitize=address,undefined")

if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers)
endif()

# ════════════════════════════════════════════════════════════════
# Output directory — keep build artifacts out of source tree
# ════════════════════════════════════════════════════════════════
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# ════════════════════════════════════════════════════════════════
# Include directories — lets all #include "file.h" resolve
# without changing any existing source code
# ════════════════════════════════════════════════════════════════
set(YSU_INCLUDE_DIRS
    ${CMAKE_SOURCE_DIR}/src/core
    ${CMAKE_SOURCE_DIR}/src/render
    ${CMAKE_SOURCE_DIR}/src/denoise
    ${CMAKE_SOURCE_DIR}/src/nerf
    ${CMAKE_SOURCE_DIR}/src/vulkan
    ${CMAKE_SOURCE_DIR}/src/physics
    ${CMAKE_SOURCE_DIR}/src/editor
    ${CMAKE_SOURCE_DIR}/src/upscale
    ${CMAKE_SOURCE_DIR}/src/third_party
)

# ════════════════════════════════════════════════════════════════
# Platform detection
# ════════════════════════════════════════════════════════════════
find_package(Threads REQUIRED)

if(WIN32)
    set(PLATFORM_LIBS ws2_32)
else()
    set(PLATFORM_LIBS m)
endif()

# ════════════════════════════════════════════════════════════════
# Core library (math, primitives, image, materials)
# ════════════════════════════════════════════════════════════════
file(GLOB CORE_SRC src/core/*.c)
# postprocess.c lives in src/render/ but is called by image.c (core), so
# include it in ysu_core to resolve the dependency before ysu_render is built.
list(APPEND CORE_SRC src/render/postprocess.c)
add_library(ysu_core STATIC ${CORE_SRC})
target_include_directories(ysu_core PUBLIC ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu_core PUBLIC ${PLATFORM_LIBS})

# ════════════════════════════════════════════════════════════════
# Render library (renderer, BVH, scene, G-buffer)
# ════════════════════════════════════════════════════════════════
set(RENDER_SRC
    src/render/render.c
    src/render/bvh.c
    src/render/sceneloader.c
    src/render/gbuffer.c
    src/render/gbuffer_dump.c
    src/render/ysu_mt.c
)
add_library(ysu_render STATIC ${RENDER_SRC})
target_include_directories(ysu_render PUBLIC ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu_render PUBLIC ysu_core Threads::Threads)

# ════════════════════════════════════════════════════════════════
# Denoise library
# ════════════════════════════════════════════════════════════════
file(GLOB DENOISE_SRC src/denoise/*.c)
add_library(ysu_denoise STATIC ${DENOISE_SRC})
target_include_directories(ysu_denoise PUBLIC ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu_denoise PUBLIC ysu_core)

# ════════════════════════════════════════════════════════════════
# NeRF library (SIMD inference, scheduling)
# ════════════════════════════════════════════════════════════════
set(NERF_SRC
    src/nerf/nerf_simd.c
    src/nerf/nerf_simd_integration.c
    src/nerf/nerf_batch.c
    src/nerf/nerf_scheduler.c
    src/nerf/depth_hint.c
)
add_library(ysu_nerf STATIC ${NERF_SRC})
target_include_directories(ysu_nerf PUBLIC ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu_nerf PUBLIC ysu_core)

# AVX2 support (optional, detected at runtime in nerf_simd.c)
include(CheckCCompilerFlag)
check_c_compiler_flag(-mavx2 HAS_AVX2)
if(HAS_AVX2)
    target_compile_options(ysu_nerf PRIVATE -mavx2 -mfma)
endif()

# OpenMP (optional, for NeRF batch processing)
find_package(OpenMP QUIET)
if(OpenMP_C_FOUND)
    target_link_libraries(ysu_nerf PUBLIC OpenMP::OpenMP_C)
endif()

# ════════════════════════════════════════════════════════════════
# Upscale library
# ════════════════════════════════════════════════════════════════
set(UPSCALE_SRC
    src/upscale/ysu_upscale.c
)
add_library(ysu_upscale STATIC ${UPSCALE_SRC})
target_include_directories(ysu_upscale PUBLIC ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu_upscale PUBLIC ysu_core)

# ════════════════════════════════════════════════════════════════
# Main CPU raytracer executable
# ════════════════════════════════════════════════════════════════
add_executable(ysu
    src/render/ysu_main.c
    src/editor/ysu_360_engine_integration.c
)
target_include_directories(ysu PRIVATE ${YSU_INCLUDE_DIRS})
target_link_libraries(ysu PRIVATE
    ysu_render
    ysu_denoise
    ysu_nerf
    ysu_upscale
    ysu_core
    Threads::Threads
    ${PLATFORM_LIBS}
)

# ════════════════════════════════════════════════════════════════
# NeRF SIMD standalone test
# ════════════════════════════════════════════════════════════════
add_executable(nerf_simd_test src/nerf/nerf_simd_test.c)
target_include_directories(nerf_simd_test PRIVATE ${YSU_INCLUDE_DIRS})
target_link_libraries(nerf_simd_test PRIVATE ysu_nerf ysu_core ${PLATFORM_LIBS})

# ════════════════════════════════════════════════════════════════
# Vulkan targets (only if Vulkan SDK is found)
# ════════════════════════════════════════════════════════════════
find_package(Vulkan QUIET)
if(Vulkan_FOUND)
    message(STATUS "Vulkan found — building GPU targets")

    # Vulkan GPU library
    set(VULKAN_SRC
        src/vulkan/gpu_vulkan_demo.c
        src/vulkan/gpu_bvh_build.c
        src/vulkan/gpu_bvh_lbv.c
        src/vulkan/gpu_bvh_lbvh_builder.c
        src/vulkan/gpu_obj_loader.c
        src/vulkan/depth_prepass_gpu.c
        src/vulkan/lbvh.c
    )

    add_executable(gpu_demo ${VULKAN_SRC})
    target_include_directories(gpu_demo PRIVATE ${YSU_INCLUDE_DIRS})
    target_link_libraries(gpu_demo PRIVATE
        ysu_denoise
        ysu_nerf
        ysu_render
        ysu_core
        Vulkan::Vulkan
        Threads::Threads
        ${PLATFORM_LIBS}
    )

    # GLFW for windowed mode (optional)
    find_package(glfw3 QUIET)
    if(glfw3_FOUND)
        target_link_libraries(gpu_demo PRIVATE glfw)
    endif()

    # Physics simulation targets
    set(PHYSICS_COMMON_SRC
        src/physics/quantum_volume.c
        src/physics/nuclear_reaction.c
        src/physics/atomic_fission.c
        src/physics/reactor_thermal.c
    )

    add_executable(quantum_demo
        src/physics/quantum_demo_main.c
        ${PHYSICS_COMMON_SRC}
    )
    target_include_directories(quantum_demo PRIVATE ${YSU_INCLUDE_DIRS})
    target_link_libraries(quantum_demo PRIVATE
        ysu_core
        Vulkan::Vulkan
        Threads::Threads
        ${PLATFORM_LIBS}
    )
    if(glfw3_FOUND)
        target_link_libraries(quantum_demo PRIVATE glfw)
    endif()

    # Reactor thermal test
    add_executable(test_reactor_thermal src/physics/test_reactor_thermal.c ${PHYSICS_COMMON_SRC})
    target_include_directories(test_reactor_thermal PRIVATE ${YSU_INCLUDE_DIRS})
    target_link_libraries(test_reactor_thermal PRIVATE ysu_core Vulkan::Vulkan ${PLATFORM_LIBS})

else()
    message(STATUS "Vulkan NOT found — skipping GPU targets")
endif()

# ════════════════════════════════════════════════════════════════
# Editor targets (require raylib)
# ════════════════════════════════════════════════════════════════
find_library(RAYLIB_LIB raylib PATHS ${CMAKE_SOURCE_DIR}/raylib/lib)
if(RAYLIB_LIB)
    message(STATUS "raylib found — building editor targets")

    set(EDITOR_LIBS ${RAYLIB_LIB})
    if(WIN32)
        list(APPEND EDITOR_LIBS gdi32 winmm opengl32)
    endif()

    add_executable(ysu_mesh_edit src/editor/ysu_mesh_edit.c)
    target_include_directories(ysu_mesh_edit PRIVATE ${YSU_INCLUDE_DIRS} ${CMAKE_SOURCE_DIR}/raylib/include)
    target_link_libraries(ysu_mesh_edit PRIVATE ysu_core ${EDITOR_LIBS} ${PLATFORM_LIBS})

    add_executable(ysu_viewport src/editor/ysu_viewport.c)
    target_include_directories(ysu_viewport PRIVATE ${YSU_INCLUDE_DIRS} ${CMAKE_SOURCE_DIR}/raylib/include)
    target_link_libraries(ysu_viewport PRIVATE ysu_core ${EDITOR_LIBS} ${PLATFORM_LIBS})

    add_executable(ysu_edit_mode src/editor/ysu_edit_mode.c)
    target_include_directories(ysu_edit_mode PRIVATE ${YSU_INCLUDE_DIRS} ${CMAKE_SOURCE_DIR}/raylib/include)
    target_link_libraries(ysu_edit_mode PRIVATE ysu_core ${EDITOR_LIBS} ${PLATFORM_LIBS})
else()
    message(STATUS "raylib NOT found — skipping editor targets")
endif()

# ════════════════════════════════════════════════════════════════
# Standalone tools
# ════════════════════════════════════════════════════════════════
add_executable(inspect_ppm src/tools/inspect_ppm.c)
target_include_directories(inspect_ppm PRIVATE ${YSU_INCLUDE_DIRS})
target_link_libraries(inspect_ppm PRIVATE ${PLATFORM_LIBS})

add_executable(ysub_info src/tools/ysub_info.c)
target_include_directories(ysub_info PRIVATE ${YSU_INCLUDE_DIRS})
target_link_libraries(ysub_info PRIVATE ${PLATFORM_LIBS})

add_executable(ysub_to_ppm src/tools/ysub_to_ppm.c)
target_include_directories(ysub_to_ppm PRIVATE ${YSU_INCLUDE_DIRS})
target_link_libraries(ysub_to_ppm PRIVATE ${PLATFORM_LIBS})

# ════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════
message(STATUS "")
message(STATUS "=== YSU Engine Build Summary ===")
message(STATUS "  Build type:   ${CMAKE_BUILD_TYPE}")
message(STATUS "  C compiler:   ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
message(STATUS "  AVX2:         ${HAS_AVX2}")
message(STATUS "  OpenMP:       ${OpenMP_C_FOUND}")
message(STATUS "  Vulkan:       ${Vulkan_FOUND}")
message(STATUS "  raylib:       ${RAYLIB_LIB}")
message(STATUS "================================")
