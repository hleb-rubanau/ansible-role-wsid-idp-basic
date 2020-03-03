#!/bin/bash
    
cat /etc/ssh/ssh_host_ed25519_key.pub | cut -f1,2 -d' ' > {{ wsid_var_run }}/public/ssh_host_ed25519_key.pub
