#!/usr/bin/env perl 

use strict; 
use warnings; 

use List::Util qw(sum); 
use QnMSG qw( get_users get_hdd ); 
use Getopt::Long; 
use Pod::Usage; 

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

# hash of users
# ( user => homedir )
my %passwd = get_users(); 

# hash of hdd: ( user => du ) 
my %hdd    = get_hdd(%passwd); 

# total disk usage 
my @users    = sort keys %hdd; 
@hdd{@users} = map { $1 if $hdd{$_} =~ /(\d+)G/ } @users; 

# total disk usage 
my $total   = sum(@hdd{@users}); 

# output format for string and digit
my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 
my $dlength = (sort {$b <=> $a} map length($_), @hdd{@users})[0]; 

# print table; 
for my $user ( sort { $hdd{$b} <=> $hdd{$a} } keys %hdd ) { 
    printf "%${slength}s  %${dlength}d GB  %6.2f %%", $user, $hdd{$user}, 100*$hdd{$user}/$total; 
    $hdd{$user} >= $cutoff ? print " [*]\n" : print "\n"; 
}

# record break 
my $summary = sprintf "%${slength}s  %${dlength}d GB  %6.2f %%", 'total', $total, 100; 
print "-" x length($summary); 
print "\n$summary\n"; 
