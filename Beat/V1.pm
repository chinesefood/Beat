package Beat::V1;


use strict;
use warnings;
use diagnostics;


use base qw(
    Beat
);

use Beat::Record;







sub new {
    my ($class, $args_ref) = @_;
    
    
    my $self = bless \do { my $anon_scalar }, ref($class) || $class;
    
    if (defined $args_ref->{'filename'}) {
        $self->_init($args_ref);
    }
    
    return $self;
}








sub load_records {
    my ($self, $args_ref) = @_;
    
    
    LOAD_RECORDS: {
        my $r = Beat::Record->new($args_ref);

        if (defined $r) {
            $self->push_record($r);
        
            redo LOAD_RECORDS;
        }
    }
}








sub patch {
    my ($self, $args_ref) = @_;
    
    
    my $fh = Beat::File->new({
        'write_to'  => $args_ref->{'filename'},
    });
    
    
    foreach my $r ($self->get_all_patch_records()) {
        $r->patch({
            'filehandle'    => $fh
        });
    }
}








{
    sub _init {
        my ($self, $args_ref) = @_;
        
        
        $self->set_filename($args_ref->{'filename'});
        
        if (defined $args_ref->{'records'}) {
            $self->set_all_records($args_ref->{'records'});
        }
        elsif ($self->get_filename()) {
            $self->read($args_ref);
        }
        else {
            $self->set_record({
                0   => Beat::Record::Header->new(),
                1   => Beat::Record::EOF->new(),
            });
        }
        
    }
}


1;
