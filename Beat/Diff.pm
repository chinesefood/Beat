package IPS::Diff;


use strict;
use warnings;
use diagnostics;


use IPS::Diff::Line;




sub new {
    my ($class, $args_ref) = @_;
    
    
    return bless \do { my $anon_scalar; }, ref($class) || $class;
}








sub generate_records {
    ;
}








sub generate_rle_records {
    ;
}








{
    sub _generate_records {
        my ($self, $args_ref) = @_;
        
        
    }
    
    
    
    
    
    
    
    
    sub _lines_are_equal {
        my ($self, $args_ref) = @_;
        
        
        my $ol = $args_ref->{'old'}->get_line();
        my $nl = $args_ref->{'new'}->get_line();
        
        return $ol eq $nl;
    }
    
    
    
    
    
    
    
    
    sub _read_lines {
        my ($self, $args_ref) = @_;
        
        
        my $o = IPS::Diff::Line->new({
            'line'  => $args_ref->{'old'}->get_line(),
        });
        
        my $n = IPS::Diff::Line->new({
            'line'  => $args_ref->{'new'}->get_line(),
        });
        
        return ($o, $n);
    }
    
    
    
    
    
    
    
    
    sub _check_for_truncated_file {
        my ($self, $args_ref) = @_;
        
        
        my $o = $args_ref->{'old'};
        my $n = $args_ref->{'new'};
        
        if ($o->get_size() > $n->get_size()) {
            return 1;
        }
        else {
            return 0;
        }
    }
    
    
    
    
    
    
    
    
    sub _make_record {
        ;
    }
    
    
    
    
    
    
    
    
    sub _make_rle_record {
        ;
    }
}

1;
