#!/usr/bin/env bash

if [[ `grep "admin.*$(echo $PAM_USER)" /etc/group` ]]
then
    exit 0
fi

if [[ `date +%u` > 5 ]]
then
    exit 1
else
    exit 0
fi