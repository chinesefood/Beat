package IPS::Diff::Line;


use strict;
use warnings;
use diagnostics;




my %line_of;




sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do { my $anon_scalar }, ref($class) || $class;
    
    if (defined $args_ref{'line'}) {
        $self->_init($args_ref);
    }
    
    return $self;
}








sub get_line {
    my ($self) = @_;
    
    
    return $line_of{$self};
}








sub set_line {
    my ($self, $l) = @_;
    
    
    $line_of{$self} = $l
}








sub get_length {
    my ($self) = @_;
    
    
    return length $line_of{$self};
}








{
    sub _init {
        my ($self, $args_ref) = @_;
        
        
        $self->set_line($args_ref->{'line'});
    }
}


1;
