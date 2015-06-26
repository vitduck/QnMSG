package QnMSG; 

use strict; 
use warnings; 
use Exporter qw(import); 

# symbol 
our @EXPORT = qw( get_users get_hdd ); 

# get hash of user 
# arg : 
#   - none 
# return: 
#   - hash of user ( user => homedir )
sub get_users { 
    open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
    my %users = map { (split ':')[0,5] } grep /\/home2?\//, <$passwd>; 
    close $passwd; 
    
    return %users;  
}

# get users' disk usage 
# arg: 
#   - hash of user
# return: 
#   - hash of disk usage ( user => disk )
sub get_hdd { 
    my %passwd = @_; 
    my %hdd; 
    for my $user ( sort keys %passwd ) { 
        my $homedir = $passwd{$user}; 
        # only physical user 
        next unless -d $homedir; 

        # capture du output with backtick
        my ($usage) = (split ' ', `du -sBG $homedir`)[0]; 
        $hdd{$user} = $usage; 
    }

    return %hdd;  
}
