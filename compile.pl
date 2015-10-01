#!/usr/bin/env perl 

use strict;  
use warnings; 

use File::Copy qw (copy); 
use Data::Dumper; 

# etc
my $template = 'Makefile.template'; 
my $openblas = "$ENV{HOME}/build/lib";  

# mirco-architecture based 
my %intel = ( 
    penryn  => { 
        flag   => "-xSSE4.1", 
        single => "$openblas/libopenblas_penryn-r0.2.14.a", 
        multi  => "$openblas/libopenblas_penrynp-r0.2.14.a", 
    }, 
    nehalem => { 
        flag   => "-xSSE4.2", 
        single => "$openblas/libopenblas_nehalem-r0.2.14.a", 
        multi  => "$openblas/libopenblas_nehalemp-r0.2.14.a", 
    }, 
); 

# compilation
for my $arch ( keys %intel ) { 
    for my $thread qw( single multi ) {  
        # complex 
        my $binary = "vasp4.openblas.$arch.$thread.x"; 
        
        # use a copy template Makefile 
        copy $template => 'Makefile'; 

        # blas library 
        blas_make($arch, $thread); 

        # compilation 
        compile_vasp($binary); 

        # switch to gamma 
        my $gamma = "vasp4.openblas.$arch.$thread.gamma.x"; 
        gamma_version(); 
        compile_vasp($gamma); 
    } 
}

#----------# 
# MAKEFILE #
#----------# 
sub compile_vasp { 
    my ($binary) = @_; 
     
    system 'make clean'; 
    system 'make'; 

    # rename vasp binary
    copy 'vasp' => $binary; 
    chmod 0755, $binary; 

    return; 
}

sub gamma_version { 
    # inline editing Makefile 

    { # local scope for inline editing ^_^ 
            local ($^I, @ARGV) = ('~', 'Makefile'); 
            while (<>) { 
                s/#-DwNGZhalf/-DwNGZhalf/; 
                print;   
            }
    }
    # remove back-up files
    unlink 'Makefile~'; 

    return; 
} 

sub blas_make { 
    my ($arch, $thread) = @_; 
    # inline editing Makefile 

    { # local scope for inline editing ^_^ 
            local ($^I, @ARGV) = ('~', 'Makefile'); 
            while (<>) { 
                s/^(OFLAG = -O3)$/$1 $intel{$arch}{flag}/; 
                s/^BLAS =/BLAS = $intel{$arch}{$thread}/; 
                print;   
            }
    }
    # remove back-up files
    unlink 'Makefile~'; 

    return; 
}
