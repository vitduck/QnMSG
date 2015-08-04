package QnMSG; 

use strict; 
use warnings; 

use IO::File; 
use IO::Pipe; 
use Exporter qw(import); 
use File::Basename; 
use List::Util qw(sum); 

# symbol 
our @system = qw( get_user get_host get_pestat get_partition ); 
our @task   = qw( get_disk_usage scan_zombie ); 
our @output = qw( print_status print_disk_usage send_mail ); 

# default import (all) 
our @EXPORT = ( @system, @output, @task ); 
# tag import 
our %EXPORT_TAGS = ( 
    system => \@system,
    output => \@output,
    task   => \@task,
); 

##########
# SYSTEM #
##########

# get hash of user 
# arg : 
#   - none 
# return: 
#   - hash of user (home => { user => homedir })
sub get_user { 
    my %passwd; 

    my $passwd = IO::File->new('/etc/passwd', 'r') 
        or die "Cannot open /etc/passwd\n"; 

    while ( <$passwd> ) { 
        chomp; 
        if ( /\/home2?\// ) { 
            my ($user, $homedir) = (split ':')[0,5]; 
            my $home = dirname($homedir); 
            $passwd{$home}{$user} = $homedir; 
        }
    }
    $passwd->close; 
    
    return %passwd; 
}

# get local host from /etc/mail/local-host-names 
# args: 
#   - none 
# return: 
#   - hostname 
sub get_host { 
    my @hosts; 

    my $hostname = IO::File->new('/etc/mail/local-host-names', 'r') 
        or die "Cannot open /etc/mail/local-host-names\n"; 

    while ( <$hostname> ) { 
        chomp; 
        # skip the comment
        next if /^\s*#/; 
        push @hosts, $_; 
    }
    $hostname->close; 
    
    # get the first host
    return $hosts[0]; 
}

# get node status of nodes 
# args: 
#   - none 
# return: 
#   - hash ( node => status )
sub get_pestat { 
    my %pestat; 

    # pipe to pestat 
    my $pestat = IO::Pipe->new; 
    $pestat->reader('pestat');  

    while ( <$pestat> ) { 
        chomp; 
        # skip the header 
        if ( /node\s+state/ ) { next }
        # %node: ( id => status )
        my ($node_id, $node_status) = (split)[0,1]; 
        $pestat{$node_id} = $node_status; 
    }
    $pestat->close; 

    return %pestat; 
}

# get partition
# arg: 
#   - none 
# return: 
#   - hash ( partition => size )
sub get_partition { 

    # pipe to df 
    my $df = IO::Pipe->new;  
    $df->reader('df -B G'); 

    my @output = <$df>; 
    $df->close; 
    
    # remove output header 
    shift @output; 
    my %df = map { (split)[-1,1] } @output; 

    # strip the suffix G 
    my @partitions = sort keys %df; 
    @df{@partitions} = map { $1 if $df{$_} =~ /(\d+)G/ } @partitions; 

    return %df;  
}

########
# TASK #
########

# get users' disk usage 
# arg: 
#   - hash ref passwd {user => homedir}
# return: 
#   - hash of du (user => usage)
sub get_disk_usage { 
    my ($passwd) = @_; 
    my %du; 
    
    # list users in $home partition
    my @users = grep -d $passwd->{$_}, sort keys %$passwd; 

    # status line format 
    my $column  = 4; 
    my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 

    # loop through all ids and collect disk usage 
    for ( 0..$#users ) { 
        my $user    = $users[$_]; 
        my $homedir = $passwd->{$user}; 
        
        # print status line 
        print_status($_, $column, \@users, $slength); 

        # capture du output with backtick
        $du{$user}  = (split ' ', `du -sBG $homedir`)[0]
    }

    return %du; 
}

# rsh and parse the output of ps for user processes 
# args: 
#   - node_id (x0??)
#   - node_status (down* ?)
#   - filehandler
sub scan_zombie { 
    my ($node_id, $node_status, $fh) = @_; 

    print $fh "=|$node_id|=\n"; 
    
    # exit with encounter with down* node
    if ( $node_status =~ /down\*/ ) { 
        print $fh "down\n"; 
        return 1; 
    }

    # remote connect to capture output of ps
    my $ps = IO::Pipe->new; 
    $ps->reader("rsh $node_id ps --no-header axo uid,user,start,time,args"); 

    # filter out the user processes 
    my @procs = grep $_->[4] ne 'ps', grep $_->[0] > 500, map [split], <$ps>; 

    unless ( @procs ) { print $fh "free\n" }

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
                print $fh "@$proc[1..$pmi+2,-2,-1]\n";  
            # from slave to master 
            } else { 
                print $fh "@$proc[1..$pmi+2,-2,-1]\n";  
            }
        } else { 
            print $fh "@$proc[1..$#$proc]\n"; 
        }
    }

    # close pipe 
    $ps->close; 
    
    return 0;  
}

##########
# OUTPUT #
##########

# print status line during scan
# args: 
#   - current node count 
#   - number of object per row
#   - ref to list of object
#   - ref to hash of object's status (optional)
# return: 
#   - null
sub print_status { 
    my ($count, $column, $r2queue, $slength, $r2status) = @_; 

    # test if a ref to hash of status is to subroutine
    if ( ref $r2status eq ref {} ) {  
        # down* node 
        if (  $r2status->{$r2queue->[$count]} =~ /down\*/ ) { 
            printf "-> %${slength}s ", "down"; 
        # free node 
        } else { 
            printf "-> %-${slength}s ", $r2queue->[$count];  
        }
    # generic status line 
    } else { 
        printf "-> %-${slength}s ", $r2queue->[$count];  
    }

    # final element: print \newline and exit
    if ( $count == $#$r2queue ) { print "\n"; return 0 }  
    
    # list starts at 0, thus line break at $column - 1
    if ( $count % $column == $column - 1 ) { print "\n"; return 0 }

    return 0; 
}

# send mail 
# args: 
#   - ref to list of recipients
#   - title of email 
#   - hostname (kohn/sham/bloch)
# return
#   - scalar filehandler
sub send_mail { 
    my ($r2recipient, $title, $host) = @_; 

    my $sender    = $ENV{USER}; 
    my $recipient = join ',', @$r2recipient; 
    
    # file handler
    # \n must be removed from $host with chomp 
    # otherwise mail will complain about invalid \012 char
    my $mailfh = IO::Pipe->new; 

    if ( $host =~ /kohn/ ) { 
        # centos 5.x on kohn
        $mailfh->writer("mail -s '$title' '$recipient' -- -f '$sender\@$host'"); 
    } else {
        # centos 6.x on sham/bloch
        $mailfh->writer("mail -s '$title' -r '$sender\@$host' '$recipient'"); 
    }

    return $mailfh; 
}

# print users' disk usage 
# args: 
#   - hash ref du {user => usage}
#   - disk usage cut-off 
# return: 
#   - null
sub print_disk_usage { 
    my ($r2du, $capacity, $quota, $fh) = @_; 

    # list of users in $home 
    my @users = sort keys %$r2du; 

    # strip the 'G' suffix, and slice the hash ref
    @{$r2du}{@users} = map { $1 if $r2du->{$_} =~ /(\d+)G/ } @users; 

    # total disk usage 
    my $total   = sum(@{$r2du}{@users}); 

    # string & digit format for table 
    my $slength = (sort {$b <=> $a} map length($_), @users)[0]; 
    my $dlength = (sort {$b <=> $a} map length($_), @{$r2du}{@users})[0]; 
    
    # summation of total usage 
    # this is used to draw dynamic dash line 
    my $summary = sprintf "%${slength}s  %${dlength}d GB  %6.2f %%", 'total', $total, 100*$total/$capacity; 
    
    # print -----
    print $fh "-" x length($summary); 
    print $fh "\n"; 

    # table description: user -> usage -> % usage [*]
    for my $user ( sort { $r2du->{$b} <=> $r2du->{$a} } keys %$r2du ) { 
        printf $fh "%${slength}s  %${dlength}d GB  %6.2f %%", $user, $r2du->{$user}, 100*$r2du->{$user}/$capacity; 
        # print a [*] if a user uses more than cut-off 
        $r2du->{$user} >= $quota ? print $fh " [*]\n" : print $fh "\n"; 
    }

    # print -----
    print $fh "-" x length($summary); 
    
    # print summary (total usaga % usage)
    print $fh "\n$summary\n"; 

    return 0; 
}

1; 
