#!/usr/bin/bash 

for i in test-*         # loop over test- dir
do  
    cd $i               # cd into test- dir
    for j in x-*;       # loop over x- dir
    do 
        cd $j           # cd into test-/x- 
        qsub VASP.pl    # submit job 
        cd ..           # go back to test-
    done 
    sleep 30            # obvious 
    cd ..               # go back to current directory 
done
