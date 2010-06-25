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
    use_ok('Beat::V2');
}




my @methods = qw(
    read
    write
    
    make
    patch
    
    get_truncation_offset
    set_truncation_offset
);

can_ok('Beat::V2', @methods);








{
    my $ips = Beat::V2->new({
        'filename'  => 'data/minimal_v2.ips',
    });
    
    my ($v2) = $ips->get_all_records();
    
    
    is(ref $v2,     'Beat::Record::V2',     'Minimal IPSv2 Patch V2 Test');
    
    is($ips->get_truncation_offset(), 1, 'Minimal IPSv2 Truncation Offset Test');
    
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    $ips->write({
        'filename'  => $f->filename(),
    });
    
    
    
    $ips = Beat::V2->new({
        'filename'  => $f->filename(),
    });
    
    ($v2) = $ips->get_all_records();
    
    is(ref $v2,     'Beat::Record::V2',     'IPSv2 Patch Writing V2 Test'); 
}




{
    my $f = File::Temp->new(
        UNLINK => 1,
    );
    
    copy('data/case1.dat', $f->filename());
    
    my $ips = Beat::V2->new({
        'filename'  => 'data/case1.v2.ips',
    });
    
    $ips->patch({
        'filename'  => $f->filename(),
    });
    
    seek($f, 0, SEEK_SET);
    
    is(<$f>, "A" x 0x10, "IPSv2 Patching Test");
}