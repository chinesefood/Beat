#!/usr/bin/perl -w


use strict;
use warnings;
use diagnostics;


use Carp;
use IO::File;


use lib ('/home/james/code/megaman/code');


use IPS::Record::RLE;
use IPS::Record::V1;
use IPS::Record::EOF;
use IPS::Record::V2;
use IPS::Record::Header;


my $h = IPS::Record::Header->new();
my $e = IPS::Record::EOF->new();


sub write_header {
    my ($fh) = @_;
    
    $h->write({
        'filehandle'    => $fh,
    });
}

sub write_eof {
    my ($fh) = @_;
    
    $e->write({
        'filehandle'    => $fh,
    });
}
        
sub new_file {
    my ($filename) = @_;
    
    return IO::File->new(
        $filename,
        '+>',
    );
}
    

{
    my $fh = new_file('minimal.ips');
    
    write_header($fh);
    write_eof($fh);
}


{
    my $fh = new_file('minimal_v2.ips');
    
    write_header($fh);
    write_eof($fh);
    
    
    my $r = IPS::Record::V2->new({
        'truncation_offset' => 0x1,
    });
    
    $r->write({
        'filehandle'    => $fh,
    });
}
    

{
    my $fh = new_file('ipsv1_example.ips');
    
    
    write_header($fh);
    
    my $r = IPS::Record::V1->new({
        'offset'    => 0x00,
        'data'      => 'DATA',
    });
    
    $r->write({
        'filehandle'    => $fh,
    });
    
    write_eof($fh);
}


{
    my $fh = new_file('ipsv1_rle_example1.ips');
    
    write_header($fh);
    
    my $r = IPS::Record::RLE->new({
        'offset'    => 0x00,
        'data'      => 'A',
        'size'      => 0x10,
    });
    
    $r->write({
        'filehandle' => $fh,
    });
    
    write_eof($fh);
}


{
    my $fh = new_file('all_record_types.ips');
    
    
    write_header($fh);
    
    my $v1 = IPS::Record::V1->new({
        'offset'    => 0x00,
        'data'      => 'DATA',
    });
    
    my $rle = IPS::Record::RLE->new({
        'offset'    => $v1->get_size(),
        'data'      => 'A',
        'size'      => 0x10,
    });
    
    my $v2 = IPS::Record::V2->new({
        'truncation_offset' => 0x3,
    });
    
    
    foreach my $r ($v1, $rle) {
        $r->write({
            'filehandle'    => $fh,
        });
    }
    
    write_eof($fh);
    
    $v2->write({
        'filehandle' => $fh,
    });
}


{
    my $fh = new_file('eof_test.ips');
    
    
    write_header($fh);
    
    my $eof = hex unpack("H*", pack("A*", 'EOF'));
    
    
    my $eof_v1 = IPS::Record::V1->new({
        'offset'    => $eof,
        'data'      => 'EOF',
    });
    
    my $eof_v2 = IPS::Record::V2->new({
        'truncation_offset' => $eof,
    });
    
    $eof_v1->write({
        'filehandle' => $fh,
    });
    
    write_eof($fh);
    
    $eof_v2->write({
        'filehandle'    => $fh,
    });
}




{
    my $fh = new_file('case1.ips');
    
    
    write_header($fh);
    
    my $r = IPS::Record::V1->new({
        'offset'    => 0x10,
        'data'      => 'A' x 0x10,
    });
    
    $r->write({
        'filehandle'    => $fh,
    });
    
    write_eof($fh);
}



{
    my $fh = new_file('case1.rle.ips');
    
    
    write_header($fh);
    
    my $r = IPS::Record::RLE->new({
        'offset'    => 0x10,
        'data'      => 'A',
        'size'      => 0x10,
    });
    
    $r->write({
        'filehandle'    => $fh,
    });
    
    write_eof($fh);
}




{
    my $fh = new_file('case1.v2.ips');
    
    
    write_header($fh);
    
    my $r = IPS::Record::V2->new({
        'truncation_offset' => 0x10,
    });
    
    write_eof($fh);
    
    $r->write({
        'filehandle' => $fh,
    });   
}