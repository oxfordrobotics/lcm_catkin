cmake_minimum_required(VERSION 2.8)
set(_lcmtypes)
set(_lcmtypes_c_dir ${PROJECT_BINARY_DIR}/lcmtypes/c)
set(_lcmtypes_cpp_dir ${PROJECT_BINARY_DIR}/lcmtypes/cpp)
set(_lcmtypes_python_dir_in ${PROJECT_BINARY_DIR}/lcmtypes/py)
set(_lcmtypes_java_dir ${PROJECT_BINARY_DIR}/lcmtypes/java)
set(_lcmtypes_h_dir ${CATKIN_DEVEL_PREFIX}/include/${PROJECT_NAME})
set(_lcmtypes_c_files)
set(_lcmtypes_h_files)
set(_lcmtypes_hpp_files_in)
set(_lcmtypes_hpp_files)
set(_lcmtypes_py_files)
set(_lcmtypes_java_files)
set(_lcm_find_path)
set(_spy_lcm_jars)
set(JAVA_INSTALL_JARS)
set(LCMTYPES_JAR ${CATKIN_DEVEL_PREFIX}/share/java/lcmtypes_${PROJECT_NAME}.jar)
set(libname "lcmtypes_${PROJECT_NAME}")
set(_lcm_redirct_script python ${CMAKE_CURRENT_LIST_DIR}/redirect.py)
add_custom_target(lcmtypes_${PROJECT_NAME}_all ALL)
list(APPEND ${PROJECT_NAME}_EXPORTED_TARGETS "lcmtypes_${PROJECT_NAME}_all")

macro(FindLCM)
  set(_lcm_find_path ${ARGN})
endmacro(FindLCM)

macro(AddLCM)
  set(_lcmtypes_python_dir ${CATKIN_DEVEL_PREFIX}/${CATKIN_PACKAGE_PYTHON_DESTINATION})

  GetLCMPackageName(_lcm_package_name ${PROJECT_NAME})
  foreach(arg ${ARGN})
    list(APPEND _lcmtypes ${CMAKE_CURRENT_SOURCE_DIR}/${_lcm_find_path}/lcmtypes/${arg}.lcm)
    list(APPEND _lcmtypes_c_files ${_lcmtypes_c_dir}/${arg}.c)
    list(APPEND _lcmtypes_h_files ${_lcmtypes_h_dir}/${arg}.h)
    string(REPLACE "${_lcm_package_name}_" "" tmp_hpp ${arg})
    list(APPEND _lcmtypes_hpp_files_in ${_lcmtypes_cpp_dir}/${tmp_hpp}.hpp)
    list(APPEND _lcmtypes_hpp_files ${_lcmtypes_h_dir}/${tmp_hpp}.hpp)
    list(APPEND _lcmtypes_py_files ${_lcmtypes_python_dir}/${tmp_hpp}.py)
    list(APPEND _lcmtypes_py_files_in ${_lcmtypes_python_dir_in}/${tmp_hpp}.py)
    list(APPEND _lcmtypes_java_files ${_lcmtypes_java_dir}/${_lcm_package_name}/${tmp_hpp}.java)
    message(STATUS "Adding LCM type '${arg}'")
  endforeach()
  list(APPEND JAVA_INSTALL_JARS ${LCMTYPES_JAR})
endmacro(AddLCM)

macro(AddSpyLCM _jarname)
  list(APPEND _spy_lcm_jars ${_jarname})
  list(APPEND JAVA_INSTALL_JARS ${CATKIN_DEVEL_PREFIX}/share/java/lcmspy_plugins_${_jarname}.jar)
  set(_jar_sources_${_jarname} "${ARGN}")
endmacro(AddSpyLCM)

macro(GetLCMPackageName ret name)
  if(${name} MATCHES "_lcmtypes")
    string(REPLACE "_lcmtypes" "" ${ret} ${name})
  else()
    set(ret "")
  endif()
endmacro(GetLCMPackageName)

macro(GetLCMPackageNameSelf ret name)
  if(${name} MATCHES "_lcmtypes")
    string(REPLACE "_lcmtypes" "" ${ret} ${name})
  else()
    set(ret ${name})
  endif()
endmacro(GetLCMPackageNameSelf)

macro(GetPackages ret)
  set(${ret} "")
  GetLCMPackageNameSelf(tmp ${PROJECT_NAME})
  list_append_unique(${ret} ${tmp})
  foreach(depend_name ${catkin_ALL_FOUND_COMPONENTS})
    GetLCMPackageNameSelf(tmp ${depend_name})
    list_append_unique(${ret} ${tmp})
  endforeach()
endmacro(GetPackages)

function(lcmtypes_build_c)
    list(LENGTH _lcmtypes _num_lcmtypes)
    if(_num_lcmtypes EQUAL 0)
        return()
    endif()

    MATH(EXPR _num_lcmtypes2 "${_num_lcmtypes}*2")
    GetPackages(_lcm_packages)

    string(REGEX REPLACE "[^a-zA-Z0-9]" "_" __sanitized_project_name "${PROJECT_NAME}")

    # set some defaults

    # header file that includes all other generated header files
    set(agg_h_bname "${__sanitized_project_name}.h")

    # allow defaults to be overriden by function parameters
    set(modewords C_LIBNAME C_AGGREGATE_HEADER)

    # create a header file aggregating all of the autogenerated .h files
    set(__agg_h_fname "${_lcmtypes_h_dir}/${agg_h_bname}")
    file(WRITE ${__agg_h_fname}
        "#ifndef __lcmtypes_${__sanitized_project_name}_h__\n"
        "#define __lcmtypes_${__sanitized_project_name}_h__\n\n")
    foreach(h_file ${_lcmtypes_h_files})
        file(RELATIVE_PATH __tmp_path ${CATKIN_DEVEL_PREFIX}/include ${h_file})
        file(APPEND ${__agg_h_fname} "#include \"${__tmp_path}\"\n")
    endforeach()
    file(APPEND ${__agg_h_fname} "\n#endif\n")
    list(APPEND _lcmtypes_h_files ${__agg_h_fname})

    # generate C bindings for LCM types

    add_custom_command(
      OUTPUT ${_lcmtypes_c_files} ${_lcmtypes_h_files}
      COMMAND sh -c '([ -d ${_lcmtypes_c_dir} ] || mkdir -p ${_lcmtypes_c_dir}) && ${LCM_GEN_EXECUTABLE} -c --c-cpath ${_lcmtypes_c_dir} --c-hpath ${_lcmtypes_h_dir} ${_lcmtypes}'
      COMMAND sh -c '${_lcm_redirct_script} ${_num_lcmtypes2} ${_lcmtypes_c_files} ${_lcmtypes_h_files} ${_lcm_packages}'
      DEPENDS ${_lcmtypes}
      COMMENT "Generating LCM types (native c)"
    )

    add_custom_target(${PROJECT_NAME}_lcmgen_c ALL DEPENDS ${_lcmtypes} ${_lcmtypes_h_files} ${__agg_h_fname})
    add_library(${libname} ${_lcmtypes_c_files})
    add_dependencies(lcmtypes_${PROJECT_NAME} ${PROJECT_NAME}_lcmgen_c ${catkin_EXPORTED_TARGETS})

    unset(__sanitized_project_name)
    unset(__agg_h_fname)
endfunction()

function(lcmtypes_build_cpp)
    list(LENGTH _lcmtypes _num_lcmtypes)
    if(_num_lcmtypes EQUAL 0)
        return()
    endif()

    GetPackages(_lcm_packages)
    GetLCMPackageName(_lcm_package_name ${PROJECT_NAME})

    string(REGEX REPLACE "[^a-zA-Z0-9]" "_" __sanitized_project_name "${PROJECT_NAME}")

    # header file that includes all other generated header files
    set(agg_hpp_bname "${__sanitized_project_name}.hpp")

    # create a header file aggregating all of the autogenerated .hpp files
    set(__agg_hpp_fname "${_lcmtypes_h_dir}/${agg_hpp_bname}")
    file(WRITE ${__agg_hpp_fname}
        "#ifndef __lcmtypes_${__sanitized_project_name}_hpp__\n"
        "#define __lcmtypes_${__sanitized_project_name}_hpp__\n\n")
    foreach(hpp_file ${_lcmtypes_hpp_files})
        file(RELATIVE_PATH __tmp_path ${CATKIN_DEVEL_PREFIX}/include ${hpp_file})
        file(APPEND ${__agg_hpp_fname} "#include \"${__tmp_path}\"\n")
    endforeach()
    file(APPEND ${__agg_hpp_fname} "\n#endif\n")

    # generate C++ bindings for LCM types
    add_custom_target(${PROJECT_NAME}_lcmgen_cpp ALL DEPENDS ${_lcmtypes} ${__agg_hpp_fname})
    add_custom_command(
      TARGET ${PROJECT_NAME}_lcmgen_cpp
      COMMAND sh -c '([ -d ${_lcmtypes_h_dir} ] || mkdir -p ${_lcmtypes_h_dir}) && ${LCM_GEN_EXECUTABLE} --cpp --cpp-hpath ${_lcmtypes_cpp_dir} ${_lcmtypes}'
      COMMAND sh -c 'cp ${_lcmtypes_cpp_dir}/${_lcm_package_name}/* ${_lcmtypes_h_dir}'
      COMMAND sh -c '${_lcm_redirct_script} ${_num_lcmtypes} ${_lcmtypes_hpp_files} ${_lcm_packages}'
      DEPENDS ${_lcmtypes}
    )
    include_directories(${CATKIN_DEVEL_PREFIX}/include)

    unset(__sanitized_project_name)
    unset(__agg_hpp_fname)
endfunction()

function(lcmtypes_build_python)
    list(LENGTH _lcmtypes _num_lcmtypes)
    if(_num_lcmtypes EQUAL 0)
        return()
    endif()

    GetPackages(_lcm_packages)

    add_custom_target(${PROJECT_NAME}_lcmgen_py ALL DEPENDS ${_lcmtypes})
    add_custom_command(
      TARGET ${PROJECT_NAME}_lcmgen_py
      COMMAND sh -c '([ -d ${_lcmtypes_python_dir_in} ] || mkdir -p ${_lcmtypes_python_dir_in}) && ${LCM_GEN_EXECUTABLE} -p ${_lcmtypes} --ppath ${_lcmtypes_python_dir_in}'
      COMMAND sh -c '([ -d ${_lcmtypes_python_dir} ] || mkdir -p ${_lcmtypes_python_dir}) && cp ${_lcmtypes_python_dir_in}/${_lcm_package_name}/* ${_lcmtypes_python_dir}'
      COMMAND sh -c '${_lcm_redirct_script} ${_num_lcmtypes} ${_lcmtypes_py_files} ${_lcm_packages} && python -m compileall ${_lcmtypes_python_dir}'
      DEPENDS ${_lcmtypes}
    )

endfunction()

function(lcmtypes_build_java)
    list(LENGTH _lcmtypes _num_lcmtypes)
    if(_num_lcmtypes EQUAL 0)
        return()
    endif()

    find_package(Java)

    GetPackages(_lcm_packages)

    # do we have LCM java bindings?  where is lcm.jar?
    execute_process(COMMAND pkg-config --variable=classpath lcm-java OUTPUT_VARIABLE LCM_JAR_FILE)
    if(NOT LCM_JAR_FILE)
        message(STATUS "Not building Java LCM type bindings (Can't find lcm.jar)")
        return()
    endif()
    string(STRIP ${LCM_JAR_FILE} LCM_JAR_FILE)
    


    add_custom_command(
      OUTPUT ${_lcmtypes_java_files}
      COMMAND sh -c '([ -d ${_lcmtypes_java_dir} ] || mkdir -p ${_lcmtypes_java_dir}) && ${LCM_GEN_EXECUTABLE} -j ${_lcmtypes} --jpath ${_lcmtypes_java_dir}'
      COMMAND sh -c '([ -d ${CATKIN_DEVEL_PREFIX}/share/java ] || mkdir -p ${CATKIN_DEVEL_PREFIX}/share/java) '
      DEPENDS ${_lcmtypes}
      COMMENT "Generating LCM types (Java)"
    )

    add_custom_target(${PROJECT_NAME}_lcmgen_java ALL DEPENDS ${_lcmtypes} ${_lcmtypes_java_files})

    set(java_classpath ${_lcmtypes_java_dir}:${LCM_JAR_FILE})

    # search for lcmtypes_*.jar files in well-known places and add them to the
    # classpath
    string(REPLACE ":" ";" ROS_PACKAGE_PATH $ENV{ROS_PACKAGE_PATH})
    set(_java_deps)
    foreach(pfx ${catkin_ALL_FOUND_COMPONENTS})
        if(";${${pfx}_EXPORTED_TARGETS};" MATCHES ";lcmtypes_${pfx}_all;")
            set(java_classpath ${java_classpath}:${CATKIN_DEVEL_PREFIX}/share/java/lcmtypes_${pfx}.jar:${CMAKE_INSTALL_PREFIX}/share/java/lcmtypes_${pfx}.jar)
            foreach(pth ${ROS_PACKAGE_PATH})
                set(java_classpath ${java_classpath}:${pth}/../share/java/lcmtypes_${pfx}.jar:${pth}/../share/java/lcmtypes_${pfx}.jar)
            endforeach()
            set(java_classpath ${java_classpath}:/opt/oh-distro/share/java/lcmtypes_${pfx}.jar)
            list_append_unique(_java_deps lcmtypes_${pfx}_all)
        endif()
    endforeach()

    #message(Java: ${java_classpath})

    # convert the list of .java filenames to a list of .class filenames
    foreach(javafile ${_lcmtypes_java_files})
        string(REPLACE .java .class __tmp_class_fname ${javafile})
        list(APPEND _lcmtypes_class_files ${__tmp_class_fname})
        unset(__tmp_class_fname)
    endforeach()

    # add a rule to build the .class files from from the .java files
    add_custom_command(OUTPUT ${_lcmtypes_class_files}
        COMMAND ${JAVA_COMPILE} -source 7 -target 7 -cp ${java_classpath} ${_lcmtypes_java_files}
        DEPENDS ${_lcmtypes_java_files}
        VERBATIM
        COMMENT "Compiling LCM types (Java)"
    )

    # add a rule to build a .jar file from the .class files
    add_custom_command(OUTPUT ${LCMTYPES_JAR}
        COMMAND ${JAVA_ARCHIVE} cf ${LCMTYPES_JAR} -C ${_lcmtypes_java_dir} .
        DEPENDS ${_lcmtypes_class_files}
        VERBATIM)
    add_custom_target(lcmtypes_${PROJECT_NAME}_jar ALL DEPENDS ${LCMTYPES_JAR})

    add_dependencies(lcmtypes_${PROJECT_NAME}_jar ${PROJECT_NAME}_lcmgen_java ${_java_deps} ${catkin_EXPORTED_TARGETS})
    add_dependencies(lcmtypes_${PROJECT_NAME}_all lcmtypes_${PROJECT_NAME}_jar)    

endfunction()

function(lcmtypes_build_java_plugins)

    list(LENGTH _spy_lcm_jars _num_plugins)
    if(_num_plugins EQUAL 0)
        return()
    endif()

    find_package(Java)

    

    # do we have LCM java bindings?  where is lcm.jar?
    execute_process(COMMAND pkg-config --variable=classpath lcm-java OUTPUT_VARIABLE LCM_JAR_FILE)
    if(NOT LCM_JAR_FILE)
        message(STATUS "Not building Java LCM type bindings (Can't find lcm.jar)")
        return()
    endif()
    string(STRIP ${LCM_JAR_FILE} LCM_JAR_FILE)
    

    set(java_classpath ${_lcmtypes_java_dir}:${LCM_JAR_FILE})

    # search for lcmtypes_*.jar files in well-known places and add them to the
    # classpath
    string(REPLACE ":" ";" ROS_PACKAGE_PATH $ENV{ROS_PACKAGE_PATH})
    set(_java_deps)
    foreach(pfx ${catkin_ALL_FOUND_COMPONENTS})
        if(";${${pfx}_EXPORTED_TARGETS};" MATCHES ";lcmtypes_${pfx}_all;")
            set(java_classpath ${java_classpath}:${CATKIN_DEVEL_PREFIX}/share/java/lcmtypes_${pfx}.jar:${CMAKE_INSTALL_PREFIX}/share/java/lcmtypes_${pfx}.jar)
            foreach(pth ${ROS_PACKAGE_PATH})
                set(java_classpath ${java_classpath}:${pth}/../share/java/lcmtypes_${pfx}.jar:${pth}/../share/java/lcmtypes_${pfx}.jar)
            endforeach()
            set(java_classpath ${java_classpath}:/opt/oh-distro/share/java/lcmtypes_${pfx}.jar)
            list_append_unique(_java_deps lcmtypes_${pfx}_all)
        endif()
    endforeach()
    set(java_classpath ${java_classpath}:${LCMTYPES_JAR})

    foreach(_spy_jar ${_spy_lcm_jars})
            set(LCMSPY_JAR ${CATKIN_DEVEL_PREFIX}/share/java/lcmspy_plugins_${_spy_jar}.jar)

	    #message(Java: ${java_classpath})

            set(_spy_java_files_in ${_jar_sources_${_spy_jar}})
            set(_spy_java_files)
            #message(JAR: ${_spy_jar})
            #message(src: ${_spy_java_files_in})

	    # convert the list of .java filenames to a list of .class filenames
	    foreach(javafile ${_spy_java_files_in})
		get_filename_component(__tmp_class_fname ${javafile} NAME_WE)
		list(APPEND _spy_class_files ${_lcmtypes_java_dir}/spy_plugins/${__tmp_class_fname}.class)
                get_filename_component(__tmp_java_fname ${javafile} ABSOLUTE)
                list(APPEND _spy_java_files ${__tmp_java_fname})
		unset(__tmp_class_fname)
                unset(__tmp_java_fname)
	    endforeach()

            #message(src: ${_spy_java_files})
	    #message(calss: ${_spy_class_files})

	    # add a rule to build the .class files from from the .java files
	    add_custom_command(OUTPUT ${_spy_class_files}
		COMMAND sh -c "([ -d ${_lcmtypes_java_dir}/spy_plugins ] || mkdir -p ${_lcmtypes_java_dir}/spy_plugins) "
		COMMAND sh -c "([ -d ${CATKIN_DEVEL_PREFIX}/share/java ] || mkdir -p ${CATKIN_DEVEL_PREFIX}/share/java) "
		COMMAND ${JAVA_COMPILE} -source 7 -target 7 -cp ${java_classpath} -d ${_lcmtypes_java_dir}/spy_plugins ${_spy_java_files}
		DEPENDS ${_spy_java_files}
		VERBATIM
		COMMENT "Compiling LCM-SPY plugins (Java)"
	    )

	    # add a rule to build a .jar file from the .class files
	    add_custom_command(OUTPUT ${LCMSPY_JAR}
		COMMAND ${JAVA_ARCHIVE} cf ${LCMSPY_JAR} -C ${_lcmtypes_java_dir}/spy_plugins .
		DEPENDS ${_spy_class_files}
		VERBATIM)
	    add_custom_target(lcmspy_${_spy_jar}_jar ALL DEPENDS ${LCMSPY_JAR})

	    add_dependencies(lcmspy_${_spy_jar}_jar lcmtypes_${PROJECT_NAME}_jar ${_java_deps} ${catkin_EXPORTED_TARGETS})
	    add_dependencies(lcmtypes_${PROJECT_NAME}_all lcmspy_${_spy_jar}_jar)
    endforeach()

endfunction()

macro(GenerateLCM)
    #find lcm-gen (it may be in the install path)
    find_program(LCM_GEN_EXECUTABLE lcm-gen ${EXECUTABLE_OUTPUT_PATH} ${EXECUTABLE_INSTALL_PATH})
    if (NOT LCM_GEN_EXECUTABLE)
        message(FATAL_ERROR "lcm-gen not found!\n")
        return()
    endif()

    lcmtypes_build_c()
    lcmtypes_build_cpp()
    lcmtypes_build_java(${ARGV})
    lcmtypes_build_java_plugins()
    lcmtypes_build_python()

    install(TARGETS ${libname}
        ARCHIVE DESTINATION ${CATKIN_PACKAGE_LIB_DESTINATION}
        LIBRARY DESTINATION ${CATKIN_PACKAGE_LIB_DESTINATION}
        RUNTIME DESTINATION ${CATKIN_GLOBAL_BIN_DESTINATION})
    install(DIRECTORY ${_lcmtypes_h_dir}/
        DESTINATION ${CATKIN_PACKAGE_INCLUDE_DESTINATION}
        PATTERN ".svn" EXCLUDE)
    install(DIRECTORY ${_lcmtypes_python_dir}/
        DESTINATION ${CATKIN_PACKAGE_PYTHON_DESTINATION}
        PATTERN ".svn" EXCLUDE)
    install(FILES ${JAVA_INSTALL_JARS}
        DESTINATION share/java)
    #lcmtypes_install_types()
endmacro()
