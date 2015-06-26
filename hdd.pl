#!/usr/bin/env perl 

use strict; 
use warnings; 

use List::Util qw(sum); 
use Getopt::Long; 
use Pod::Usage; 

use QnMSG;  

my @usages = qw(NAME SYSNOPSIS OPTIONS); 

# POD 
=head1 NAME 

hdd.pl: disk usages of users 

=head1 SYNOPSIS

hdd.pl [-h]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=back

=cut 

# default optional arguments 
my $help = 0; 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# require root 
die "Require root previlege to preceed\n" unless $< == 0; 

# threadhold (GB)
my $cutoff = 1000; 

# hash of users: (home => { user => homedir })
my %passwd = get_users(); 

# hash of hdd: (home => { user => usage })
my %hdd    = get_hdd(%passwd); 

# print disk usage from all home partition 
for my $home ( sort keys %hdd ) { 
    print "\nDisk usage in $home\n"; 
    print_hdd($hdd{$home}, $cutoff); 
}
