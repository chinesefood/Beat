package Beat::Record::V2;


use strict;
use warnings;
use diagnostics;


use Carp;

use base qw(
    Exporter
);


use constant IPS_TRUNCATION_OFFSET_LENGTH   => 3;

use constant IPS_TRUNCATION_OFFSET_OFFSET   => -3;
use constant IPS_TRUNCATION_OFFSET_MAX      => 2 ** 24 - 1;
use constant IPS_TRUNCATION_OFFSET_MIN      => 0;
use constant IPS_END_OF_FILE                => 0;


our @EXPORT_OK = qw(
    IPS_TRUNCATION_OFFSET_LENGTH
);


my %truncation_offset_of;








sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do{ my $anon_scalar }, ref($class) || $class;
    
    if (defined $args_ref->{'filehandle'}) {
        $self->_init($args_ref);
    }
    else {
        if (defined $args_ref->{'offset'}) {
            $self->set_offset($args_ref->{'offset'});
        }
    }
    
    return $self;
}








sub patch {
    my ($self, $args_ref) = @_;
    
    
    $args_ref->{'filehandle'}->truncate($self->get_offset());
}








sub read {
    my ($self, $args_ref) = @_;
    
    my $o = $self->_read_offset($args_ref);
    
    $self->set_offset($o);
}








sub write {
    my ($self, $args_ref) = @_;
    
    
    $self->_write_offset($args_ref);
}





    

    
sub set_offset {
    my ($self, $o) = @_;
    
    
    if ($o > IPS_TRUNCATION_OFFSET_MAX) {
        croak "Tried to set truncation offset ($o) larger than "
            . IPS_TRUNCATION_OFFSET_MAX;
    }
    elsif ($o < IPS_TRUNCATION_OFFSET_MIN) {
        croak "Tried to set truncation offset ($o) smaller than "
            . IPS_TRUNCATION_OFFSET_MIN;
    }
    
    $$self = $o;
}



sub get_offset {
    my ($self) = @_;
    
    
    return $$self;
}

    
       
    
    
    
    
    
{
    sub _init {
        my ($self, $args_ref) = @_;
        
        $self->read($args_ref);
    }
    
    
    
    
    
    
    
    
    sub _read_offset {
        my ($self, $args_ref) = @_;
        
        
        my $o = $args_ref->{'filehandle'}->read({
            'length'        => IPS_TRUNCATION_OFFSET_LENGTH,
        });
        
        return hex unpack "H*", $o;
    }
    
    
    
    
    
    
    
    
    sub _write_offset {
        my ($self, $args_ref) = @_;
        
        
        $args_ref->{'filehandle'}->write(
            pack "H*", sprintf("%06X", $self->get_offset())
        );
    }
}

1;
