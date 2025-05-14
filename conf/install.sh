#!/bin/bash













if [[ $PROTOCOL == 'admiral' ]];then
    cp -f admiral/* /mnt/
fi

if [[ $PROTOCOL == 'control' ]];then
    cp -f control/* /mnt/
fi