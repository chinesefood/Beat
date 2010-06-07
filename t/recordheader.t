#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More 'no_plan';
use File::Temp;


use lib qw(
    ..
);


use Beat::File;








BEGIN {
    my @imports = qw(
        IPS_HEADER
        IPS_HEADER_LENGTH
    );
    
    use_ok('Beat::Record::Header', @imports);
}


my $header = new_ok('Beat::Record::Header');


my @header_methods = qw(
    write
);

can_ok $header, @header_methods;


my $f = Beat::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

$header->write({
    'filehandle'    => $f
});

$f->seek(0);

my $header_test = Beat::Record::Header->new({
    'filehandle'    => $f,
});

$f->seek(0);

is(
    $f->read({'length' => IPS_HEADER_LENGTH}),
    IPS_HEADER,
    "Header Writing Test"
);