package IPS::Record::RLE;


use strict;
use warnings;
use diagnostics;


use Carp;


use base qw(
    IPS::Record::V1
    Exporter
);


use constant IPS_RECORD_RLE_SIZE_FLAG      => 0;
use constant IPS_RECORD_RLE_SIZE_LENGTH    => 2;
use constant IPS_RECORD_RLE_DATA_LENGTH    => 1;

our @EXPORT_OK = qw(
    IPS_RECORD_RLE_SIZE_FLAG
    IPS_RECORD_RLE_SIZE_LENGTH
    IPS_RECORD_RLE_DATA_LENGTH
);


my %rle_size_of;







sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do{ my $anon_scalar } , ref($class) || $class;
    
    if (defined $args_ref->{'filehandle'}) {
        $self->_init($args_ref);
    }
    else {
        foreach my $a qw(offset data) {
            my $m = "set_$a";
            
            if (defined $args_ref->{$a}) {
                $self->$m($args_ref->{$a});
            }
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
    
    if ($s != IPS_RECORD_RLE_SIZE_FLAG) {   
        croak "This record is not an IPSv1 RLE record";
    }
    
    my $rs = $self->_read_rle_size($args_ref);
    my $d = $self->_read_data({
        'length'  => IPS_RECORD_RLE_DATA_LENGTH,
        %$args_ref,
    });
    
    $self->set_offset($o);
    $self->set_size($rs);
    $self->set_data_byte($d);
}








sub write {
    my ($self, $args_ref) = @_;
    
    
    $self->_write_offset($args_ref);
    $self->_write_size($args_ref);
    $self->_write_rle_size($args_ref);
    $self->_write_data($args_ref);
}








sub get_size {
    my ($self) = @_;
    
    
    return $rle_size_of{$self};
}








sub set_size {
    my ($self, $rs) = @_;
    
    
    $rle_size_of{$self} = $rs;
}








sub get_data {
    my ($self) = @_;
    
    
    return $self->get_data_byte() x $self->get_size();
}








sub set_data {
    my ($self, $data) = @_;
    
    my $l = length $data;
    my $d = substr $data, 0, 1;
    
    
    $self->IPS::Record::V1::set_data($d);
    $self->set_size($l);
}







    
sub get_data_byte {
    my ($self) = @_;
    
    
    return $self->IPS::Record::V1::get_data();
}








sub set_data_byte {
    my ($self, $d) = @_;
    
    
    $self->IPS::Record::V1::set_data($d);
}








{
    sub _init {
        my ($self, $args_ref) = @_;
        
        
        $self->read($args_ref);
    }
    
    
    
    
    
    
    
    
    sub _write_size {
        my ($self, $args_ref) = @_;
        
        $args_ref->{'filehandle'}->write(
            pack "H*", sprintf("%04X", IPS_RECORD_RLE_SIZE_FLAG)
        );
    }








    sub _read_rle_size {
        my ($self, $args_ref) = @_;
        
        my $rs = $args_ref->{'filehandle'}->read({
            'length'        => IPS_RECORD_RLE_SIZE_LENGTH,
        });
        
        return hex unpack "H*", $rs;
    }




    
    
    
    
    sub _write_rle_size {
        my ($self, $args_ref) = @_;
        
        $args_ref->{'filehandle'}->write(
            pack "H*", sprintf("%04X", $self->get_size())
        );
    }
    
    
    
    
    
    
    
    
    sub _write_data {
        my ($self, $args_ref) = @_;
        
        $args_ref->{'filehandle'}->write( $self->get_data_byte() );
    }
}


1;