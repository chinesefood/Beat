package Beat::V2;


use base qw(Beat::V1);


my %truncation_record_of;







# sub new {
    # my ($class, $args_ref) = @_;
    
    
    # my $self = bless \do { my $anon_scalar }, ref($class) || $class;
    
    # if (defined($args_ref->{'filename'}) or defined($args_ref->{'records'})) {
        # $self->_init($args_ref);
        
        # ($truncation_record_of{$self}) = grep { ref($_) eq 'Beat::Record::V2' }
            # $self->get_all_patch_records();
    # }
    
    # return $self;
# }








sub load_records {
    my ($self, $args_ref) = @_;
    
    
    LOAD_RECORDS: {
        my $r = Beat::Record->new($args_ref);
        
        if (defined $r) {
            if (ref($r) eq 'ARRAY') {
                $self->push_record(@$r);
                
                $truncation_record_of{$self} = $r->[1];
            }
            else {
                $self->push_record($r);
            }
        
            
            redo LOAD_RECORDS;
        }
    }
}








sub get_truncation_offset {
    my ($self) = @_;
    
    
    return $truncation_record_of{$self}->get_offset();
}




sub set_truncation_offset {
    my ($self, $o) = @_;
    
    
    my $r = Beat::Record::V2->new({
        'offset' => $o
    });
    
    $truncation_record_of{$self} = $r;
}


1;