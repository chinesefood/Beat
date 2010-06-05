package IPS::Record::V1;


use strict;
use warnings;
use diagnostics;

use Carp;

use base qw(
    Exporter
);

use constant IPS_RECORD_OFFSET_LENGTH       => 3;
use constant IPS_RECORD_SIZE_LENGTH         => 2;

use constant IPS_MAX_OFFSET             => 2 ** 24 - 1;
use constant IPS_MIN_OFFSET             => 0;

use constant IPS_MAX_SIZE               => 2 ** 16 - 1;
use constant IPS_MIN_SIZE               => 1;


our @EXPORT_OK = qw(
    IPS_RECORD_OFFSET_LENGTH
    IPS_RECORD_SIZE_LENGTH
);

my %offset_of;      # Store file offset
my %size_of;        # Store size
my %data_of;        # Store data








sub new {
    my ($class, $args_ref) = @_;


    my $self = bless \do{ my $anon_scalar } , ref($class) || $class;

    if (defined $args_ref->{'filehandle'}) {
        $self->_init($args_ref);
    }
    else {
        if (defined $args_ref->{'offset'}) {
            $self->set_offset($args_ref->{'offset'});
        }

        if (defined $args_ref->{'data'}) {
            $self->set_data($args_ref->{'data'});
        }
    }


    return $self;
}








sub patch {
    my ($self, $args_ref) = @_;
    
    
    my $fh = $args_ref->{'filehandle'};
    
    $fh->seek($self->get_offset());
    $fh->write($self->get_data());
}








sub read {
    my ($self, $args_ref) = @_;


    my $o = $self->_read_offset($args_ref);
    my $s = $self->_read_size($args_ref);

    $self->set_offset($o);

    my $d = $self->_read_data({
        'length'    => $s,
        %$args_ref
    });

    $self->set_data($d);
}








sub write {
    my ($self, $args_ref) = @_;


    $self->_write_offset($args_ref);
    $self->_write_size($args_ref);
    $self->_write_data($args_ref);

}








sub set_data {
    my ($self, $d) = @_;


    $data_of{$self} = $d;
}








sub get_data {
    my ($self) = @_;


    return $data_of{$self};
}








sub get_size {
    my ($self) = @_;


    return length $self->get_data();
}








sub get_offset {
    my ($self) = @_;


    return $offset_of{$self};
}







sub set_offset {
    my ($self, $o) = @_;

    if (!defined $o) {
        croak "Offset not defined";
    }
    
    if ($o > IPS_MAX_OFFSET) {
        croak "Tried to set a record offset ($o) higher than " . IPS_MAX_OFFSET;
    }
    elsif ($o < IPS_MIN_OFFSET) {
        croak "Tried to set a record offset ($o) lower than " . IPS_MIN_OFFSET;
    }

    $offset_of{$self} = $o;
}








{
    sub _init {
        my ($self, $args_ref) = @_;


        $self->read($args_ref);
    }






    sub _write_offset {
        my ($self, $args_ref) = @_;

        
        my $o = pack "H*", sprintf("%06X", $self->get_offset());
        
        $args_ref->{'filehandle'}->write($o);
    }








    sub _write_size {
        my ($self, $args_ref) = @_;

        
        my $s = pack "H*", sprintf("%04X", $self->get_size());
        $args_ref->{'filehandle'}->write($s);
    }








    sub _write_data {
        my ($self, $args_ref) = @_;

        
        my $d = $self->get_data();
        
        $args_ref->{'filehandle'}->write($d);
    }








    sub _read_data {
        my ($self, $args_ref) = @_;


        my $d = $args_ref->{'filehandle'}->read({
            'length'        => $args_ref->{'length'},
        });

        return $d;
    }








    sub _read_offset {
        my ($self, $args_ref) = @_;


        my $o = $args_ref->{'filehandle'}->read({
            'length'        => IPS_RECORD_OFFSET_LENGTH,
        });

        return hex unpack "H*", $o;
    }







    sub _read_size {
        my ($self, $args_ref) = @_;


        my $s = $args_ref->{'filehandle'}->read({
            'length'        => IPS_RECORD_SIZE_LENGTH,
        });

        return hex unpack "H*", $s;
    }
}

1;
