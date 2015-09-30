#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper; 
use Getopt::Long; 
use File::Copy qw (copy); 
use File::Path qw (mkpath);  
use List::Util qw (shuffle); 
use Pod::Usage; 

use QnMSG   qw( get_pestat ); 

my @usages = qw( NAME SYSNOPSIS OPTIONS ); 

# POD 
=head1 NAME 
benchmark.pl: check the stability of myrinet/infiniband

=head1 SYNOPSIS

benchmark.pl -t template/TiO2 -x {1..33} -l 8 -n 10

=head1 OPTIONS

=over 8

=item B<-h>

Print the help message and exit.

=item B<-t> 

Directory containing VASP input files

=item B<-j> 

Prefix of job's name (default: 'q')

=item B<-x> 

List of nodes 

=item B<-l> 

Number of nodes per job (default: 4)

=item B<-p> 

Number of cores per node (default: 8)

=item B<-n> 

Number of randomized tests (default: 4)

=back

=cut

# default optional arguments
my $help    = 0;  
my $tempdir = '';   
my $prefix  = 'test'; 
my @xnodes  = (); 
my $batch   = 4; 
my $ppn     = 8; 
my $ntest   = 4; 

# VASP input files 
my @VASP = qw(INCAR KPOINTS POSCAR POTCAR VASP.pl); 

# parse optional arguments 
GetOptions(
    'h'       => \$help, 
    't=s'     => \$tempdir,  
    'j=s'     => \$prefix, 
    'l=i'     => \$batch,
    'x=i{1,}' => \@xnodes, 
    'p=i'     => \$ppn, 
    'n=i'     => \$ntest, 
) or pod2usage(-verbose => 1); 

# help message 
if ( $help or @xnodes == 0 ) { pod2usage(-verbose => 99, -section => \@usages) }

# sanity check 
unless ( defined $tempdir and -d $tempdir ) { die "Template directory $tempdir does not exist\n" }

# node status
my %pestat = get_pestat(); 

# lookup hash table :( 
my %xnode = map { $_ => 1 } @xnodes; 

# Schwartzian shenanigans
my @nodes = sort 
grep { $pestat{$_} ne 'down*' }
map  { $_->[0] } 
grep { exists $xnode{$_->[1]} } 
map  { [$_, sprintf('%d',$1)] if /x(\d+)/ } 
keys %pestat; 

# loop through test 
my $format = length($ntest); 
for my $test (1..$ntest) { 
    # shuffle and slice the array
    my @shuffle = (shuffle @nodes)[0..$batch*(int(@nodes/$batch))-1];  

    # top directory 
    my $topdir = 'test-'.sprintf("%0${format}d", $test); 
    print "=> $topdir\n"; 

    # generate VAPS input in batch mode 
    while ( my @batch =  splice(@shuffle, 0, $batch) ) { 
        # topdir/subdir
        my $subdir  = 'x-' . join "_", map { sprintf("%d",$1) if /x(\d+)/ } @batch; 
        
        # name of job in PBS 
        my $jobname = "$prefix-" . join "_", map { sprintf("%d",$1) if /x(\d+)/ } @batch ; 
        print "=> $jobname\n"; 
        
        # list of node in PBS
        my $lnode = join "+", map { sprintf "%s:ppn=$ppn", $_ } @batch;  

        # create top and sub directory 
        mkpath "$topdir/$subdir" or die "Cannot create directory $topdir/$subdir\n"; 

        # clone the template directory 
        map { copy "$tempdir/$_" => "$topdir/$subdir" } @VASP;   

        { # local scope for inline editing ^_^ 
            local ($^I, @ARGV) = ('~', "$topdir/$subdir/VASP.pl"); 
            while (<>) { 
                s/#PBS -l/#PBS-l nodes=$lnode/; 
                s/#PBS -N/#PBS -N $jobname/; 
                print;   
            }
        }
        # remove back-up files
        unlink "$topdir/$subdir/VASP.pl~"; 
    }
    print "\n"; 
}
