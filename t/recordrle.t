#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);
use Carp;
use File::Temp;


use lib qw(
    ..
);


use Beat::File;


BEGIN {
    use_ok('Beat::Record::RLE');
};





my @rle_methods = qw(
    write
    read
    patch

    get_data
    set_data

    get_size
    set_size
    
    get_offset
    set_offset
);

can_ok('Beat::Record::RLE', @rle_methods);


my $offset = 0x00;
my $data   = 'C' x 0x10;
my $size   = length $data;

my $r_test = new_ok('Beat::Record::RLE' => [{
    'offset'    => $offset,
    'data'      => $data,
}]);


is($r_test->get_offset(), $offset, "Offset Attribute");
is($r_test->get_size(),   $size,   "Size Attribute");
is($r_test->get_data(),   $data,   "Data Attribute");



    
    
# Test record writing.

my $r = Beat::Record::RLE->new();

$r->set_offset($offset);
$r->set_size($size);
$r->set_data($data);


is($r->get_offset(),    $offset, "Offset mutators");
is($r->get_size(),      $size,   "RLE Size mutators"  );
is($r->get_data(),      $data,   "Data mutators");



my $f = Beat::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

$r->write({
    'filehandle'    => $f,
});


$f->seek(0);

my $r_test_f = Beat::Record::RLE->new({
    'filehandle'    => $f,
});

is($r_test_f->get_offset(), $offset,    "Offset Read/Write Test");
is($r_test_f->get_size(),   $size,      "Size Read/Write Test");
is($r_test_f->get_data(),   $data,      "Data Read/Write Test");


{
    my $nf = Beat::File->new({
        'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
    });
    
    
    $r_test_f->patch({
        'filehandle'    => $nf,
    });
    
    $nf->seek(0);
    
    is($nf->get_line(), $r_test_f->get_data(), 'RLE Patching Test');
}