#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);
use File::Temp;
use File::Copy;
use Carp;


use lib qw(..);


BEGIN {
    use_ok('Beat::V1');
}




my @methods = qw(
    read
    write
    
    make
    patch
);

can_ok('Beat::V1', @methods);








{
    my $ips = Beat::V1->new({
        'filename'  => 'data/minimal.ips',
    });

    my @records = $ips->get_all_records();
    
    is(@records, 0 , 'Minimal IPSv1 Patch Loading Test');
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = Beat::V1->new({
        'filename'  => $f->filename(),
    });
    
    is($ips->get_all_records(), 0, 'Minimal IPSv1 Writing Test 1');
}








{
    my $ips = Beat::V1->new({
        'filename'  => 'data/ipsv1_example.ips',
    });
    
    my @records = $ips->get_all_records();
    

    is(ref $records[0], 'Beat::Record::V1',     "IPSv1 Example Record");

    
    is($records[0]->get_offset(), 0,      'IPSv1 Example Record Offset');
    is($records[0]->get_size(),   4,      'IPSv1 Example Record Size');
    is($records[0]->get_data(),   'DATA', 'IPSv1 Example Record Data');
    
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = Beat::V1->new({
        'filename'  => $f->filename(),
    });
    
    @records = $ips->get_all_records();
    

    is(ref $records[0], 'Beat::Record::V1',     "IPSv1 Writing V1 Record");

    
    is($records[0]->get_offset(), 0,      'IPSv1 Writing V1 Offset');
    is($records[0]->get_size(),   4,      'IPSv1 Writing V1 Size');
    is($records[0]->get_data(),   'DATA', 'IPSv1 Writing V1 Data');
}








{
    my $ips = Beat::V1->new({
        'filename'  => 'data/ipsv1_rle_example1.ips',
    });
    
    my @records = $ips->get_all_records();
    
    
    is(ref $records[0], 'Beat::Record::RLE',    'IPSv1 RLE Example Record');
    
    
    is($records[0]->get_offset(), 0,   'IPSv1 RLE Example Record Offset');
    is($records[0]->get_size(),   16,  'IPSv1 RLE Example Record Size');
    is(
        $records[0]->get_data(), 'A' x $records[0]->get_size(),
        'IPSv1 RLE Example Record Data'
    );
    
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = Beat::V1->new({
        'filename'  => $f->filename(),
    });
    
    @records = $ips->get_all_records();
    

    is(ref $records[0], 'Beat::Record::RLE',    'IPSv1 RLE Writing Test RLE Record');
    
    
    is($records[0]->get_offset(), 0,   'IPSv1 RLE Writing Test Record Offset');
    is($records[0]->get_size(),   16,  'IPSv1 RLE Writing Test Record Size');
    is(
        $records[0]->get_data(), 'A' x $records[0]->get_size(),
        'IPSv1 RLE Writing Test Record Data'
    );
}




{
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    copy('data/case1.dat', $f->filename());
    
    my $ips = Beat::V1->new({
        'filename'  => 'data/case1.ips',
    });
    
    $ips->patch({
        'filename'  => $f->filename(),
    });
    
    seek($f, 0, SEEK_SET);
    
    is(<$f>, "A" x 0x30, "IPSv1 Patching Test");
}




{
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    copy('data/case1.dat', $f->filename());
    
    my $ips = Beat::V1->new({
        'filename'  => 'data/case1.rle.ips',
    });
    
    $ips->patch({
        'filename'  => $f->filename(),
    });
    
    seek($f, 0, SEEK_SET);
    
    is(<$f>, "A" x 0x30, "IPSv1 RLE Patching Test");
}