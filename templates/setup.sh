#!/bin/bash

function prepare_directories() {
    wsid_temp_dir=$( mktemp -d /tmp/wsid.XXXXX )
    wsid_var_run="{{ wsid_var_run }}"

    if [ -e "$wsid_var_run" ]; then
        rm -rfv "$wsid_var_run"
    fi 

    ln -sfv "$wsid_temp_dir" "$wsid_var_run" 

    wsid_private_dir="${wsid_var_run}/private/_"
    wsid_public_dir="${wsid_var_run}/public/_"

    mkdir -pv "$wsid_private_dir" "$wsid_public_dir"
}

function generate_password() {
    pwgen > "${wsid_private_dir}/passwd"
}

prepare_directories 2>&1 | logger -e -s -t wsid

{% for wsid_identity in wsid_identities %}
echo "Running rotation script for {{wsid_identity}}" 2>&1 | logger -e -s -t wsid
{{ wsid_script_rotate }} "{{ wsid_identity }}"
{% endfor %}
