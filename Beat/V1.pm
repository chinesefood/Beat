package Beat::V1;


use strict;
use warnings;
use diagnostics;


use base qw(
    Beat
);

use Beat::Record;







# sub new {
    # my ($class, $args_ref) = @_;
    
    
    # my $self = bless \do { my $anon_scalar }, ref($class) || $class;
    
    # if (defined $args_ref->{'filename'}) {
        # $self->_init($args_ref);
    # }
    
    # return $self;
# }








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


1;
