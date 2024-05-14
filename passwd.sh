#!/bin/bash
set nvm [lindex $argv 0]
spawn qm guest passwd "$nvm" root 
expect -exact "Enter new password: " 
send -- "P@ssw0rd!de\r"
expect -exact "Retype new password: "
send -- "P@ssw0rd!de\r"
sleep 1
spawn qm guest passwd "$nvm" user
expect -exact "Enter new password: "
send -- "resu!de\r"
expect -exact "Retype new password: "
send -- "resu!de\r"
expect eof
