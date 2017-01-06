#!/usr/bin/env perl 

use strict; 
use warnings; 

use IO::File;
use File::Basename;
use Getopt::Long; 
use Pod::Usage; 
use POSIX qw( strftime );

use Sibyl qw( authenticate read_passwd read_pestat cymatic_scan pkill );  

my @usages = qw( NAME SYSNOPSIS OPTIONS );  

# POD 
=head1 NAME 

dominator.pl: The eye of the Sibyl

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
my @pids   = (); 
#my $mail   = ''; 

# var
my $fh     = *STDOUT;   
my $date   = strftime "%Y-%m-%d", localtime;
my $output = "scan-$date.dat"; 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    'n=s{1,}' => \@nodes, 
    #'m=s'     => \$mail,
    'k=i{1,}' => \@pids, 
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# nodes status 
my %pestat = read_pestat();  

# users 
my %passwd = read_passwd();  

# scanning mode
if ( @nodes == 0 ) { 
    @nodes = sort keys %pestat; 
    #$fh = $mail ? send_mail($mail, $output) : IO::File->new($output,'w'); 
    $fh = IO::File->new($output,'w'); 
} else { 
    @nodes = sort grep exists $pestat{$_}, @nodes; 
}

# cymatic scan 
my %target = map { $_ => $pestat{$_} } @nodes; 
my %orphan = cymatic_scan(\%target, \%passwd); 

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

# kill process 
if ( @pids ) { 
    if ( @nodes > 1 ) { die "\n<> -k is only applicable to single node\n" }
    # root previlege is required 
    authenticate(); 
    # remote kill process
    pkill($nodes[0], $orphan{$nodes[0]}, \@pids);  
}
