#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Carp;
use File::Temp;
use Test::More 'no_plan';


use lib '..';

use Beat::File;







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
    
    use_ok('Beat::Record'    => @exports);
}








use Beat::Record::Header;
use Beat::Record::V1;
use Beat::Record::RLE;
use Beat::Record::EOF;
use Beat::Record::V2;

my $fh = Beat::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

my $base_args_ref = {
    'filehandle'    => $fh,
};


my $h  = Beat::Record::Header->new();

my $v1 = Beat::Record::V1->new({
    'offset'    => 0x888,
    'data'      => pack("C", 0x80),
});

my $rle = Beat::Record::RLE->new({
    'offset'    => 0xFFF,
    'size'      => 0xFFF,
    'data'      => pack "C*", 0xFF,
});

my $e = Beat::Record::EOF->new();

my $v2 = Beat::Record::V2->new({
    'offset' => 0xEEEEEE,
});


foreach my $r ($h, $v1, $rle, $e, $v2) {
    $r->write($base_args_ref);
}

$fh->seek(0);

{
    my $read_h   = Beat::Record->new($base_args_ref);
    my $read_v1  = Beat::Record->new($base_args_ref);
    my $read_rle = Beat::Record->new($base_args_ref);
    my $read_v2  = Beat::Record->new($base_args_ref);
    my $no_record = Beat::Record->new($base_args_ref);


    isa_ok($read_h, 'Beat::Record::Header');
    isa_ok($read_v1, 'Beat::Record::V1');
    isa_ok($read_rle, 'Beat::Record::RLE');
    isa_ok($read_v2->[0], 'Beat::Record::EOF');
    isa_ok($read_v2->[1], 'Beat::Record::V2');

    is($no_record, undef, 'No More Records Test');
}