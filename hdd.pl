#!/usr/bin/env perl 

use strict; 
use warnings; 

use Data::Dumper; 
use Getopt::Long; 
use File::Spec; 
use List::Util qw/sum/;  
use Pod::Usage; 

use Sibyl qw/authenticate read_passwd read_partition disk_usage/; 

my @usages = qw/NAME SYSNOPSIS OPTIONS/; 

# POD 
=head1 NAME 

hdd.pl: summarize users' disk usage 

=head1 SYNOPSIS

hdd.pl [-h] [-d /home2] [-q 500 ]

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit

=item B<-d>

List of partitions to scan (default: /home)

=item B<-q>

Allowed disk quota in GB (default: disk_capacity/number_of_user)

=back

=cut 

# default optional arguments 
my $help       = 0; 
my $quota      = 0;  
my @partitions = ( );  

# parse optional arguments 
GetOptions( 
    'h'       => \$help, 
    'd=s{1,}' => sub { 
        my ( $opt, $arg ) = @_; 
        # remove the trailing dash 
        push @partitions, File::Spec->canonpath($arg); 
    },  
    'q=i'     => \$quota,
) or pod2usage(-verbose => 1); 

# help message 
if ( $help ) { pod2usage(-verbose => 99, -section => \@usages) }

# user authentication 
authenticate('Kougami Shinya', 'Enforcer'); 

# default partition to scan 
if ( @partitions == 0 ) { push @partitions, '/home' }

# user and homedir information  
my %passwd = read_passwd();  

# partition table 
my %df = read_partition(); 

# print disk usage from all home partition 
for my $home ( @partitions ) { 
    # sanity check
    unless ( exists $df{$home} ) { 
        print "$home is not a valid partition!\n"; 
        next; 
    }

    # w.r.t to partition 
    my %du = disk_usage($passwd{$home}); 

    # list of user and total 
    my @users = sort { $du{$b} <=> $du{$a} } keys %du; 

    # total disk usage 
    my $total = sum(@du{@users}); 
    
    # set quota = capacity/user 
    my $quota = $df{$home}/scalar(@users); 

    # format 
    my $luser   = (sort {$b <=> $a} map length($_), keys %du )[0]; 
    my $ldisk   = (sort {$b <=> $a} map length($_), values %du)[0]; 
    my $summary = sprintf "%${luser}s  %${ldisk}d GB  %6.2f %%", 'total', $total, 100*$total/$df{$home};  

    # header 
    print "\n$home: $df{$home} GB\n"; 
    printf "%s\n", "-" x length($summary); 

    for my $user ( @users ) { 
        printf "%-${luser}s  %${ldisk}d GB  %6.2f %%", $user, $du{$user}, 100*$du{$user}/$df{$home}; 
        # print a [*] if a user uses more than cut-off 
        $du{$user} >= $quota ? print " [*]\n" : print "\n"; 
    }

    printf "%s\n", "-" x length($summary); 
    print "$summary\n"; 
}
