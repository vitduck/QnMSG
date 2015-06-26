package QnMSG; 

use strict; 
use warnings; 

use Exporter qw(import); 
use File::Basename; 
use List::Util qw(sum); 

# symbol 
our @user   = qw( get_user ); 
our @hdd    = qw( get_partition get_disk_usage print_disk_usage ); 
our @zombie = qw( zombie_sweep ); 
our @status = qw( print_status ); 

# default import (all) 
our @EXPORT = ( @user, @hdd, @zombie, @status ); 

# tag import 
our %EXPORT_TAGS = ( 
    user   => \@user,  
    hdd    => \@hdd, 
    zombie => \@zombie, 
    status => \@status, 
); 

########
# USER #
########

# get hash of user 
# arg : 
#   - none 
# return: 
#   - hash of user (home => { user => homedir })
sub get_user { 
    my %passwd; 

    open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
    while ( <$passwd> ) { 
        if ( /\/home2?\// ) { 
            my ($user, $homedir) = (split ':')[0,5]; 
            my $home = dirname($homedir); 
            $passwd{$home}{$user} = $homedir; 
        }
    }
    close $passwd; 
    
    return %passwd; 
}

#######
# HDD #
#######

# get partition
# arg: 
#   - none 
# return: 
#   - hash ( partition => size )
sub get_partition { 
    # pipe to df 
    open DF, '-|', 'df -B G' or die "Cannot open pipe to df\n"; 
    my @output = <DF>; 
    close DF; 
    
    # remove output header 
    shift @output; 
    my %df = map { (split)[-1,1] } @output; 

    # strip the suffix G 
    my @partitions = sort keys %df; 
    @df{@partitions} = map { $1 if $df{$_} =~ /(\d+)G/ } @partitions; 

    return %df;  
}

# get users' disk usage 
# arg: 
#   - hash of user
# return: 
#   - hash of disk usage (home => { user => usage })
sub get_disk_usage { 
    my %passwd = @_; 
    my %du; 
    
    my $count  = 0; 
    my $column = 4; 

    for my $home ( keys %passwd ) { 
        # ref to hash of users in $home
        my $r2user = $passwd{$home}; 

        # list users in $home partition
        my @users = keys %$r2user; 

        # string format for status line 
        my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 

        # loop through all ids and collect disk usage 
        for my $user ( @users ) { 
            my $homedir = $r2user->{$user}; 
            # only physical user 
            next unless -d $homedir; 

            # print status line 
            print_status(++$count, $column, $user, $slength); 
            
            # line break for last user
            if ( $user eq $users[-1] && $count % $column != 0 ) { print "\n" };

            # capture du output with backtick
            my ($usage) = (split ' ', `du -sBG $homedir`)[0]; 
            $du{$home}{$user} = $usage; 
        }
    }

    return %du; 
}

# print users' disk usage 
# args: 
#   - hash of disk usage (home => { user => usage })
#   - disk usage cut-off 
# return: 
#   - null
sub print_disk_usage { 
    my ($r2hdd, $capacity, $cutoff) = @_; 

    # list of users in $home 
    my @users = sort keys %$r2hdd;

    # strip the 'G' suffix, and slice the hash ref
    @{$r2hdd}{@users} = map { $1 if $r2hdd->{$_} =~ /(\d+)G/ } @users; 

    # total disk usage 
    my $total   = sum(@{$r2hdd}{@users}); 

    # string & digit format for table 
    my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 
    my $dlength = (sort {$b <=> $a} map length($_), @{$r2hdd}{@users})[0]; 
    
    # summation of total usage 
    # this is used to draw dynamic dash line 
    my $summary = sprintf "%${slength}s  %${dlength}d GB  %6.2f %%", 'total', $total, 100*$total/$capacity; 

    # print -----
    print "-" x length($summary); print "\n"; 

    # table description: user -> usage -> % usage [*]
    for my $user ( sort { $r2hdd->{$b} <=> $r2hdd->{$a} } keys %$r2hdd ) { 
        printf "%${slength}s  %${dlength}d GB  %6.2f %%", $user, $r2hdd->{$user}, 100*$r2hdd->{$user}/$capacity; 
        # print a [*] if a user uses more than cut-off 
        $r2hdd->{$user} >= $cutoff ? print " [*]\n" : print "\n"; 
    }

    # print -----
    print "-" x length($summary); 
    
    # print summary (total usaga % usage)
    print "\n$summary\n"; 

    return 0; 
}

##########
# ZOMBIE #
##########

# rsh and parse the output of ps for user processes 
# args: 
#   - node_id (x0??)
#   - node_status (down* ?)
#   - filehandler
sub zombie_sweep { 
    my ($node_id, $node_status, $fh) = @_; 

    # exit with encounter with down* node
    if ( $node_status =~ /down\*/ ) { return 1 }

    # if $fh is not defined, direct output to *STDOUT (type glob)
    my $output = $fh || *STDOUT; 
    
    # remote connect to capture output of ps
    open my $ps, "-|", "rsh $node_id ps --no-header axo uid,user,start,time,args"; 
    print $output "=|$node_id|=\n"; 

    # filter out the user processes 
    my @procs = grep $_->[4] ne 'ps', grep $_->[0] > 500, map [split], <$ps>; 

    unless ( @procs ) { print $output "...\n" }

    # in brightest day, and darkest night 
    # no zombie will escape my sight 
    for my $proc ( @procs ) { 
        # parse file full path for filename only
        @$proc = map { (fileparse($_))[0] } @$proc; 
        if ( grep { $_ eq 'ps' } @$proc ) { next }

        # the position of pmi_proxy process in the output field 
        my ($pmi) = grep { $proc->[$_] =~ /pmi_proxy/ } 0..$#$proc; 
        
        if ( $pmi ) { 
            # from master to slave 
            if ( $proc->[4] eq 'rsh' ) {
                print $output "@$proc[1..$pmi+2,-2,-1]\n";  
            # from slave to master 
            } else { 
                print $output "@$proc[1..$pmi+2,-2,-1]\n";  
            }
        } else { 
            print $output  "@$proc[1..$#$proc]\n"; 
        }
    }
    print $output "\n"; 

    # close pipe 
    close $ps; 
    
    return 0;  
}

##########
# STATUS #
##########

# print status line during scan
# args: 
#   - current node count 
#   - node_id (x0??|user)
#   - node_status (down* ?)
# return: 
#   - null
sub print_status { 
    my ($count, $column, $process, $slength) = @_; 

    # addition status (down* or null)
    my $status = shift @_ || ''; 
    
    # mark down node and return immediately 
    if ( $status =~ /down\*/ ) { 
        printf "->% ${slength}s ", "down"; 
        return 1;  
    } else { 
        # generic counting status
        $count % $column == 0 ? printf "-> %${slength}s\n", $process : printf "-> %${slength}s ", $process; 
    }

    return 0;  
}

1; 
