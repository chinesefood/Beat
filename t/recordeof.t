#!/usr/bin/perl


use strict;
use warnings;
use diagnostics;


use Test::More 'no_plan';
use File::Temp;

use lib qw(
    ..
);


use IPS::File;

BEGIN {
    use_ok('IPS::Record::EOF', qw(
        IPS_EOF
        IPS_EOF_LENGTH
    ));
}


my $eof = new_ok('IPS::Record::EOF');


my @eof_methods = qw(
    write
);

can_ok $eof, @eof_methods;


my $f = IPS::File->new({
    'write_to'  => File::Temp->new(UNLINK => 1)->filename(),
});

$eof->write({
    'filehandle'    => $f
});

$f->seek(0);

ok(IPS::Record::EOF->new({'filehandle' => $f}), "EOF Writing Test");