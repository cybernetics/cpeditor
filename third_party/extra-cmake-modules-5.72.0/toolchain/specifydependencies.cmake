execute_process(COMMAND readelf --wide --dynamic ${TARGET} ERROR_VARIABLE readelf_errors OUTPUT_VARIABLE out RESULT_VARIABLE result)

if (NOT result EQUAL 0)
    message(FATAL_ERROR "readelf failed on ${TARGET} exit(${result}): ${readelf_errors}")
endif()

string(REPLACE "\n" ";" lines "${out}")
set(extralibs)
foreach(line ${lines})
    string(REGEX MATCH ".*\\(NEEDED\\) +Shared library: +\\[(.+)\\]$" matched ${line})
    set(currentLib ${CMAKE_MATCH_1})

    if(NOT ${currentLib} MATCHES "libQt5.*" AND matched)
        find_file(ourlib-${currentLib} ${currentLib} HINTS ${OUTPUT_DIR} ${EXPORT_DIR} ${ECM_ADDITIONAL_FIND_ROOT_PATH} NO_DEFAULT_PATH PATH_SUFFIXES lib)

        if(ourlib-${currentLib})
            list(APPEND extralibs "${ourlib-${currentLib}}")
        else()
            message(STATUS "could not find ${currentLib} in ${OUTPUT_DIR} ${EXPORT_DIR}/lib/ ${ECM_ADDITIONAL_FIND_ROOT_PATH}")
        endif()
    endif()
endforeach()

function(contains_library libpath IS_EQUAL)
    get_filename_component (name ${libpath} NAME)
    unset (IS_EQUAL PARENT_SCOPE)

    foreach (extralib ${extralibs})
        get_filename_component (extralibname ${extralib} NAME)
        if (${extralibname} STREQUAL ${name})
            set (IS_EQUAL TRUE PARENT_SCOPE)
            break()
        endif()
    endforeach()
endfunction()

if (ANDROID_EXTRA_LIBS)
    foreach (extralib ${ANDROID_EXTRA_LIBS})
        contains_library(${extralib} IS_EQUAL)

        if (IS_EQUAL)
            message (STATUS "found duplicate, skipping: " ${extralib})
        else()
            message(STATUS "manually specified extra library: " ${extralib})
            list(APPEND extralibs ${extralib})
        endif()
    endforeach()
endif()

if(extralibs)
    string(REPLACE ";" "," libs "${extralibs}")
    set(extralibs "\"android-extra-libs\": \"${libs}\",")
endif()

set(extraplugins)
foreach(folder "share" "lib/qml") #now we check for folders with extra stuff
    set(plugin "${EXPORT_DIR}/${folder}")
    if(EXISTS "${plugin}")
        if(extraplugins)
            set(extraplugins "${extraplugins},${plugin}")
        else()
            set(extraplugins "${plugin}")
        endif()
    endif()
endforeach()
if(extraplugins)
    set(extraplugins "\"android-extra-plugins\": \"${extraplugins}\",")
endif()

file(READ "${INPUT_FILE}" CONTENTS)
file(READ "stl" stl_contents)

file(READ "ranlib" ranlib_contents)
string(REGEX MATCH ".+/toolchains/(.+)-([^\\-]+)/prebuilt/.*/bin/(.*)-ranlib" x ${ranlib_contents})

string(REPLACE "##ANDROID_TOOL_PREFIX##" "${CMAKE_MATCH_1}" NEWCONTENTS "${CONTENTS}")
string(REPLACE "##ANDROID_TOOLCHAIN_VERSION##" "${CMAKE_MATCH_2}" NEWCONTENTS "${NEWCONTENTS}")
string(REPLACE "##ANDROID_COMPILER_PREFIX##" "${CMAKE_MATCH_3}" NEWCONTENTS "${NEWCONTENTS}")
string(REPLACE "##EXTRALIBS##" "${extralibs}" NEWCONTENTS "${NEWCONTENTS}")
string(REPLACE "##EXTRAPLUGINS##" "${extraplugins}" NEWCONTENTS "${NEWCONTENTS}")
string(REPLACE "##CMAKE_CXX_STANDARD_LIBRARIES##" "${stl_contents}" NEWCONTENTS "${NEWCONTENTS}")
file(WRITE "${OUTPUT_FILE}" ${NEWCONTENTS})