#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More 'no_plan';
use File::Temp;

use lib qw(
    ..
);


BEGIN {
    use_ok('Beat::File');
}


my @methods = qw(
    read
    write
    
    seek
    tell
    
    get_size
    get_line
);

can_ok('Beat::File', @methods);








{
    new_ok('Beat::File');
}








{
    my $f = Beat::File->new({
        'read_from' => 'data/case1.dat',
    });
    
    my $test_data = 'A' x 0x10 . 'B' x 0x10 . 'A' x 0x10;
    
    is($f->get_line(), $test_data, 'Instantiation with read_from argument');
}








{
    my $f = Beat::File->new({
        'write_to' => File::Temp->new(UNLINK => 1)->filename(),
    });
    
    
    $f->write('AAAA');
    
    $f->seek(0);
    
    is($f->get_line(), 'AAAA', 'Instantiation with write_to argument');
}
