#!/bin/bash

# test-all.sh
# Runs all hyperdsl tests: Delite framework, Delite DSL, and Forge DSL tests
# Used by Jenkins to verify commits.

# add new DSLs to test here
dsls=(
    "SimpleIntVector"
    "SimpleVector"
    "OptiML"
    "OptiQL"
    "OptiGraph"
    "OptiWrangler"
    )
runners=(
    "ppl.dsl.forge.examples.SimpleIntVectorDSLRunner"
    "ppl.dsl.forge.examples.SimpleVectorDSLRunner"
    "ppl.dsl.forge.dsls.optiml.OsptiMLDSLRunner"
    "ppl.dsl.forge.dsls.optiql.OptiQLDSLRunner"
    "ppl.dsl.forge.dsls.optigraph.OptiGraphDSLRunner"
    "ppl.dsl.forge.dsls.optiwrangler.OptiWranglerDSLRunner"
    )

# exit if any part of the script fails
#set -e

E_BADENV=65

echoerr() { echo "error: $@" 1>&2; } # 1>&2 redirects stdout to stderr
env_var_error() {
    echoerr "$1 environment variable is not defined. Please set it to the appropriate project root directory or run 'source init-env.sh'";
    exit $E_BADENV;
}
# check for required env variables
if [ -z "${HYPER_HOME}" ]; then env_var_error HYPER_HOME; fi
if [ -z "${LMS_HOME}" ]; then env_var_error LMS_HOME; fi
if [ -z "${DELITE_HOME}" ]; then env_var_error DELITE_HOME; fi
if [ -z "${FORGE_HOME}" ]; then env_var_error FORGE_HOME; fi

config_file_error() {
    echoerr "$1 is not present. Check ${DELITE_HOME}/config/delite/ for a configuration for your platform";
    exit $E_BADENV;
}
check_config_file() {
    if [ ! -f "${DELITE_HOME}/config/delite/$1" ]; then config_file_error $1; fi
}
# check for required configuration files
check_config_file CPP.xml
check_config_file BLAS.xml
check_config_file CUDA.xml
check_config_file cuBLAS.xml

# remove previous delite runtime cache
rm -rf $DELITE_HOME/generatedCache

# all non-Forge tests
echo "[test-all]: running Delite and Delite DSL tests"
sbt -Dtests.threads=1,19 -Dtests.targets=scala,cpp "; project tests; test"
(( st = st || $? ))

listcontains() {
  for elem in $1; do
    [[ $elem = $2 ]] && return 0
  done
  return 1
}
# delite test with GPU
if listcontains "$@" --cuda; then
	echo "[test-all]: running Delite CUDA tests"
	sbt -Dtests.threads=1 -Dtests.targets=cuda "; project delite-test; test"
	(( st = st || $? ))
fi

# all Forge DSL tests
echo "[test-all]: running Forge DSL tests"

for i in `seq 0 $((${#dsls[@]}-1))` 
do  
    pushd .
    dsl=${dsls[$i]} 
    $FORGE_HOME/bin/update ${runners[$i]} $dsl 
    cd published/$dsl/
    echo "[test-all]: running $dsl tests"
    sbt -Dtests.threads=1,19 -Dtests.targets=scala,cpp "; project $dsl-tests; test"
    (( st = st || $? ))
    if listcontains "$@" --cuda; then
    	echo "[test-all]: running $dsl tests (CUDA)"
    	sbt -Dtests.threads=1 -Dtests.targets=cuda "; project $dsl-tests; test"
    	(( st = st || $? ))
    fi
    popd
done

echo "[test-all]: All tests finished!"

if [ "$1" != "--no-benchmarks" ]; then
	echo "[test-all]: Running benchmarks"
	benchmark/benchmark.py -v -f
	(( st = st || $? ))
	echo "[test-all]: Benchmarks finished!"
fi

exit $st
