#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);

use lib '..';

use Beat::File;

BEGIN {
    use_ok('Beat::Diff');
}








my @methods = qw(
    generate_records
);

can_ok('Beat::Diff', @methods);






{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case0.dat',
        'new_file'  => 'data/case0.new.dat',
    });
    
    
    is(@records, 0, "Case 0:  Identical Files");
}








{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case1.dat',
        'new_file'  => 'data/case1.new.dat',
    });
    
    is(@records, 1, "Case 1:  One Delta");
    
    my $r = shift @records;
    
    is $r->get_offset(), 0x10,       "Case 1:  Record Offset Test";
    is $r->get_data(),   'A' x 0x10, "Case 1:  Data Test";
}








{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case2.dat',
        'new_file'  => 'data/case2.new.dat',
    });
    
    is @records, 8, 'Case 2:  Alternating Bytes';
    
    my $c = 'B';
    for (1..8) {
        my $r = $records[$_ - 1];
        
        is $r->get_data,   $c++,         "Case 2:  Record $_ Data Test";
        is $r->get_offset, ($_ - 1) * 2, "Case 2:  Record $_ Offset Test";
    }
}









{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case3.dat',
        'new_file'  => 'data/case3.new.dat',
    });
    
    
    is @records, 2, 'Case 3:  Truncation';
    
    is ref $records[0], 'Beat::Record::V1', 'Case 3:  V1 Record Creation Test';
    
    is $records[0]->get_offset(), 0,   'Case 3:  V1 Record Offset Test';
    is $records[0]->get_data(),   'B', 'Case 3:  V1 Record Data Test';
    
    
    is ref $records[1], 'Beat::Record::V2', 'Case 3:  V2 Record Creation Test';
}








{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case4.dat',
        'new_file'  => 'data/case4.new.dat',
    });
    
    
    is @records, 2, 'Case 4:  Deltas Larger Than 2^16';
 
}








# New file is larger than old file
{
    my $d = Beat::Diff->new();
    
    my @records = $d->generate_records({
        'old_file'  => 'data/case5.dat',
        'new_file'  => 'data/case5.new.dat',
    });
    
    
    is @records, 2, 'Case 5: New File Larger than Old File';
}