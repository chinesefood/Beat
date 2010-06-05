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
    my $fh = new_file('case1.dat');

    print $fh ("A" x 0x10) . ("B" x 0x10) . ("A" x 0x10);

    
    $fh = new_file('case1.new.dat');

    print $fh "A" x 0x30;
}




{
    my ($fh) = new_file('case2.dat');
    
    print $fh 'A' x 0x10;
    
    
    $fh = new_file('case2.new.dat');
    
    for (my $i = 0; $i < 0x10; $i++) {
        if ($i % 2) {
            print $fh 'A';
            next;
        }
        
        print $fh 'B';
    }
}




{
    my $fh = new_file('case3.dat');
    
    print $fh 'A' x 0x10;
    
    
    $fh = new_file('case3.new.dat');
    
    print $fh 'A';
}