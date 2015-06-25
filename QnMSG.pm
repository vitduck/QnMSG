package QnMSG; 

use strict; 
use warnings; 
use Exporter qw(import); 

# symbol 
our @EXPORT = qw( get_users ); 

#########
# USERS #
#########
sub get_users { 
    open my $passwd, '<', '/etc/passwd' or die "Cannot open /etc/passwd\n"; 
    my %users = map { (split ':')[0,5] } grep /\/home2?\//, <$passwd>; 
    close $passwd; 
    
    return %users;  
}
