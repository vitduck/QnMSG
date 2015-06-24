#!/usr/bin/env perl 

use strict; 
use warnings; 

my $output = 'umbrella.dat'; 

# list of all users 
open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
my @users = map { (split ':')[0] } grep /\/home2?\//, <$passwd>; 
close $passwd; 

# pipe to pestat 
open my $pestat, '-|', 'pestat'; 
open my $umbrella, '>', $output or die "Cannot open $output\n"; 

# loop through node_id
my $count = 0; 
for my $line ( <$pestat> ) { 
    # skip the header
    if ( $line =~ /node\s+state/ ) { next }

    # node id (1st col) and job id (10th col)
    my ($node_id, $node_status) = (split ' ', $line)[0,1]; 

    # print status line and skip over 'down' node 
    if ( print_status(++$count, $node_id, $node_status) ) { next }

    # walking dead  
    zombie_sweep($umbrella, $node_id); 
}        

# close fh
close $pestat; 
close $umbrella; 

sub print_status { 
    my ($count, $node_id, $node_status) = @_; 
    
    # mark down node and return immediately 
    if ( $node_status =~ /down\*/ ) { 
        printf "%5s", "down"; 
        return 1;  
    } else { 
        # 8 nodes per line 
        $count % 8 == 0 ? printf "%5s\n", $node_id : printf "%5s", $node_id; 
    }

    return 0;  
}

sub zombie_sweep { 
    my ($umbrella, $node_id) = @_; 
    
    # remote connect to capture output of ps
    open my $ps, "-|", "rsh $node_id ps --no-header axo uid,user,start,time,args"; 
    print $umbrella "=>|$node_id|<=\n"; 

    # filter out the user processes 
    my @procs = grep $_->[4] ne 'ps', grep $_->[0] > 500, map [split], <$ps>; 

    # in brightest day, and darkest night 
    # no zombie will escape my sight 
    for my $proc ( @procs ) { 
        # the position of pmi_proxy process in the output field 
        my ($pmi) = grep { $proc->[$_] =~ /pmi_proxy/ } 0..$#$proc; 
        if ( $pmi ) { 
            print $umbrella "@$proc[1..3,$pmi-2..$pmi+2,-2,-1]\n";  
        } else { 
            print $umbrella  "@$proc[1..$#$proc]\n"; 
        }
    }
    print $umbrella "\n"; 

    # close pipe 
    close $ps; 
    
    return 0;  
}
