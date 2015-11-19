package Sibyl; 

use strict; 
use warnings; 

use IO::File; 
use IO::Pipe; 
use Exporter; 
use File::Basename; 

our @scan   = qw/disk_usage orphan_process/; 
our @system = qw/authenticate read_release read_passwd read_host read_pestat read_partition send_mail/; 

our @ISA         = qw/Exporter/; 
our @EXPORT      = ( );  
our @EXPORT_OK   = ( @system, @scan ); 
our %EXPORT_TAGS = ( 
    system => \@system,
    scan   => \@scan,
); 

#--------#
# SYSTEM #
#--------#

# authenticate user 
# args 
# -< null 
# return 
# -> null 
sub authenticate { 
    my ( $user, $occupation ) = @_; 
    print "\n"; 
    if ( $< == 0 ) {  
        print "> User authentication: $user ($occupation)\n"; 
        print "> Affiliation: Public Safety Bureau, Criminal Investigation Deparment\n"; 
        print "> You are a valid user\n\n"; 
    } else { 
        die "> You are an invalid user\n"; 
    }
}

# read CentOS release version 
# args 
# -< file ( /etc/redhat-release )
# return 
# -> version 
sub read_release { 
    my ( $file ) = @_; 
    $file = defined $file ? $file : '/etc/redhat-release'; 
    
    my @lines = read_file($file); 
    my ( $version ) = ( $lines[0] =~ /(\d*\.\d*)/g ); 
    
    return $version; 
}

# read hash of user 
# args 
# -< passwrd file ( /etc/passwd )
# return
# -> hash of passwd 
sub read_passwd { 
    my ( $file ) = @_;  
    $file = defined $file ? $file : '/etc/passwd';  

    my %passwd = ( ); 
    
    for ( read_file($file) ) { 
        if ( /\/home\d?\// ) { 
            my ( $user, $homedir ) = ( split ':' )[0,5]; 
            my $home = dirname($homedir); 
            if ( -d $homedir ) { $passwd{$home}{$user} = $homedir } 
        }
    }
    
    return %passwd;  
}

# get local host  
# args
# -< host file ( /etc/mail/local-host-names )
# return
# -> first hostname 
sub read_host { 
    my ( $file ) = @_; 
    $file = defined $file ? $file : '/etc/mail/local-host-names'; 

    my @hosts = ( ); 
    for ( read_file($file) ) { 
        # skip the comment
        if ( /^\s*#/ ) { next } 
        push @hosts, $_; 
    }
    
    # return the first host
    return $hosts[0]; 
}

# get node status of nodes 
# args
# -< null
# return 
# -> hash of pestat  
sub read_pestat { 
    my %pestat = ( ); 

    # pipe to pestat 
    for ( read_pipe('pestat') ) { 
        # skip the header 
        if ( /node\s+state/ ) { next }

        # %node: ( id => status )
        my ( $node_id, $node_status ) = ( split )[0,1]; 
        $pestat{$node_id} = $node_status; 
    }

    return %pestat;  
}

# read partition
# args 
# -< null
# return
# -> partition hash
sub read_partition { 
    # pipe to df 
    my @lines = read_pipe('df -B G'); 
    
    # remove df's output header 
    shift @lines;  
    
    # construct hash 
    my %partition = map { ( split )[-1,1] } @lines; 

    # strip the suffix G
    map { s/G$// } values %partition; 

    return %partition; 
}

# send mail 
# args 
# -< recipient
# -< title of email 
# return
# -> mail filehandler
sub send_mail { 
    my ( $recipient, $title ) = @_; 

    my $sender    = $ENV{USER}; 
    
    # file handler
    # \n must be removed from $host with chomp 
    # otherwise mail will complain about invalid \012 char
    my $host = read_host(); 
    my $mailfh = IO::Pipe->new; 
    if ( read_host() =~ /kohn/ ) { 
        # centos 5.x on kohn
        $mailfh->writer("mail -s '$title' '$recipient' -- -f '$sender\@$host'"); 
    } else {
        # centos 6.x on sham/bloch
        $mailfh->writer("mail -s '$title' -r '$sender\@$host' '$recipient'"); 
    }

    return $mailfh; 
}

#------#
# SCAN #
#------#

# get users' disk usage 
# args
# -< hash ref of passwd 
# return
# -> hash of du 
sub disk_usage { 
    my ( $passwd ) = @_; 

    my %du = ( ); 

    # status 
    my @status = construct_status_bar($passwd);  
    my $status_length = ( sort { $b <=> $a } map length($_), @status )[0]; 

    my $count = 0;  
    my $ncol  = 4; 

    for my $user ( sort keys %$passwd ) {  
        my $homedir = $passwd->{$user}; 
        
        # status 
        print_status_bar(\@status, $count, $ncol, $status_length); 
        
        # capture du output with backtick, remove the G suffix 
        $du{$user} = (split ' ', `du -sBG $homedir`)[0]; 
        $du{$user} =~ s/G$//;  

        # status update 
        $count++; 
    }

    return %du;  
}

# get users' process 
# args 
# -< hash of pestat 
# return 
# -> hash of process 
sub orphan_process { 
    my ( $pestat ) = @_; 
   
    # status 
    my @status = construct_status_bar($pestat, 'down');  
    my $status_length = ( sort { $b <=> $a } map length($_), @status )[0]; 

    my $count = 0; 
    my $ncol  = 4;
   
    my %orphan = ( ); 
    for my $node ( sort keys %$pestat ) {  
        # status 
        print_status_bar(\@status, $count, $ncol, $status_length); 
       
        # read process
        my @procs = read_ps($node, $pestat->{$node});  

        if ( ref($procs[0]) eq 'ARRAY' ) { 
            push @{$orphan{$node}}, \@procs; 
        } else { 
            $orphan{$node} = $procs[0]; 
        } 
        
        # status update 
        $count++; 
    }

    return %orphan; 
}

#-----------# 
# AUXILIARY #
#-----------# 

# read file
# args
# -< file 
# return
# -> array of lines 
sub read_file { 
    my ( $file ) = @_; 

    my @lines = ( );  
    
    my $fh = IO::File->new($file => 'r') or die "Cannot open $file\n"; 
    chomp ( @lines = <$fh> ); 
    $fh->close;  
    
    return @lines;  
}

# read pipe 
# args 
# -< command 
# return 
# -> array of lines  
sub read_pipe { 
    my ( $command ) = @_; 

    my @lines = ( );  

    my $pipe = IO::Pipe->new; 
    $pipe->reader($command) or die "Cannot pipe from $command\n";  
    chomp ( @lines = <$pipe> ); 
    $pipe->close; 

    return @lines;  
}

# construct status bar  
# args 
# -< ref of data
# -< bad status 
# return 
# -> array of status
sub construct_status_bar { 
    my ( $data, $bad ) = @_;  

    my @status = sort keys %$data; 

    # Insert status into item list
    if ( defined $bad ) { 
        map { $_ = $data->{$_} if $data->{$_} =~ /$bad/ } @status;  
    }

    return @status;  
}

# print status bar 
# args 
# -< ref of array of status
# -< count 
# -< number of column 
# -< length for format print 
# return 
# -> null
sub print_status_bar { 
    my ( $status, $count, $ncol, $length ) = @_; 

    # first 
    if ( $count % $ncol == 0 ) { 
        printf "%-${length}s", $status->[$count];  
        # only single item ? 
        if ( @$status == 1 ) { print "\n" }
    # end of line or final 
    } elsif ( $count % $ncol == $ncol -1 || $count == $#$status ) { 
        printf " -> %-${length}s\n", $status->[$count]; 
    # the rest
    } else { 
        printf " -> %-${length}s", $status->[$count]; 
    }

    return; 
} 

# rsh and parse the output of ps for user processes 
# args 
# -< node 
# -< status
# return 
# -> array of process
sub read_ps { 
    my ( $node, $status ) = @_; 

    my @procs = ( ); 

    # return 1 for down* node
    if ( $status =~ /down\*/ ) { return 1 } 

    # remote connect to capture output of ps
    my @ps = read_pipe("rsh $node ps --no-header axo uid,user,start,time,pid,args"); 
    
    # filter out the user processes ( UID > 500 ) 
    for ( @ps ) { 
        my ( $uid, $user, $start, $time, $pid, @args ) = split;      

        # user process ( UID > 500 )
        if ( $uid <= 500 ) { next }
        
        # skip ps process 
        if ( grep $_ eq 'ps', @args ) { next }

        # strip the full path 
        @args = map { (fileparse($_))[0] } @args;  
        
        # position of pmi_proxy process in the output field 
        my ( $pmi ) = grep { $args[$_] =~ /pmi_proxy/ } 0..$#args;  

        if ( ! defined $pmi ) { 
            push @procs, [ $user, $start, $time, $pid, @args ];  
        } else { 
            push @procs, [ $user, $start, $time, $pid, @args[0..$pmi+2,-2,-1] ];  
        }
    }
   
    # return 0 for free nodes 
    return ( @procs ? @procs : 0 );  
}

# last evaluated expression
1; 
