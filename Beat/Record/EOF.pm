package Beat::Record::EOF;


use strict;
use warnings;
use diagnostics;


use Carp;


use base qw(
    Exporter
);


use constant IPS_EOF                        => 'EOF';
use constant IPS_EOF_LENGTH                 => 3;


our @EXPORT_OK = qw(
    IPS_EOF
    IPS_EOF_LENGTH
);




sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do { my $anon_scalar }, ref($class) || $class;
    
    if (defined $args_ref->{'filehandle'}) {
        $self->_init($args_ref);
    }
    
    
    return $self;
}








sub write {
    my ($self, $args_ref) = @_;
    
    
    $self->_write_eof_record($args_ref);
}

        
    
    
    
    
    
    
{
    sub _init {
        my ($self, $args_ref) = @_;
        
        my $d = $args_ref->{'filehandle'}->read({
            'length'    => IPS_EOF_LENGTH,
        });
        
        if ($d ne IPS_EOF) {
            croak "Not end of patch";
        }
    }
    
    
    
    
    
    
    
    
    sub _write_eof_record {
        my ($self, $args_ref) = @_;
        
        
        $args_ref->{'filehandle'}->write(IPS_EOF);
    }
}

1;
