#!/bin/bash

function run() {
    real_wsid_path="$( readlink -f '{{ wsid_var_run }}' )"
    echo "Deleting $real_wsid_path"
    rm -rfv "$real_wsid_path"
}

run 2>&1 | logger -e -s -t wsid
