#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Carp;
use File::Temp;
use Test::More 'no_plan';


use lib '..';

use IPS::File;







BEGIN {
    my @exports = qw(
        IPS_EOF
        IPS_EOF_LENGTH
        
        IPS_RECORD_OFFSET_LENGTH
        IPS_RECORD_SIZE_LENGTH
        
        IPS_RECORD_RLE_SIZE_FLAG
        IPS_RECORD_RLE_SIZE_LENGTH
        IPS_RECORD_RLE_DATA_LENGTH
        
        IPS_TRUNCATION_OFFSET_LENGTH
    );
    
    use_ok('IPS::Record'    => @exports);
}








use IPS::Record::Header;
use IPS::Record::V1;
use IPS::Record::RLE;
use IPS::Record::EOF;
use IPS::Record::V2;

my $fh = IPS::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

my $base_args_ref = {
    'filehandle'    => $fh,
};


my $h  = IPS::Record::Header->new();

my $v1 = IPS::Record::V1->new({
    'offset'    => 0x888,
    'data'      => pack("C", 0x80),
});

my $rle = IPS::Record::RLE->new({
    'offset'    => 0xFFF,
    'size'      => 0xFFF,
    'data'      => pack "C*", 0xFF,
});

my $e = IPS::Record::EOF->new();

my $v2 = IPS::Record::V2->new({
    'offset' => 0xEEEEEE,
});


foreach my $r ($h, $v1, $rle, $e, $v2) {
    $r->write($base_args_ref);
}

$fh->seek(0);

{
    my $read_h   = IPS::Record->new($base_args_ref);
    my $read_v1  = IPS::Record->new($base_args_ref);
    my $read_rle = IPS::Record->new($base_args_ref);
    my $read_v2  = IPS::Record->new($base_args_ref);
    my $no_record = IPS::Record->new($base_args_ref);


    isa_ok($read_h, 'IPS::Record::Header');
    isa_ok($read_v1, 'IPS::Record::V1');
    isa_ok($read_rle, 'IPS::Record::RLE');
    isa_ok($read_v2->[0], 'IPS::Record::EOF');
    isa_ok($read_v2->[1], 'IPS::Record::V2');

    is($no_record, undef, 'No More Records Test');
}