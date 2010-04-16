package EnsEMBL::Web::Data::Bio::AlignFeature;

### NAME: EnsEMBL::Web::Data::Bio::AlignFeature
### Base class - wrapper around Bio::EnsEMBL::DnaAlignFeature 
### or ProteinAlignFeature API object(s) 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Feature

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
  my $self = shift;
  my $data = $self->data_objects;
  my $type = $self->type;
  my $results = [];

  my @coord_systems = @{$self->coord_systems}; 
  foreach my $f (@$data) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
#     next unless ($f->score > 80);
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
      if( $f->coord_system_name ne $coord_systems[0] ) {
        foreach my $system ( @coord_systems ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          } 
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
      };
    } 
  }   
  my $feature_mapped = 1; ## TODO - replace with $self->feature_mapped call once unmapped feature display is added
  if ($feature_mapped) {
    return [$results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ], $type];
  }
  else {
    return [$results, [], $type];
  }


}

1;
