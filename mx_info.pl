#!/usr/bin/env perl 

use strict; 
use warnings; 

use Data::Dumper; 
use Sibyl qw/read_pestat/; 

my %node = read_pestat(); 

for my $node ( sort { $a cmp $b } keys %node ) { 
    next if $node{$node} =~ /down/; 
    next if $node =~ /x033|x034|x035/; 
    print "Node: $node\t"; 
    
    my @mx = Sibyl::read_pipe("rsh $node /opt/mx_1.2.12/bin/mx_info 2>/dev/null"); 

    for ( @mx ) { 
        if (/Mapper:.+?([^!]configured)/) { print "Status: $1\t" }
        if (/Mapper:.+?(!configured)/)    { print "Status: $1\n" }
        if (/Mapped hosts.+?(\d+)/)       { print "Mapped hosts: $1\n" }
        if (/D \d,\d/)                    { print } 
    }
    print "\n"; 
}
