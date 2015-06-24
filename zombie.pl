#!/usr/bin/env perl 

use strict; 
use warnings; 
use Getopt::Long; 
use Pod::Usage; 
use POSIX qw(strftime);

my @usages = qw(NAME SYSNOPSIS OPTIONS); 

# POD 
=head1 NAME 

zombie.pl: walking dead

=head1 SYNOPSIS

zombie.pl [-h] [-n x031 x053 ]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=item B<-n>

List of the nodes to be scanned

=back

=cut 

# default optional arguments 
my $help   = 0; 
my $scan   = 0; 
my @nodes  = (); 

# output 
my $date   = strftime "%Y-%m-%d", localtime;
my $output = "zombie-$date.dat"; 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    's'       => \$scan,
    'n=s{1,}' => \@nodes, 
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# list of all users 
open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
my @users = map { (split ':')[0] } grep /\/home2?\//, <$passwd>; 
close $passwd; 

# pipe to pestat 
my %pestat; 
open my $pestat, '-|', 'pestat'; 
while ( <$pestat> ) { 
    # skip the header 
    if ( /node\s+state/ ) { next }
    # %node: ( id => status )
    my ($node_id, $node_status) = (split)[0,1]; 
    $pestat{$node_id} = $node_status; 
}
close $pestat; 

# In brightest day, in blackest night,
# No zombies shall esacpe my sight.  
if ( @nodes ) { 
    for my $node ( @nodes ) { 
        # skip non-existing node 
        unless ( $pestat{$node} ) { next }
        zombie_sweep($node, $pestat{$node}); 
    }
} else { 
    my $count; 
    open my $umbrella, '>', $output or die "Cannot open $output\n"; 
    for my $node ( sort keys %pestat ) { 
        # print status line and # skip down* node 
        if ( print_status(++$count, $node, $pestat{$node}) ) { next } 
        zombie_sweep($node, $pestat{$node}, $umbrella); 
    }
    close $umbrella; 
}

# status line 
sub print_status { 
    my ($count, $node_id, $node_status) = @_; 
    
    # mark down node and return immediately 
    if ( $node_status =~ /down\*/ ) { 
        printf "->%5s ", "down"; 
        return 1;  
    } else { 
        # 8 nodes per line 
        $count % 8 == 0 ? printf "->%5s\n", $node_id : printf "->%5s ", $node_id; 
    }

    return 0;  
}

# rsh and parse the output of ps for user processes 
sub zombie_sweep { 
    my ($node_id, $node_status, $umbrella) = @_; 

    # exit with encounter with down* node
    if ( $node_status =~ /down\*/ ) { return 1 }

    # if $umbrella is not defined, direct output to *STDOUT (glob)
    my $output = $umbrella || *STDOUT; 
    
    # remote connect to capture output of ps
    open my $ps, "-|", "rsh $node_id ps --no-header axo uid,user,start,time,args"; 
    print $output "=>|$node_id|<=\n"; 

    # filter out the user processes 
    my @procs = grep $_->[4] ne 'ps', grep $_->[0] > 500, map [split], <$ps>; 

    unless ( @procs ) { print $output "...\n" }

    # in brightest day, and darkest night 
    # no zombie will escape my sight 
    for my $proc ( @procs ) { 
        # the position of pmi_proxy process in the output field 
        my ($pmi) = grep { $proc->[$_] =~ /pmi_proxy/ } 0..$#$proc; 
        if ( $pmi ) { 
            print $output "@$proc[1..3,$pmi-2..$pmi+2,-2,-1]\n";  
        } else { 
            print $output  "@$proc[1..$#$proc]\n"; 
        }
    }
    print $output "\n"; 

    # close pipe 
    close $ps; 
    
    return 0;  
}
