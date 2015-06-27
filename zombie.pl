#!/usr/bin/env perl 

use strict; 
use warnings; 

use File::Basename;
use Getopt::Long; 
use Pod::Usage; 
use POSIX qw( strftime );

use QnMSG qw( print_status zombie_scan ); 

my @usages = qw(NAME SYSNOPSIS OPTIONS); 

# POD 
=head1 NAME 

zombie.pl: walking dead

=head1 SYNOPSIS

zombie.pl [-h] [-n x031 x053 ... ]

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
        zombie_scan($node, $pestat{$node}); 
    }
} else { 
    print "Scanning for zombie ...\n"; 
    open my $fh, '>', $output or die "Cannot open $output\n"; 

    # sorted node list x001 ... x064
    my @nodes   = sort keys %pestat; 

    # string format 
    my $column  = 4; 
    my $slength = (sort {$b <=> $a} map length($_), @nodes)[0]; 

    for ( 0..$#nodes ) { 
        # print status line and # skip down* node 
        if ( print_status($_, $column, \@nodes, $slength, \%pestat) ) { next } 

        # scan for zombie 
        zombie_scan($nodes[$_], $pestat{$nodes[$_]}, $fh); 
    }
    close $fh; 
    
    print "Another episode of Walking Dead: $output\n"; 
}
