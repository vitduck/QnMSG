#!/usr/bin/env perl 

use strict; 
use warnings; 

use File::Spec; 
use List::Util qw( sum ); 
use Getopt::Long; 
use Pod::Usage; 

use QnMSG qw( get_user get_host get_partition get_disk_usage :output); 

my @usages = qw( NAME SYSNOPSIS OPTIONS ); 

# POD 
=head1 NAME 

hdd.pl: disk usages of users 

=head1 SYNOPSIS

hdd.pl [-h] [-d /home /home2] [-q 500 ] [-m jangsik.lee@kaist.ac.kr]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=item B<-d>

List of partitions (default: all)

=item B<-q>

Allowed disk quota in GB (default: 1000)

=item B<-m>

List of the e-mail recipients

=back

=cut 

# default optional arguments 
my $help       = 0; 
my $quota      = 1000; 
my @partitions = ();  
my @mails      = (); 

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    'd=s{1,}' => \@partitions, 
    'q=i'     => \$quota,
    'm=s{1,}' => \@mails,
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# require root 
die "Require root previlege to preceed\n" unless $< == 0; 

# hash of passwd: (home => { user => homedir })
my %passwd = get_user(); 

# hash of df: (partition => size)
my %df = get_partition(); 

# target partitions
if ( @partitions ) { 
    # remove the trailing dashes  
    @partitions = map { File::Spec->canonpath($_) } @partitions; 
} else {  
    # scan all partitions 
    @partitions =  sort keys %passwd; 
}
    
# print disk usage from all home partition 
for my $home ( @partitions ) { 
    # check against df hash 
    unless ( exists $df{$home} ) { 
        print "$home is not a valid partition!\n"; 
        next; 
    }
    # refence to hash { user => usage } 
    my $r2user = $passwd{$home};  
    
    # hash of disk usage 
    print "\nSummarizing disk usage ...\n"; 
    my %du = get_disk_usage($r2user); 

    my $fh = @mails ? send_mail(\@mails, "Disk usage: $home", get_host()) : *STDOUT; 

    # table header
    print $fh "\n$home: $df{$home} GB\n"; 
    print_disk_usage(\%du, $df{$home}, $quota, $fh); 

    $fh->close; 
}
