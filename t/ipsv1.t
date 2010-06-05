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
    use_ok('IPS::V1');
}




my @methods = qw(
    read
    write
    
    make
    patch
);

can_ok('IPS::V1', @methods);








{
    my $ips = IPS::V1->new({
        'filename'  => 'data/minimal.ips',
    });

    my ($header, $eof) = $ips->get_record(0, 1);
    
    is(ref $header, 'IPS::Record::Header', 'Minimal IPS Patch Test 1');
    is(ref $eof,    'IPS::Record::EOF',    'Minimal IPS Patch Test 2');
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = IPS::V1->new({
        'filename'  => $f->filename(),
    });
    
    is(ref $ips->get_record(0), 'IPS::Record::Header', 'Minimal IPS Writing Test 1');
    is(ref $ips->get_record(1), 'IPS::Record::EOF',    'Minimal IPS Writing Test 2');
}








{
    my $ips = IPS::V1->new({
        'filename'  => 'data/ipsv1_example.ips',
    });
    
    my @records = $ips->get_all_records();
    
    is(ref $records[0], 'IPS::Record::Header', "IPSv1 Example Header");
    is(ref $records[1], 'IPS::Record::V1',     "IPSv1 Example Record");

    
    is($records[1]->get_offset(), 0,      'IPSv1 Example Record Offset');
    is($records[1]->get_size(),   4,      'IPSv1 Example Record Size');
    is($records[1]->get_data(),   'DATA', 'IPSv1 Example Record Data');
    
    
    is(ref $records[2], 'IPS::Record::EOF', 'IPSv1 Example EOF');
    
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = IPS::V1->new({
        'filename'  => $f->filename(),
    });
    
    @records = $ips->get_all_records();
    
    is(ref $records[0], 'IPS::Record::Header', "IPSv1 Writing Header");
    is(ref $records[1], 'IPS::Record::V1',     "IPSv1 Writing V1 Record");

    
    is($records[1]->get_offset(), 0,      'IPSv1 Writing V1 Offset');
    is($records[1]->get_size(),   4,      'IPSv1 Writing V1 Size');
    is($records[1]->get_data(),   'DATA', 'IPSv1 Writing V1 Data');
    
    
    is(ref $records[2], 'IPS::Record::EOF', 'IPSv1 Writing Test EOF');
}








{
    my $ips = IPS::V1->new({
        'filename'  => 'data/ipsv1_rle_example1.ips',
    });
    
    my @records = $ips->get_all_records();
    
    is(ref $records[0], 'IPS::Record::Header', 'IPSv1 RLE Example Header');
    is(ref $records[1], 'IPS::Record::RLE',    'IPSv1 RLE Example Record');
    
    
    is($records[1]->get_offset(), 0,   'IPSv1 RLE Example Record Offset');
    is($records[1]->get_size(),   16,  'IPSv1 RLE Example Record Size');
    is(
        $records[1]->get_data(),
        $records[1]->get_data_byte() x $records[1]->get_size(),
        'IPSv1 RLE Example Record Data'
    );
    
    
    is(ref $records[2], 'IPS::Record::EOF', 'IPSv1 RLE Example EOF');
    
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    $ips = IPS::V1->new({
        'filename'  => $f->filename(),
    });
    
    @records = $ips->get_all_records();
    
    is(ref $records[0], 'IPS::Record::Header', 'IPSv1 RLE Writing Test Header');
    is(ref $records[1], 'IPS::Record::RLE',    'IPSv1 RLE Writing Test RLE Record');
    
    
    is($records[1]->get_offset(), 0,   'IPSv1 RLE Writing Test Record Offset');
    is($records[1]->get_size(),   16,  'IPSv1 RLE Writing Test Record Size');
    is(
        $records[1]->get_data(),
        $records[1]->get_data_byte() x $records[1]->get_size(),
        'IPSv1 RLE Writing Test Record Data'
    );
    
    
    is(ref $records[2], 'IPS::Record::EOF', 'IPSv1 RLE Writing Test EOF');
}




{
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    copy('data/case1.dat', $f->filename());
    
    my $ips = IPS::V1->new({
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
    
    my $ips = IPS::V1->new({
        'filename'  => 'data/case1.rle.ips',
    });
    
    $ips->patch({
        'filename'  => $f->filename(),
    });
    
    seek($f, 0, SEEK_SET);
    
    is(<$f>, "A" x 0x30, "IPSv1 RLE Patching Test");
}