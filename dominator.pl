#!/usr/bin/env perl 

use strict; 
use warnings; 

use Data::Dumper; 
use IO::File;
use File::Basename;
use Getopt::Long; 
use Pod::Usage; 
use POSIX qw/strftime/;

use Sibyl qw/authenticate read_passwd read_pestat orphan_process send_mail/; 

my @usages = qw/NAME SYSNOPSIS OPTIONS/;  

# POD 
=head1 NAME 

dominator.pl: The Eye of the Sibyl

=head1 SYNOPSIS

dominator.pl [-h] [-n x031 x053 ... ] [-m sibyl@kaist.ac.kr]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=item B<-n>

List of the nodes to be scanned

=item B<-k> 

Remotely kill process 

=item B<-m>

E-mail of recipient

=back

=cut 

# default optional arguments 
my $help   = 0; 
my @nodes  = (); 
my $pid    = 0; 
my $mail   = ''; 

# var
my $fh     = *STDOUT;   
my $date   = strftime "%Y-%m-%d", localtime;
my $output = "scan-$date.dat"; 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    'n=s{1,}' => \@nodes, 
    'm=s'     => \$mail,
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# nodes status 
my %pestat = read_pestat();  

# user 
my %passwd = read_passwd();  

# branching filehandler
if ( @nodes == 0 ) { 
    @nodes = keys %pestat; 
    $fh = $mail ? send_mail($mail, $output) : IO::File->new($output,'w'); 
}

print "\n> Activating Dominator Portable Psychological Diagnosis and Suppression System\n"; 
print "\n> Performing Cymatic Scan\n"; 

# cymatic scan 
my %target = map { $_ => $pestat{$_} } @nodes; 
my %orphan = orphan_process(\%target, \%passwd); 

@nodes = sort @nodes; 
for my $node ( @nodes ) { 
    # preceding blank line
    if ( $node eq $nodes[0] ) { print "\n" }

    # header 
    print $fh "=|$node|=\n"; 
    
    # down node 
    if ( $orphan{$node} == 1 ) { 
        print $fh "down*\n"; 
    # free node 
    } elsif ( $orphan{$node} == 0  ) { 
        print $fh "free\n"; 
    # excl node 
    } else {  
        map { print $fh "@$_\n" } @{$orphan{$node}}; 
    }

    # trailing blank line in output
    if ( $node ne $nodes[-1] ) { print $fh "\n" }
}
