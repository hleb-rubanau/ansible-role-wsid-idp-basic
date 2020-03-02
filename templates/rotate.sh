#!/bin/bash

ID="${1:-_}"
USER_PRIVATE_DIR="{{ wsid_var_run }}/private/$ID"
USER_PUBLIC_DIR="{{ wsid_var_run }}/public/$ID"

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
    if [ -e "$oldfile" ]; then
        mv -vf "$oldfile" "${oldfile}.old"
    else
        echo "No preexisting file '$oldfile' found"
    fi
}

function generate_passwdfile() {
    pwgen | tee "$PASSWDFILE" | python -c 'import nacl.pwhash; import sys; print( nacl.pwhash.str(line.strip())+"\n" for line in sys.stdin.readlines(); ' > "$PASSWDHASHFILE"
    echo "New password stored at $PASSWDFILE, hash in $PASSWDHASHFILE"
}  

function generate_key_file() {
    openssl genpkey -algorithm ed25519 -outform PEM | tee "$KEYFILE" | openssl pkey -pubout -out "$PUBLIC_KEY_FILE" 
    echo "New SSH key stored at $KEYFILE, pubkey in $PUBLIC_KEY_FILE"
} 

function run_hooks() {
    hooksdir="$1"
    if ![ -e "$hooksdir" ]; then
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

prepare_directories 2>&1 | with_logger 
move_old_file "$PASSWDHASHFILE" 2>&1 | with_logger 
generate_passwdfile 2>&1 | with_logger
run_hooks "$PASSWD_HOOKS_DIR" 2>&1 | with_logger

move_old_file "$PUBLIC_KEY_FILE" 2>&1 | with_logger
generate_key_file 2>&1 | with_logger 
run_hooks "$KEY_HOOKS_DIR" 2>&1 | with_logger

