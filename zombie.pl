#!/usr/bin/env perl 

use strict; 
use warnings; 

use IO::File;
use File::Basename;
use Getopt::Long; 
use Pod::Usage; 
use POSIX qw( strftime );

use QnMSG qw( get_pestat scan_zombie print_status get_host send_mail ); 

my @usages = qw(NAME SYSNOPSIS OPTIONS); 

# POD 
=head1 NAME 

zombie.pl: walking dead

=head1 SYNOPSIS

zombie.pl [-h] [-n x031 x053 ... ] [-m jangsik.lee@kaist.ac.kr]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=item B<-n>

List of the nodes to be scanned

=item B<-m>

List of the e-mail recipients

=back

=cut 

# default optional arguments 
my $help   = 0; 
my $scan   = 0; 
my @nodes  = (); 
my @mails  = (); 

# output 
my $date   = strftime "%Y-%m-%d", localtime;
my $output = "zombie-$date.dat"; 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    's'       => \$scan,
    'n=s{1,}' => \@nodes, 
    'm=s{1,}' => \@mails,
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# pipe to pestat 
my %pestat = get_pestat(); 

# In brightest day, in blackest night,
# No zombies shall esacpe my sight.  
if ( @nodes ) { 
    for my $node ( @nodes ) { 
        # skip non-existing node 
        unless ( $pestat{$node} ) { next }
        scan_zombie($node, $pestat{$node}, *STDOUT); 
    }
} else { 
    # file handler branching; 
    my $fh = @mails ? send_mail(\@mails, $output, get_host()) : IO::File->new($output,'w'); 

    # sorted node list x001 ... x064
    my @nodes = sort keys %pestat; 

    # string format 
    my $column  = 4; 
    my $slength = (sort {$b <=> $a} map length($_), @nodes)[0]; 

    print "\nScanning for zombie ...\n"; 
    for ( 0..$#nodes ) { 
        # print status line and # skip down* node 
        print_status($_, $column, \@nodes, $slength, \%pestat); 

        # scan for zombie 
        scan_zombie($nodes[$_], $pestat{$nodes[$_]}, $fh); 

        # line break 
        unless ( $_ == $#nodes ) { print $fh "\n" }
    }
    
    print "Another episode of Walking Dead: $output\n"; 

    # close fh
    $fh->close; 
}
