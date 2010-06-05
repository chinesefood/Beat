#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);

use lib '../..';

use IPS::File;

BEGIN {
    use_ok('IPS::Diff');
}








my @methods = qw(
    generate_records
    generate_rle_records
);

can_ok('IPS::Diff', @methods);






{
    my $of = IPS::File->new({
        'read_from' => 'data/case1.dat',
    });
    
    my $nf = IPS::File->new({
        'read_from' => 'data/case1.new.dat',
    });
    
    
    my $d = IPS::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => $of,
        'new_file'  => $nf,
    });
    
    
    is(@records, 1, "Case 1:  Record Number Test");
    
    my $r = $records[0];
    
    is($r->get_offset(), 0x16,       "Case 1:  Corect Offset");
    is($r->get_data(),   'B' x 0x16, "Case 1:  Correct Data");
}
    