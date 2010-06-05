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


use IPS::File;


BEGIN {
    use_ok('IPS::Record::V2');
}




my @v2_methods = qw(
    write
    read
    patch
    
    get_offset
    set_offset
);

can_ok('IPS::Record::V2', @v2_methods);




my $o = 0x100;

my $r = new_ok ('IPS::Record::V2' => [{
    'offset' => $o,
}]);

is($r->get_offset(), $o, "Default Constructor Test");




my $r_set = new_ok('IPS::Record::V2');

$r_set->set_offset($o);

is($r_set->get_offset(), $o, "Truncation Offset Mutator Test");




my $f = IPS::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

$r_set->write({
    'filehandle'    => $f,
});

$f->seek(0);

my $r_test = IPS::Record::V2->new({
    'filehandle'    => $f,
});

is($r_test->get_offset(), $o, "IPS Record V2 Writing Test");




{
    my $nf = IPS::File->new({
        'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
    });
    
    
    $nf->write("0" x 0x200);
    
    $r_test->patch({
        'filehandle'    => $nf,
    });
    
    is($nf->get_size(), $r_test->get_offset(), 'V2 Patching Test');
}