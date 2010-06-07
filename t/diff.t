#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);

use lib '../..';

use Beat::File;

BEGIN {
    use_ok('Beat::Diff');
}








my @methods = qw(
    generate_records
    generate_rle_records
);

can_ok('Beat::Diff', @methods);






{
    my $of = Beat::File->new({
        'read_from' => 'data/case1.dat',
    });
    
    my $nf = Beat::File->new({
        'read_from' => 'data/case1.new.dat',
    });
    
    
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => $of,
        'new_file'  => $nf,
    });
    
    
    is(@records, 1, "Case 1:  Record Number Test");
    
    my $r = $records[0];
    
    is($r->get_offset(), 0x16,       "Case 1:  Corect Offset");
    is($r->get_data(),   'B' x 0x16, "Case 1:  Correct Data");
}
    