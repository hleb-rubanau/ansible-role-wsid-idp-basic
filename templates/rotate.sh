#!/bin/bash

WSID_PRIVATE_DIR="{{ wsid_var_run }}/private"
WSID_PUBLIC_DIR="{{ wsid_var_run }}/public"
WSID_PASSWD_HOOKS_DIR="{{ wsid_hooks_passwd_dir }}"
WSID_KEY_HOOKS_DIR="{{ wsid_hooks_key_dir }}"
WSID_DELAY_BEFORE_UPDATE_SECONDS={{wsid_delay_before_update_seconds}}



function with_logger() {
    logger -e -s -t wsid-rotate
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
    local secret_file="$1"
    local public_file="$2"
    pwgen | tee "$secret_file" | python3 -c 'import nacl.pwhash; import sys; print( "\n".join( [ nacl.pwhash.str(line.strip().encode()).decode() for line in sys.stdin.readlines() ] )+"\n" ); ' > "$public_file"
    echo "New password stored at $secret_file, hash in $public_file"
}  

function generate_key_file() {
    local secret_file="$1"
    local public_file="$2"
    local wsid_id="$3"
    #openssl genpkey -algorithm ed25519 -outform PEM | tee "$secret_file" | openssl pkey -pubout -out "$public_file" 
    echo -e 'y\n' | ssh-keygen -t ed25519 -N '' -C "$wsid_id" -f "$secret_file" && mv -v "$secret_file.pub" "$public_file"
    echo "New SSH key stored at $secret_file, pubkey in $public_file"
} 

function rebuild_combined() {
    outfile="$1"
    # newest always comes first, it may be useful
    cat "$outfile.new" "$outfile.old" | egrep -v '^$' > "$outfile"
}

function run_hooks() {
    hooksdir="$1"
    if [ ! -e "$hooksdir" ]; then
        echo "Hooks directory $hooksdir does not exist, running no hooks"
    else
        echo "Checking for hooks in $hooksdir"
        cd "$hooksdir"
        for hook in $( find . -type f ); do
            echo "Running hook $hook"
            $hook
        done
        cd -
    fi
}



function do_rotation() {
    local wsid_id="$1"
    echo "Secrets rotation for identity '$wsid_id'"
    local identity_private_dir="$WSID_PRIVATE_DIR/$wsid_id"
    local identity_public_dir="$WSID_PUBLIC_DIR/$wsid_id"

    mkdir -pv "$identity_private_dir"
    mkdir -pv "$identity_public_dir"

    local identity_passwd_file="$identity_private_dir/passwd"
    local identity_pwhash_file="$identity_public_dir/passwdhash"
   
    move_old_file "$identity_pwhash_file"
    generate_passwdfile  "$identity_passwd_file" "$identity_pwhash_file.new"
    rebuild_combined "$identity_pwhash_file"

    local identity_privkey_file="$identity_private_dir/id_ed25519"
    local identity_pubkey_file="$identity_public_dir/id_ed25519.pub"

    move_old_file "$identity_pubkey_file"
    generate_key_file "$identity_privkey_file" "$identity_pubkey_file.new" "$wsid_id"
    rebuild_combined "$identity_pubkey_file"
}

function run_identity_hooks() {
    local wsid_id="$1"
    echo "Post-rotate hooks for identity '$wsid_id'"
    local identity_passwd_hooks_dir="$WSID_PASSWD_HOOKS_DIR/$wsid_id"
    local identity_key_hooks_dir="$WSID_KEY_HOOKS_DIR/$wsid_id"
    run_hooks "$identity_passwd_hooks_dir"
    run_hooks "$identity_key_hooks_dir"
}   

function hostkey_expose() {
    local src=/etc/ssh/ssh_host_ed25519_key.pub
    local dest="$WSID_PUBLIC_DIR/ssh_host_ed25519_key.pub"
    echo "Exposing $src -> $dest"
    cut -f1,2 -d' ' < "$src" > "$dest"
} 

wsid_identities=$*

hostkey_expose | with_logger 

for wsid_identity in $wsid_identities ; do
    do_rotation "$wsid_identity" 2>&1 | with_logger 
done

echo "Sleeping {{ wsid_delay_before_update_seconds }} seconds before pushing secrets to consumers" | with_logger
sleep $WSID_DELAY_BEFORE_UPDATE_SECONDS

for wsid_identity in $wsid_identities ; do
    run_identity_hooks "$wsid_identity" 2>&1 | with_logger
done
