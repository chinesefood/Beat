#!/usr/bin/perl -w


use strict;
use warnings;
use diagnostics;


use Carp;
use IO::File;


use lib ('/home/james/code/megaman/code');

sub new_file {
    my ($fn) = @_;
    
    return IO::File->new(
        $fn,
        '>',
    );
}








{
    my $fh = new_file('case0.dat');
    
    print $fh '0' x 0x10;

}


{
    use File::Copy;
    
    copy 'case0.dat', 'case0.new.dat';
}




{
    my $fh = new_file('case1.dat');

    print $fh ("A" x 0x10) . ("B" x 0x10) . ("A" x 0x10);

    
    $fh = new_file('case1.new.dat');

    print $fh "A" x 0x30;
}




{
    my ($fh) = new_file('case2.dat');
    
    print $fh 'A' x 0x10;
    
    
    $fh = new_file('case2.new.dat');
    
    my $c = 'B';
    for (my $i = 0; $i < 0x10; $i++) {
        if ($i % 2) {
            print $fh 'A';
            next;
        }
        
        print $fh $c++;
    }
}




{
    my $fh = new_file('case3.dat');
    
    print $fh 'A' x 0x10;
    
    
    $fh = new_file('case3.new.dat');
    
    print $fh 'B';
}








{
    my $f1 = new_file('case4.dat');
    
    print $f1 'A' x 0x10001;
    
    
    my $f2 = new_file('case4.new.dat');
    
    print $f2 'B' x 0x10001;
}








# New file is larger than old file
{
    my $f1 = new_file('case5.dat');
    
    print $f1 'A' x 0x10000;
    
    
    my $f2 = new_file('case5.new.dat');
    
    print $f2 'B' x 0x10001;
}