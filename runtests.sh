#!/bin/bash

script_name=$(basename ${0}); pushd $(dirname ${0}) >/dev/null
script_path=$(pwd -P); popd >/dev/null

. "${script_path}/util-web.sh"

newline_char="\r\n"

test_ok="... ok"
test_fail="... fail"

function action_cloning_source() {
    echo " - Cloning source from https://github.com/docker-exec/${1}.git"
}
function action_testing_image() {
    echo "Testing image: docker-exec/${1}"
}
function action_running_test() {
    echo " - Running test: ${1}"
}
function action_building_image() {
    echo " - Building Docker image ${1}"
}

declare -a failures
declare -i successes=0

declare -a initial_state
declare -a end_state

workdir=".workspace"

use_dexec=false
do_pre_clean=true
do_post_clean=true
do_build=true

# use_dexec=true
# do_pre_clean=true
# do_post_clean=false
# do_build=false

function run_with_docker() {
    docker_image=${1}; shift
    dexec_args=("${@}")

    docker run -t --rm \
        -v $(pwd -P):/tmp/dexec/build:rw \
        ${docker_image} "${dexec_args[@]}"
}

function run_with_dexec() {
    dexec_args=("${@}")

    dexec "${dexec_args[@]}"
}

function print_action() {
    local action_name="${1}"
    printf "\r%s\r" "${action_name}"
}

function print_action_status() {
    local padding=$(printf '%0.1s' " "{1..80})
    local action_name="${1}"
    local action_status="${2}"
    printf "\r%s %s ${action_status}\n" "${action_name}" "${padding:${#action_name}}"
}

function state_matches() {
    local state_matches=0
    for i in `seq 0 $((${#initial_state[@]} - 1))`; do
        if [ "${initial_state[i]}" != "${end_state[i]}" ]; then
            local state_matches=1
            break
        fi
    done
    for i in `seq 0 $((${#end_state[@]} - 1))`; do
        if [ "${initial_state[i]}" != "${end_state[i]}" ]; then
            local state_matches=1
            break
        fi
    done
    return "${state_matches}"
}

function clean_docker() {
    local image_name="${1}"
    docker rmi -f ${image_name} &>/dev/null
    (docker images -aqf dangling=true | xargs docker rmi -f) &>/dev/null
}

function clean_target() {
    local target="${1}"
    rm -rf ${script_path}/${workdir}/${target} &>/dev/null
}

function clone_source() {
    local target="${1}"
    print_action "$(action_cloning_source ${target})"
    git clone https://github.com/docker-exec/${target}.git ${script_path}/${workdir}/${target} --recursive &>/dev/null
    print_action_status "$(action_cloning_source ${target})" "${test_ok}"
}

function build_target_image() {
    local image_name="${1}"
    print_action "$(action_building_image ${image_name})"
    docker build -t ${image_name} . &>/dev/null
    print_action_status "$(action_building_image ${image_name})" "${test_ok}"
}

function load_state_into() {
    local state_var="${1}"
    eval "${state_var}=($(find . -maxdepth 1 ! -path .))"
}

function execute_stdout_test() {
    local target="$1"; shift
    local image_name="$1"; shift
    local test_name="$1"; shift
    local file_pattern="$1"; shift
    local expected_result=$(echo -e "$1"); shift
    local arguments=("${@}")

    load_state_into "initial_state"

    print_action "$(action_running_test ${test_name})"

    local source_file=$(find . -maxdepth 1 ! -path . -type f -iregex ${file_pattern} | xargs basename)

    if [[ -z ${source_file} ]]; then
        failures+=("${target}: ${test_name} (could not find source)")
        print_action_status "$(action_running_test ${test_name})" "${test_fail}"
        return
    fi

    if [ "${use_dexec}" = "true" ]; then
        local actual_result=$(run_with_dexec ${source_file} "${arguments[@]}")
    else
        local actual_result=$(run_with_docker ${image_name} ${source_file} "${arguments[@]}")
    fi

    load_state_into "end_state"

    if ! $(state_matches); then
        print_action_status "$(action_running_test ${test_name})" "${test_fail}"
        failures+=("${target}: ${test_name} (dirty working directory)")
    elif [ "${actual_result}" = "${expected_result}" ]; then
        print_action_status "$(action_running_test ${test_name})" "${test_ok}"
        successes=$((successes + 1))
    else
        print_action_status "$(action_running_test ${test_name})" "${test_fail}"
        failures+=("${target}: ${test_name} (expected != actual)")
    fi
}

function test_image() {
    local target="${1}"
    local image_name="dexec/${target}:testing"

    echo "$(action_testing_image ${target})"
    if [ "${do_pre_clean}" = "true" ]; then
        clean_docker "${image_name}"
        clean_target "${target}"
        clone_source "${target}"
    fi

    mkdir -p "${script_path}/${workdir}/${target}"

    pushd ${script_path}/${workdir}/${target} >/dev/null
    if [ "${do_build}" = "true" ]; then
        build_target_image ${image_name}
        sleep 5
    fi

    pushd ${script_path}/${workdir}/${target}/test >/dev/null
    execute_stdout_test "${target}" \
                        "${image_name}" \
                        "hello world" \
                        ".*helloworld.*" \
                        "hello world${newline_char}"

    execute_stdout_test "${target}" \
                        "${image_name}" \
                        "shebang removal" \
                        ".*shebang.*" \
                        "hello world${newline_char}"

    execute_stdout_test "${target}" \
                        "${image_name}" \
                        "echo chamber" \
                        ".*echochamber.*" \
                        "a${newline_char}a b${newline_char}a b c${newline_char}x y${newline_char}z${newline_char}" \
                        -a 'a' -a 'a b' -a 'a b c' -a 'x y' -a z

    popd >/dev/null
    popd >/dev/null

    if [ "${do_post_clean}" = "true" ]; then
        clean_docker
        clean_target "${target}"
    fi

    echo
}

function test_images() {
    local all_dirs=($(get_github_repos))
    local target_dirs=($(for target_dir in "${all_dirs[@]}"; do
        echo "${target_dir}" | grep -Eve "^(base-|image-|docker-exec|dexec)"
    done))

    if [ ! -z "${1}" ]; then
        local target_dirs=("${@}")
    fi

    for target in "${target_dirs[@]}"; do
        test_image "${target}"
    done
}

function print_results() {
    echo "Tests run       : $((${#failures[@]} + ${successes}))"
    echo "Tests succeeded : ${successes}"
    echo "Tests failed    : ${#failures[@]}"

    if [ ${#failures[@]} -gt 0 ]; then
        for failure in "${failures[@]}"; do
            echo " - ${failure}"
        done
        exit 1
    fi
}

function validate() {
    if [[ ! -x $(which curl) ]]; then
        echo "curl not found" >&2
        exit 1
    fi
    if [[ ! -x $(which docker) ]]; then
        echo "Docker not found" >&2
        exit 1
    fi
    if [[ ${OSTYPE} == "linux-gnu" ]] && [ "$(id -u)" != "0" ]; then
       echo "This script must be run as root" >&2
       exit 1
    fi
}

validate
test_images "${@}"
print_results
