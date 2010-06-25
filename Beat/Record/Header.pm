package Beat::Record::Header;


use strict;
use warnings;
use diagnostics;


use Carp;


use base qw(
    Exporter
);


use constant IPS_HEADER         => 'PATCH';
use constant IPS_HEADER_LENGTH  => 5;

use constant START_OF_FILE      => 0;


our @EXPORT_OK = qw(
    IPS_HEADER
    IPS_HEADER_LENGTH
);








sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do{ my $anon_scalar = IPS_HEADER }, ref($class) || $class;
    
    if (defined $args_ref->{'filehandle'}) {
        $self->_init($args_ref);
    }
    
    return $self;
}



        
       

       
sub write {
    my ($self, $args_ref) = @_;
    
    
    $self->_write_header($args_ref);
}








{
    sub _init {
        my ($self, $args_ref) = @_;
        
        
        my $d = $args_ref->{'filehandle'}->read({
            'length'    => IPS_HEADER_LENGTH,
        });
        
        if ($d eq IPS_HEADER) {
            return 1;
        }
        else {
            croak "Invalid IPS Patch Header";
        }
    }
    
    
    
    
    
    
    
    
    sub _write_header {
        my ($self, $args_ref) = @_;
        
        
        $args_ref->{'filehandle'}->write(IPS_HEADER);
    }
}
1;
