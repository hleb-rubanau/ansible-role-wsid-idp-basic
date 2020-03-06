#!/bin/bash

ID="${1:-_}"
USER_PRIVATE_DIR="{{ wsid_var_run }}/private/$ID"
USER_PUBLIC_DIR="{{ wsid_var_run }}/public/$ID"

ROTATION_TIMESTAMP=$( date +%s )

PASSWDFILE="${USER_PRIVATE_DIR}/passwd"
PASSWDHASHFILE="${ USER_PUBLIC_DIR }/passwdhash"
PASSWD_HOOKS_DIR="{{ wsid_hooks_passwd_dir }}/$ID"

KEYFILE="${USER_PRIVATE_DIR}/id_ed25519"
PUBLIC_KEY_FILE="${USER_PUBLIC_DIR}/id_ed25519.pub"
KEY_HOOKS_DIR="{{ wsid_hooks_key_dir }}/$ID"

function prepare_directories() {
    mkdir -pv "$USER_PRIVATE_DIR"
    mkdir -pv "$USER_PUBLIC_DIR"
}

function with_logger() {
    logger -e -s -t wsid
}   

function move_old_file() {
    oldfile="$1"
    if [ -e "$oldfile.new" ]; then
        mv -vf "$oldfile.new" "${oldfile}.old" ;
    else
        echo -n '' > "${oldfile}.old" ;
    fi
}

function generate_passwdfile() {
    local secret_file=$1
    local public_file="$2.new"
    pwgen | tee "$secret_file" | python3 -c 'import nacl.pwhash; import sys; print( "\n".join( [ nacl.pwhash.str(line.strip()) for line in sys.stdin.readlines() ] )+"\n" ); ' > "$public_file"
    echo "New password stored at $secret_file, hash in $public_file"
}  

function generate_key_file() {
    local secret_file="$1"
    local public_file="$2.new"
    openssl genpkey -algorithm ed25519 -outform PEM | tee "$secret_file" | openssl pkey -pubout -out "$public_file" 
    echo "New SSH key stored at $secret_file, pubkey in $public_file"
} 

function run_hooks() {
    hooksdir="$1"
    if [ ! -e "$hooksdir" ]; then
        echo "Hooks directory $hooksdir does not exist, running no hooks"
    else
        echo "Checking for hooks in $hooksdir"
        cd "$hooksdir"
        for hook in $( find . -type -f ); do
            echo "Running hook $hook"
            $hook
        done
    fi
}

function rebuild_combined() {
    outfile="$1"
    cat "$outfile.old" "$outfile.new" > "$outfile"
}

prepare_directories 2>&1 | with_logger 

move_old_file "$PASSWDHASHFILE" 2>&1 | with_logger 
generate_passwdfile "$PASSWDFILE" "$PASSWDHASHFILE" 2>&1 | with_logger
rebuild_combined "$PASSWDHASHFILE" 2>&1 | with_logger
run_hooks "$PASSWD_HOOKS_DIR" 2>&1 | with_logger

move_old_file "$PUBLIC_KEY_FILE" 2>&1 | with_logger
generate_key_file "$KEYFILE" "$PUBLIC_KEY_FILE" 2>&1 | with_logger 
rebuild_combined "$PUBLIC_KEY_FILE" 2>&1 | with_logger
run_hooks "$KEY_HOOKS_DIR" 2>&1 | with_logger

