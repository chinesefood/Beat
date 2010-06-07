#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More qw(no_plan);
use File::Temp;
use Carp;





BEGIN {
    use lib qw(
        ..
    );
    
    use_ok('Beat::Record::V1', qw(
        IPS_RECORD_OFFSET_LENGTH
        IPS_RECORD_SIZE_LENGTH
    ));
};

use Beat::File;



my @v1_methods = qw(
    write
    read
    patch
    
    get_data
    set_data

    get_size

    get_offset
    set_offset
);

can_ok('Beat::Record::V1', @v1_methods);


my $offset = 0x00;
my $data   = map { pack "C", $_ } (0..255);
my $size   = length $data;

my $r_test = new_ok('Beat::Record::V1' => [{
    'offset'    => $offset,
    'data'      => $data,
}]);


is($r_test->get_offset(), $offset, "Offset Attribute");
is($r_test->get_size(),   $size,   "Size Attribute");
is($r_test->get_data(),   $data,   "Data Attribute");



    
# Test record writing.

my $r = Beat::Record::V1->new();

$r->set_offset($offset);
$r->set_data($data);


is($r->get_offset(), $offset, "Offset mutators");
is($r->get_size(),   $size,   "Size mutators"  );
is($r->get_data(),   $data,   "Data mutators");


my $f = Beat::File->new({
    'write_to'  => File::Temp->new(UNLINK   => 1)->filename(),
});

$r->write({
    'filehandle'    => $f,
});


$f->seek(0);


my $r_test_f = Beat::Record::V1->new({
    'filehandle'    => $f,
});

is($r_test_f->get_offset(), $offset, "Offset Read/Write Test");
is($r_test_f->get_size(),   $size,   "Size Read/Write Test");
is($r_test_f->get_data(),   $data,   "Data Read/Write Test");




{
    my $nf = Beat::File->new({
        'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
    });
    
    $r_test_f->patch({
        'filehandle'    => $nf,
    });
    
    $nf->seek(0);
    
    is($nf->get_line(), $data, 'Patching Test');
}