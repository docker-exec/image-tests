#!/bin/bash

declare -a headers

function get_headers() {
    local url="${1}"
    headers=("$(curl -sIL "${url}" | grep ':')")
}

function get_header() {
    shopt -s extglob # Required to trim whitespace; see below
    while IFS=':' read key value; do
        value=${value##+([[:space:]])}; value=${value%%+([[:space:]])}

        if [ "$key" = "${1}" ]; then
            echo "$value"
            return 0
        fi
     done
     return 1
}

function get_content() {
    local url="${1}"
    local content
    content=$(curl -sL "${url}")
    echo "${content}"
}

function get_paged_content() {
    shopt -s extglob

    while IFS=':' read key value; do
        value=${value##+([[:space:]])}; value=${value%%+([[:space:]])}
        if [ "$key" = "Link" ]; then link_header="$value"; fi
    done < <(curl -sIL "${1}")

    # echo "link header: ${link_header}" >&2

    link_pattern="^<(.+)>.*rel=\"(.*)\".*<(.+)>.+$"

    next=$(sed -Ee "s/${link_pattern}/\1/" <<<"${link_header}")
    relation=$(sed -Ee "s/${link_pattern}/\2/" <<<"${link_header}")
    # last=$(sed -Ee "s/${link_pattern}/\3/" <<<"${link_header}")

    # echo "next: ${next}" >&2
    # echo "last: ${last}" >&2
    # echo "rel:  ${relation}" >&2

    if [ ! -z "${next}" ] && [ "${relation}" = "next" ]; then
        printf "%s\n%s" "$(get_content "${1}")" "$(get_paged_content "${next}")"
    else
        printf "%s" "$(get_content "${1}")"
    fi
}

function get_github_repos() {
    local name_pattern='.*"name": "(.+)",'
    repos=($(get_paged_content https://api.github.com/orgs/docker-exec/repos \
                | grep '"name"' \
                | sed -Ee "s/${name_pattern}/\1/" \
                | sort))
    echo "${repos[@]}"
}
