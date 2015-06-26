package QnMSG; 

use strict; 
use warnings; 

use Exporter qw(import); 
use File::Basename; 
use List::Util qw(sum); 

# symbol 
our @user   = qw( get_users ); 
our @hdd    = qw( get_hdd print_hdd ); 
our @zombie = qw( print_status zombie_sweep ); 

# default import (all) 
our @EXPORT = ( @user, @hdd, @zombie ); 

# tag import 
our %EXPORT_TAGS = ( 
    user   => \@user,  
    hdd    => \@hdd, 
    zombie => \@zombie, 
); 

########
# USER #
########

# get hash of user 
# arg : 
#   - none 
# return: 
#   - hash of user (home => { user => homedir })
sub get_users { 
    my %passwd; 

    open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
    while ( <$passwd> ) { 
        if ( /\/home2?\// ) { 
            my ($user, $homedir) = (split ':')[0,5]; 
            my $home = (fileparse($homedir))[1]; 
            $passwd{$home}{$user} = $homedir; 
        }
    }
    close $passwd; 
    
    return %passwd; 
}

#######
# HDD #
#######

# get users' disk usage 
# arg: 
#   - hash of user
# return: 
#   - hash of disk usage (home => { user => usage })
sub get_hdd { 
    my %passwd = @_; 
    my %hdd; 
    
    for my $home ( keys %passwd ) { 
        # ref to hash of users in $home
        my $r2user = $passwd{$home}; 
        # loop through all ids and collect disk usage 
        for my $user ( keys %$r2user ) { 
            my $homedir = $r2user->{$user}; 
            # only physical user 
            next unless -d $homedir; 

            # capture du output with backtick
            my ($usage) = (split ' ', `du -sBG $homedir`)[0]; 
            $hdd{$home}{$user} = $usage; 
        }
    }

    return %hdd;  
}

# print users' disk usage 
# args: 
#   - hash of disk usage (home => { user => usage })
#   - disk usage cut-off 
# return: 
#   - null
sub print_hdd { 
    my ($r2hdd, $cutoff) = @_; 

    # list of users in $home 
    my @users      = sort keys %$r2hdd;

    # strip the 'G' suffix, and slice the hash ref
    @{$r2hdd}{@users} = map { $1 if $r2hdd->{$_} =~ /(\d+)G/ } @users; 

    # total disk usage 
    my $total   = sum(@{$r2hdd}{@users}); 

    # output format for string and digit
    my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 
    my $dlength = (sort {$b <=> $a} map length($_), @{$r2hdd}{@users})[0]; 
    
    # summation of total usage 
    # this is used to draw dynamic dash line 
    my $summary = sprintf "%${slength}s  %${dlength}d GB  %6.2f %%", 'total', $total, 100; 

    # print table
    print "-" x length($summary); 
    print "\n"; 
    for my $user ( sort { $r2hdd->{$b} <=> $r2hdd->{$a} } keys %$r2hdd ) { 
        printf "%${slength}s  %${dlength}d GB  %6.2f %%", $user, $r2hdd->{$user}, 100*$r2hdd->{$user}/$total; 
        $r2hdd->{$user} >= $cutoff ? print " [*]\n" : print "\n"; 
    }
    print "-" x length($summary); 
    
    # print summary at the end 
    print "\n$summary\n"; 

    return 0; 
}

##########
# ZOMBIE #
##########

# print status line during scan
# args: 
#   - current node count 
#   - node_id (x0??)
#   - node_status (down* ?)
# return: 
#   - null
sub print_status { 
    my ($count, $node_id, $node_status) = @_; 
    
    # mark down node and return immediately 
    if ( $node_status =~ /down\*/ ) { 
        printf "->%5s ", "down"; 
        return 1;  
    } else { 
        # 8 nodes per line 
        $count % 8 == 0 ? printf "->%5s\n", $node_id : printf "->%5s ", $node_id; 
    }

    return 0;  
}

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
