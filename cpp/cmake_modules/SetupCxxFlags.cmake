# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Check if the target architecture and compiler supports some special
# instruction sets that would boost performance.
include(CheckCXXCompilerFlag)
# x86/amd64 compiler flags
CHECK_CXX_COMPILER_FLAG("-msse3" CXX_SUPPORTS_SSE3)
# power compiler flags
CHECK_CXX_COMPILER_FLAG("-maltivec" CXX_SUPPORTS_ALTIVEC)

# compiler flags that are common across debug/release builds

if (MSVC)
  # TODO(wesm): Change usages of C runtime functions that MSVC says are
  # insecure, like std::getenv
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)

  # Use __declspec(dllexport) during library build, other users of the Arrow
  # headers will see dllimport
  add_definitions(-DARROW_EXPORTING)

  # ARROW-1931 See https://github.com/google/googletest/issues/1318
  #
  # This is added to CMAKE_CXX_FLAGS instead of CXX_COMMON_FLAGS since only the
  # former is passed into the external projects
  if (MSVC_VERSION VERSION_GREATER 1900)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_SILENCE_TR1_NAMESPACE_DEPRECATION_WARNING")
  endif()

  if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    # clang-cl
    set(CXX_COMMON_FLAGS "-EHsc")
  elseif(${CMAKE_CXX_COMPILER_VERSION} VERSION_LESS 19)
    message(FATAL_ERROR "Only MSVC 2015 (Version 19.0) and later are supported
    by Arrow. Found version ${CMAKE_CXX_COMPILER_VERSION}.")
  else()
    # Fix annoying D9025 warning
    string(REPLACE "/W3" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

    # Set desired warning level (e.g. set /W4 for more warnings)
    set(CXX_COMMON_FLAGS "/W3")
  endif()

  if (ARROW_USE_STATIC_CRT)
    foreach (c_flag CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG
                    CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO
                    CMAKE_C_FLAGS CMAKE_C_FLAGS_RELEASE CMAKE_C_FLAGS_DEBUG
                    CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO)
      string(REPLACE "/MD" "-MT" ${c_flag} "${${c_flag}}")
    endforeach()
  endif()

  # Support large object code
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /bigobj")
else()
  # Common flags set below with warning level
  set(CXX_COMMON_FLAGS "")
endif()

# Build warning level (CHECKIN, EVERYTHING, etc.)

# if no build warning level is specified, default to development warning level
if (NOT BUILD_WARNING_LEVEL)
  set(BUILD_WARNING_LEVEL Production)
endif(NOT BUILD_WARNING_LEVEL)

string(TOUPPER ${BUILD_WARNING_LEVEL} UPPERCASE_BUILD_WARNING_LEVEL)

if ("${UPPERCASE_BUILD_WARNING_LEVEL}" STREQUAL "CHECKIN")
  # Pre-checkin builds
  if ("${COMPILER_FAMILY}" STREQUAL "msvc")
    string(REPLACE "/W3" "" CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS}")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /W3")
    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /WX")
  elseif ("${COMPILER_FAMILY}" STREQUAL "clang")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Weverything -Wno-c++98-compat \
-Wno-c++98-compat-pedantic -Wno-deprecated -Wno-weak-vtables -Wno-padded \
-Wno-comma -Wno-unused-parameter -Wno-unused-template -Wno-undef \
-Wno-shadow -Wno-switch-enum -Wno-exit-time-destructors \
-Wno-global-constructors -Wno-weak-template-vtables -Wno-undefined-reinterpret-cast \
-Wno-implicit-fallthrough -Wno-unreachable-code-return \
-Wno-float-equal -Wno-missing-prototypes \
-Wno-old-style-cast -Wno-covered-switch-default \
-Wno-cast-align -Wno-vla-extension -Wno-shift-sign-overflow \
-Wno-used-but-marked-unused -Wno-missing-variable-declarations \
-Wno-gnu-zero-variadic-macro-arguments -Wconversion -Wno-sign-conversion \
-Wno-disabled-macro-expansion")

    # Version numbers where warnings are introduced
    if ("${COMPILER_VERSION}" VERSION_GREATER "3.3")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-gnu-folding-constant")
    endif()
    if ("${COMPILER_VERSION}" VERSION_GREATER "3.6")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-reserved-id-macro")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-range-loop-analysis")
    endif()
    if ("${COMPILER_VERSION}" VERSION_GREATER "3.7")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-double-promotion")
    endif()
    if ("${COMPILER_VERSION}" VERSION_GREATER "3.8")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-undefined-func-template")
    endif()

    if ("${COMPILER_VERSION}" VERSION_GREATER "4.0")
      set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-zero-as-null-pointer-constant")
    endif()

    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-unknown-warning-option -Werror")
  elseif ("${COMPILER_FAMILY}" STREQUAL "gcc")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wall -Wconversion -Wno-sign-conversion")
    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wno-unknown-warning-option -Werror")
  else()
    message(FATAL_ERROR "Unknown compiler. Version info:\n${COMPILER_VERSION_FULL}")
  endif()
elseif ("${UPPERCASE_BUILD_WARNING_LEVEL}" STREQUAL "EVERYTHING")
  # Pedantic builds for fixing warnings
  if ("${COMPILER_FAMILY}" STREQUAL "msvc")
    string(REPLACE "/W3" "" CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS}")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /Wall")
    # https://docs.microsoft.com/en-us/cpp/build/reference/compiler-option-warning-level
    # /wdnnnn disables a warning where "nnnn" is a warning number
    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS}  /WX")
  elseif ("${COMPILER_FAMILY}" STREQUAL "clang")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Weverything -Wno-c++98-compat -Wno-c++98-compat-pedantic")
    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Werror")
  elseif ("${COMPILER_FAMILY}" STREQUAL "gcc")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wall -Wpedantic -Wextra -Wno-unused-parameter")
    # Treat all compiler warnings as errors
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Werror")
  else()
    message(FATAL_ERROR "Unknown compiler. Version info:\n${COMPILER_VERSION_FULL}")
  endif()
else()
  # Production builds (warning are not treated as errors)
  if ("${COMPILER_FAMILY}" STREQUAL "msvc")
    # https://docs.microsoft.com/en-us/cpp/build/reference/compiler-option-warning-level
    # TODO: Enable /Wall and disable individual warnings until build compiles without errors
    # /wdnnnn disables a warning where "nnnn" is a warning number
    string(REPLACE "/W3" "" CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS}")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /W3")
  elseif ("${COMPILER_FAMILY}" STREQUAL "clang")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wall")
  elseif ("${COMPILER_FAMILY}" STREQUAL "gcc")
    set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -Wall")
  else()
    message(FATAL_ERROR "Unknown compiler. Version info:\n${COMPILER_VERSION_FULL}")
  endif()
endif()

# Disable annoying "performance warning" about int-to-bool conversion
if ("${COMPILER_FAMILY}" STREQUAL "msvc")
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} /wd4800")
endif()

# if build warning flags is set, add to CXX_COMMON_FLAGS
if (BUILD_WARNING_FLAGS)
  # Use BUILD_WARNING_FLAGS with BUILD_WARNING_LEVEL=everything to disable
  # warnings (use with Clang's -Weverything flag to find potential errors)
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} ${BUILD_WARNING_FLAGS}")
endif(BUILD_WARNING_FLAGS)

if (NOT ("${COMPILER_FAMILY}" STREQUAL "msvc"))
set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -std=c++11")
endif()

# Only enable additional instruction sets if they are supported
if (CXX_SUPPORTS_SSE3 AND ARROW_SSE3)
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -msse3")
endif()

if (CXX_SUPPORTS_ALTIVEC AND ARROW_ALTIVEC)
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -maltivec")
endif()

if (APPLE)
  # Depending on the default OSX_DEPLOYMENT_TARGET (< 10.9), libstdc++ may be
  # the default standard library which does not support C++11. libc++ is the
  # default from 10.9 onward.
  set(CXX_COMMON_FLAGS "${CXX_COMMON_FLAGS} -stdlib=libc++")
endif()

# compiler flags for different build types (run 'cmake -DCMAKE_BUILD_TYPE=<type> .')
# For all builds:
# For CMAKE_BUILD_TYPE=Debug
#   -ggdb: Enable gdb debugging
# For CMAKE_BUILD_TYPE=FastDebug
#   Same as DEBUG, except with some optimizations on.
# For CMAKE_BUILD_TYPE=Release
#   -O3: Enable all compiler optimizations
#   Debug symbols are stripped for reduced binary size. Add
#   -DARROW_CXXFLAGS="-g" to add them
if (NOT MSVC)
  set(CXX_FLAGS_DEBUG "-ggdb -O0")
  set(CXX_FLAGS_FASTDEBUG "-ggdb -O1")
  set(CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
endif()

set(CXX_FLAGS_PROFILE_GEN "${CXX_FLAGS_RELEASE} -fprofile-generate")
set(CXX_FLAGS_PROFILE_BUILD "${CXX_FLAGS_RELEASE} -fprofile-use")

# if no build build type is specified, default to debug builds
if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug)
endif(NOT CMAKE_BUILD_TYPE)

string (TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE)

# Set compile flags based on the build type.
message("Configured for ${CMAKE_BUILD_TYPE} build (set with cmake -DCMAKE_BUILD_TYPE={release,debug,...})")
if ("${CMAKE_BUILD_TYPE}" STREQUAL "DEBUG")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_DEBUG}")
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "FASTDEBUG")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_FASTDEBUG}")
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "RELEASE")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_RELEASE}")
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "PROFILE_GEN")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_PROFILE_GEN}")
elseif ("${CMAKE_BUILD_TYPE}" STREQUAL "PROFILE_BUILD")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX_FLAGS_PROFILE_BUILD}")
else()
  message(FATAL_ERROR "Unknown build type: ${CMAKE_BUILD_TYPE}")
endif ()

if ("${CMAKE_CXX_FLAGS}" MATCHES "-DNDEBUG")
  set(ARROW_DEFINITION_FLAGS "-DNDEBUG")
else()
  set(ARROW_DEFINITION_FLAGS "")
endif()

message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
