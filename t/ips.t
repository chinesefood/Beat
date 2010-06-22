#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);


use lib '..';

use Beat::Record::EOF;
use Beat::Record::Header;

use File::Temp;
use File::Copy;
use File::Compare;

BEGIN {
    use_ok('Beat');
}


my @methods = qw(
    get_filename
    set_filename
    
    get_all_records
    set_all_records
    
    get_record
    set_record
    
    push_record
    pop_record
    shift_record
    unshift_record
    
    make
    patch
);

can_ok('Beat', @methods);



{
    my $ips = new_ok('Beat'  => []);
    
    my $e = Beat::Record::EOF->new();
    my $h = Beat::Record::Header->new();
    
    
    $ips->push_record($e);
    $ips->push_record($h);
    
    is($ips->pop_record(), $h, "Push/Pop Record Test 1");
    is($ips->pop_record(), $e, "Push/Pop Record Test 2");
    
    
    $ips->unshift_record($e);
    $ips->unshift_record($h);
    
    is($ips->shift_record(), $h, "Unshift/Shift Record Test 1");
    is($ips->shift_record(), $e, "Unshift/Shift Record Test 2");
    
    
    $ips->set_record({
        0   => $h,
        1   => $e,
    });
    
    is($ips->get_record(0), $h, "Get/Set Record Test 1");
    is($ips->get_record(1), $e, "Get/Set Record Test 2");
    
    is($ips->get_all_records(), 2, "Get All Records Test");
    
    
    my $records_ref = [$e, $h];
    
    $ips->set_all_records($records_ref);
    
    is($ips->get_record(0), $e, "Set All Records Test 1");
    is($ips->get_record(1), $h, "Set All Records Test 2");
    
    
    $ips->set_filename('ips.ips');
    
    is($ips->get_filename(), 'ips.ips', "Get/Set Filename Test");
}




{
    isa_ok(
        Beat->new({'filename' => 'data/minimal.ips',}),
        'Beat::V1'
    );
    
    isa_ok(
        Beat->new({'filename' => 'data/minimal_v2.ips',}),
        'Beat::V2'
    );
}




{
    my $ips = Beat->new({
        'filename'  => 'data/eof_test.ips',
    });
    
    isa_ok($ips, 'Beat::V2');
    
    my $eof = hex unpack("H*", pack("A*", 'EOF'));
    my $r = $ips->get_record(1);
    
    is($r->get_offset(), $eof,  "Offset is 'EOF'");
    is($r->get_data(),   'EOF', "Data is 'EOF'");
    
    is($ips->get_truncation_offset(), $eof, "Truncation offset is 'EOF'");
}




{
    my $ips = Beat->new({
        'filename'  => 'data/all_record_types.ips',
    });
    
    my ($h, $v1, $rle, $eof, $v2) = $ips->get_all_records();
    
    is(ref($h),   'Beat::Record::Header', "All Record Types Header Test");
    is(ref($v1),  'Beat::Record::V1',     "All Record Types Record V1 Test");
    is(ref($rle), 'Beat::Record::RLE',    "All Record Types Record RLE Test");
    is(ref($eof), 'Beat::Record::EOF',    "All Record Types Record EOF Test");
    is(ref($v2),  'Beat::Record::V2',     "All Record Types Record V2 Test");
}




{
    my $ips = Beat->new();
    
    $ips->make({
        'old_file'  => 'data/case1.dat',
        'new_file'  => 'data/case1.new.dat',
    });
    
    my $tmp = File::Temp->new(UNLINK => 1);
    
    copy 'data/case1.dat', $tmp->filename();
    
    $ips->patch({
        'filename'  => $tmp->filename(),
    });
    
    ok !compare('data/case1.new.dat', $tmp->filename()), 'Case 1:  Patching';
}




{
    my $ips = Beat->new({
        'old_file'  => 'data/case2.dat',
        'new_file'  => 'data/case2.new.dat'
    });
    
    
    my $tmp = File::Temp->new(UNLINK => 1);
    
    copy 'data/case2.dat', $tmp->filename();
    
    $ips->patch({
        'filename'  => $tmp->filename(),
    });
    
    ok !compare('data/case2.new.dat', $tmp->filename()), 'Case 2:  Patching';
}




{
    my $ips = Beat->new({
        'old_file'  => 'data/case3.dat',
        'new_file'  => 'data/case3.new.dat',
    });
    
    my $tmp = File::Temp->new(UNLINK => 1);
    
    copy 'data/case3.dat', $tmp->filename();
    
    $ips->patch({
        'filename'  => $tmp->filename(),
    });
    
    ok !compare('data/case3.new.dat', $tmp->filename()), 'Case 3:  Patching';
}






{
    my $ips = Beat->new({
        'old_file'  => 'data/case4.dat',
        'new_file'  => 'data/case4.new.dat',
    });
    
    my $tmp = File::Temp->new(UNLINK => 1);
    
    copy 'data/case4.dat', $tmp->filename();
    
    $ips->patch({
        'filename'  => $tmp->filename(),
    });
    
    ok !compare('data/case4.new.dat', $tmp->filename()), 'Case 4:  Patching';
}







{
    my $ips = Beat->new({
        'old_file'  => 'data/case5.dat',
        'new_file'  => 'data/case5.new.dat',
    });
    
    my $tmp = File::Temp->new(UNLINK => 1);
    
    copy 'data/case5.dat', $tmp->filename();
    
    $ips->patch({
        'filename'  => $tmp->filename(),
    });
    
    ok !compare('data/case5.new.dat', $tmp->filename()), 'Case 5:  Patching';
}