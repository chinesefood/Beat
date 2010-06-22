=pod

set old file offset;
set new file offset;

set up new filehandle
set up old filehandle


BUILD_RECORDS:

load line from old file;
    set line offset;
load line from new file;
    set line offset;


if old line eq new line
    increment offsets;
    load next lines;

    if length old line eq length new line
        while last character doesn't match
            have obj concatenate next chunk

        build some IPS records:
            find first nonmatching character
            find last nonmatching character

            if range is greater than IPS record size
                build two records
            push to the records stack

    if length old line > length new line
        build one IPS record
        push to stack
        end

    if length old line < length new line
        build a v2 record
        push to stack
        end

=cut




package Beat::Diff;


use strict;
use warnings;
use diagnostics;

use Carp;

use Beat::File;
use Beat::Record::V1;
use Beat::Record::V2;



sub new {
    my ($class, $args_ref) = @_;


    return bless \do { my $anon_scalar; }, ref($class) || $class;
}








sub generate_records {
    my ($self, $args_ref) = @_;


    my $of = Beat::File->new({
        'read_from' => $args_ref->{'old_file'},
    });

    my $nf = Beat::File->new({
        'read_from' => $args_ref->{'new_file'},
    });

    my @records;
    
    my $is_v2 = 0;
    if ($of->get_size() > $nf->get_size()) {
        $is_v2 = 1;
    }

    my $new_is_larger = 0;
    if ($of->get_size() < $nf->get_size()) {
        $new_is_larger = 1;
    }
    
    BUILD_RECORDS:
    while (!$of->eof() && !$nf->eof()) {
        my $length;
        
        if ($nf->get_size() - $nf->tell() > 2 ** 16) {
            $length = 2 ** 16;
        }
        else {
            $length = $nf->get_size() % 2 ** 16;
        }
    
        if ($is_v2) {
            my $diff = $nf->get_size() - $nf->tell();
            
            if ($length > $diff) {
                $length = $diff;
            }
        }
        
        my $of_chunk = $of->read({
            'length'    => $length,
        });
        
        my $nf_chunk = $nf->read({
            'length'    => $length,
        });
        
       
        my $non_match;
        my $in_delta = 0;
        
        FIND_DELTAS:
        for (my $i = 0; $i <= $length; $i++) {
            my $matched = substr($of_chunk, $i, 1) eq substr($nf_chunk, $i, 1);
            
            if ($matched && !$in_delta) {
                ;
            }
            elsif ($matched && $in_delta) {
                $in_delta = 0;
                
                my $range = $i - $non_match;
                
                my $delta = substr $nf_chunk, $non_match, $range;
                
                my $offset = $nf->tell() - $length + $non_match;
                
                my $r = Beat::Record::V1->new({
                    'offset'    => $offset,
                    'data'      => $delta,
                });
                
                push @records, $r;
            }
            elsif (!$matched && !$in_delta) {
                $non_match = $i;
                $in_delta = 1;
            }
            elsif (!$matched && $in_delta) {
                ;
            }
            else {
                croak "Error building delta";
            }
        }
        
    }
    
    if ($is_v2) {
        push @records, Beat::Record::V2->new({
            'offset'    => $nf->get_size(),
        });
    }
    
    while (!$nf->eof() && $new_is_larger) {
        my $length;
        
        if ($nf->get_size() - $nf->tell() > 2 ** 16) {
            $length = 2 ** 16;
        }
        else {
            $length = $nf->get_size() % 2 ** 16;
        }

        my $nf_chunk = $nf->read({
            'length'    => $length,
        });

        my $offset = $nf->tell() - $length;
        
        push @records, Beat::Record::V1->new({
            'offset'    => $offset,
            'data'      => $nf_chunk,
        });
    }
    
    return @records;
}








sub generate_rle_records {
    ;
}


1;