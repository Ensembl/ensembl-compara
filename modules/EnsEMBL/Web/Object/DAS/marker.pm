package EnsEMBL::Web::Object::DAS::marker;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'marker'  }
  ];
}

sub Features {
  my $self = shift;
  return $self->base_feature( 'MarkerFeature', 'marker' );
}


sub _feature {
  my( $self, $feature ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $marker        = $feature->marker;
  my $feature_id    = $marker->display_marker_synonym;
  my $feature_type  = $feature->marker_consensus->marker_type;
  my $feature_class = $feature->marker_consensus->marker_class;
  my $type          = $feature->analysis->logic_name;
  my $display_label = $feature->analysis->display_label;
  my $slice_name    = $self->slice_cache( $feature->slice );
  my $consensus     = $feature->marker_consensus->marker_consensus;
  my $note_array    = [
    'Mapweight: '.   $marker->map_weight,
    'Left primer: '. $marker->left_primer,
    'Right primer: '.$marker->map_primer,
    'Type: '.        $marker->type
  ];
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $feature_id,
   'LABEL'       => "$feature_class: $feature_id",
   'TYPE'        => "marker:$type:$feature_type",
   'ORIENTATION' => $feature->hstrand,
   'TARGET'      => {
     'ID'        => $feature_id,
     'START'     => $feature->hstart,
     'STOP'      => $feature->hend,
   },
   'NOTE'        => $note_array,
   'SCORE'       => $feature->score,
   'METHOD'      => "$type:$feature_type",
   'CATEGORY'    => "$type:$feature_type",
   $self->loc( $slice_name, $feature->start, $feature->end, $feature->strand ),
  };
## Return the reference to an array of the slice specific hashes.
}

1;
