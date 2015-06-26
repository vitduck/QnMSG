#!/usr/bin/env perl 

use strict; 
use warnings; 

use List::Util qw( sum ); 
use Getopt::Long; 
use Pod::Usage; 

use QnMSG qw( get_user :hdd ); 

my @usages = qw( NAME SYSNOPSIS OPTIONS ); 

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

# maximum usable storage (GB)
my $cutoff = 1000; 

# hash of passwd: (home => { user => homedir })
my %passwd = get_user(); 

# hash of df: (partition => size)
my %df = get_partition(); 

# print disk usage from all home partition 
for my $home ( sort keys %passwd ) { 
    # refence to hash { user => usage } 
    my $r2user = $passwd{$home};  
    
    # hash of disk usage 
    print "\nSummarizing disk usage ...\n"; 
    my %du = get_disk_usage($r2user); 

    # table header
    print "\n$home: $df{$home} GB\n"; 
    print_disk_usage(\%du, $df{$home}, $cutoff); 
}
