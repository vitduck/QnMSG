package Sibyl; 

use strict; 
use warnings; 

use IO::File; 
use IO::Pipe; 
use Exporter; 
use File::Basename; 

our @scan   = qw( disk_usage cymatic_scan pkill );  
our @system = qw( authenticate read_release read_passwd read_host read_pestat read_partition );  

our @ISA         = qw( Exporter );  
our @EXPORT      = ();  
our @EXPORT_OK   = ( @system, @scan ); 
our %EXPORT_TAGS = ( 
    system => \@system,
    scan   => \@scan,
); 

our %CID = ( 
    Inspector => [ 'Ginoza Nobuchika', 'Tsunemori Akane' ], 
    Enforcer  => [ 'Kougama Shinya', 'Masaoka Tomomi', 'Kagari Shuisei', 'Kunizuka Yayoi' ],  
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
    if ( $< == 0 ) {  
        print "\n> Activating Dominator Portable Psychological Diagnosis and Suppression System\n"; 

        # flatten array ref 
        my @CID  = map @$_, values %CID;  

        # pick a user 
        my $user = $CID[int(rand(@CID))]; 

        # interface to Sibyl
        print "> User authentication: $user\n"; 
        print "> Affiliation: Public Safety Bureau, Criminal Investigation Deparment\n"; 
        print "> Dominator usage approval confirmed. You are a valid user\n"; 
    } else { 
        print "\n"; 
        die "> You are an invalid user. The trigger will be locked\n"; 
    }

    return; 
}


# read CentOS release version 
# args 
# -< file ( /etc/redhat-release )
# return 
# -> version 
sub read_release { 
    my @lines = read_file('/etc/redhat-release'); 
    my ( $version ) = ( $lines[0] =~ /(\d*\.\d*)/g ); 
    
    return $version; 
}

# read hash of user 
# args 
# -< passwrd file ( /etc/passwd )
# return
# -> hash of passwd 
sub read_passwd { 
    my %passwd = (); 
    my @ignore = qw( nfsnobody ); 
    
    for ( read_file('/etc/passwd') ) { 
        my ( $user, $uid, $homedir ) = ( split ':' )[0,2,5]; 

        # skip system user 
        if ( $uid < 500 ) { next }

        # skip pseudo-user ? 
        if ( ! -d $homedir ) { next } 

        # skip user in ignore list 
        if ( grep $user eq $_, @ignore ) { next }

        # hash: user -> homedir
        $passwd{dirname($homedir)}{$user} = $homedir;  
    }
    
    return %passwd;  
}

# get local host  
# args
# -< host file ( /etc/mail/local-host-names )
# return
# -> first hostname 
#sub read_host { 
    #my @hosts = (); 
    #for ( read_file('/etc/mail/local-host-names') ) { 
        ## skip the comment
        #if ( /^\s*#/ ) { next } 
        #push @hosts, $_; 
    #}
    
    ## return the first host
    #return $hosts[0]; 
#}

# get node tatus of nodes 
# args
# -< null
# return 
# -> hash of pestat  
sub read_pestat { 
    my %pestat = ( ); 

    # pipe to pestat 
    for ( read_pipe('pestat') ) { 
        # skip the header 
        if ( /Node\s+GN/ ) { next }
        if ( /Netload /  ) { next } 

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
#sub send_mail { 
    #my ( $recipient, $title ) = @_; 

    ## basic info
    #my $sender  = $ENV{USER}; 
    #my $host    = read_host(); 
    #my $version = read_release(); 

    ## file handler
    ## \n must be removed from $host with chomp 
    ## otherwise mail will complain about invalid \012 char
    #my $mailfh = IO::Pipe->new; 
    
    #if ( $version =~ /5\./ ) { 
        ## centos 5.x (kohn)
        #$mailfh->writer("mail -s '$title' '$recipient' -- -f '$sender\@$host'"); 
    #} else {
        ## centos 6.x (sham/bloch)
        #$mailfh->writer("mail -s '$title' -r '$sender\@$host' '$recipient'"); 
    #}

    #return $mailfh; 
#}

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
    my @bar = construct_progress_bar($passwd);  
    my $status_length = ( sort { $b <=> $a } map length($_), @bar )[0]; 

    my $count = 0;  
    my $ncol  = 4; 

    for my $user ( sort keys %$passwd ) {  
        my $homedir = $passwd->{$user}; 
        
        # status 
        print_progress_bar(\@bar, $count, $ncol, $status_length); 
        
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
sub cymatic_scan { 
    my ( $pestat, $passwd ) = @_; 
   
    # status 
    my @bar = construct_progress_bar($pestat, 'down');  
    my $status_length = ( sort { $b <=> $a } map length($_), @bar )[0]; 
    
    # user list
    my @users  = map keys %$_, values %$passwd; 

    my $count = 0; 
    my $ncol  = 4;
   
    my %orphan = ( ); 

    print "\n> Performing cymatic scan\n"; 
    
    for my $node ( sort keys %$pestat ) {  
        # status 
        print_progress_bar(\@bar, $count, $ncol, $status_length); 
       
        # read process
        my @procs = read_ps($node, $pestat->{$node}, \@users);  
       
        # free|down|excl nodes
        $orphan{$node} = ref($procs[0]) eq 'ARRAY' ? \@procs : $procs[0]; 
        
        # status update 
        $count++; 
    }

    return %orphan; 
}

# kill process remotely 
# args 
# -< PID 
# -< ref of PID array 
# return 
# -> null 
sub pkill { 
    my ( $node, $proc, $pid ) = @_; 
    
    # remote connection 
    my $host = read_host(); 
    my $ssh  = $host =~ /kohn/ ? 'rsh' : 'ssh'; 

    # free or down nodes 
    if ( $proc == 0 || $proc == 1 ) { crime_coefficient(int(rand(100))) }

    # verify process ID or excl nodes 
    my ( @targets, @kpids );  
    for my $id ( @$pid ) { 
        my ( $target ) =  grep { $id eq $_->[1] } @$proc;  
        if ( $target ) { 
            push @targets, $target; 
            push @kpids, $target->[1]; 
        }
    }
    
    # crime coefficient ? 
    @targets 
    ? crime_coefficient(int(rand(100))+300) 
    : crime_coefficient(int(rand(100))); 

    # list target  
    print "\n"; 
    my $fdash = (sort { $b <=> $a } map { length("@$_") } @targets)[0];   

    printf "%s\n", "-" x $fdash; 
    map { print "@$_\n" } @targets; 
    printf "%s\n", "-" x $fdash; 

    # user confirmation 
    print "\n"; 
    print "> Proceed: [y/n]: ";  
    chomp ( my $answer = <STDIN> );  

    # remote kill
    if ( $answer =~ /^y/i ) { 
        system "$ssh $node kill -9 @kpids";  
        if ( $?== 0 ) { print "> Done!\n" } 
    }

    return; 
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
sub construct_progress_bar { 
    my ( $data, $bad ) = @_;  

    my @bar = sort keys %$data; 

    # Insert status into item list
    if ( defined $bad ) { 
        map { $_ = $data->{$_} if $data->{$_} =~ /$bad/ } @bar;  
    }

    return @bar; 
}

# print status bar 
# args 
# -< ref of array of status
# -< count 
# -< number of column 
# -< length for format print 
# return 
# -> null
sub print_progress_bar { 
    my ( $status, $count, $ncol, $length ) = @_; 

    if ( $count % $ncol == 0 ) { 
        printf "%-${length}s", $status->[$count] 
    } else  { 
        printf " > %-${length}s", $status->[$count]; 
    }

    # trailing new line 
    if ( $count == $#$status or $count % $ncol == $ncol -1 ) { print "\n" }
    
    return; 
} 


# rsh and parse the output of ps for user processes 
# args 
# -< node 
# -< status
# -< ref of array of user
# return 
# -> array of process
sub read_ps { 
    my ( $node, $status, $passwd ) = @_; 
    
    my $ssh;  
    my @procs = (); 
    #my $host = read_host(); 
    
    # return 1 for down* node
    if ( $status =~ /down\*/ ) { return 1 } 

    # root ? 
    #if ( $< == 0 ) { 
        #$ssh = $host =~ /kohn/ ? 'rsh' : 'ssh'; 
    ## normal user
    #} else { 
        $ssh = 'ssh'; 
    #} 
    
    # remote connect to capture output of ps
    my @ps = read_pipe("$ssh $node ps --no-header aux"); 

    # filter out the user processes ( UID > 500 ) 
    for ( @ps ) { 
        my ( $user, $pid, undef, undef, undef, undef, undef, $status, $start, $time, @args ) = split;      

        # user process
        if ( ! grep $_ eq $user, @$passwd ) { next }
        
        # skip ps process 
        if ( grep $_ eq 'ps', @args ) { next }

        # strip the full path 
        @args = map { (fileparse($_))[0] } @args;  
        
        # position of pmi_proxy process in the output field 
        my ( $pmi ) = grep { $args[$_] =~ /pmi_proxy/ } 0..$#args;  

        # defunct pmi ? (rare cases)
        my ( $defunct ) = grep { $args[$_] =~ /defunct/ } 0..$#args; 

        # older MPI communcation usind mpd.py 
        # and zombie pmi_proxy 
        if ( ! defined $pmi || $defunct ) { 
            push @procs, [ $user, $pid, $start, $time, $status, @args ];  
        } else { 
            push @procs, [ $user, $pid, $start, $time, $status, @args[0..$pmi+2,-2,-1] ];  
        }
    }

    # return 0 for free nodes 
    return ( @procs ? @procs : 0 );  
}

# args
# -< target's crime coefficient 
# return 
# -> null 
sub crime_coefficient { 
    my ( $coef ) = @_; 
        
    printf "\n> Crime coefficient is %d\n", $coef;  

    if ( $coef < 100 ) { 
        die  "> Not a taget for enforcement. The trigger will be locked\n";
    } elsif ( $coef > 300 ) { 
        print "> Enforcement mode: lethal eliminator. Please aim carefully and eliminate the target.\n"; 
    } else { 
        print "> Enforcement mode: Non-Lethal Paralyzer. Please aim calmly and subdue the target.\n" 
    }

    return; 
        
}

# last evaluated expression
1; 
