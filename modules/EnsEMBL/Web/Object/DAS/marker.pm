package EnsEMBL::Web::Object::DAS::marker;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS);



sub Types {
  my $self = shift;

  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'marker'  }
			     ]
			     }
	  ];
}

sub Features {
  my $self = shift;
  my( $feature_type, $feature_label ) = ( 'MarkerFeature', 'marker' );

  $self->{_feature_label} = $feature_label;
  my @segments      = $self->Locations;
  my %feature_types = map { $_ ? ($_=>1) : () } @{$self->FeatureTypes  || []};
  my @group_ids     = grep { $_ }               @{$self->GroupIDs      || []};
  my @feature_ids   = grep { $_ }               @{$self->FeatureIDs    || []};
warn "@group_ids - @feature_ids";

  my $dba_hashref;
  my( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
  $db = 'core' unless $db;
  my @features;
  foreach ($db) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    $dba_hashref->{$_}=$T if $T;
  }
  @logic_names = (undef) unless @logic_names;
  if(0){
    warn "Databases:   ",join ' ', sort keys %$dba_hashref;
    warn "Logic names: @logic_names";
    warn "Segments:    ",join ' ', map { $_->slice->seq_region_name } @segments;
    warn "Group ids:   @group_ids";
    warn "Feature ids: @feature_ids";
  }
  my $call         = "get_all_$feature_type".'s';
  my $adapter_call = "get_$feature_type".'Adaptor';

  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && ($segment->{'TYPE'} eq 'ERROR'||$segment->{'TYPE'} eq 'UNKNOWN') ) {
      push @features, $segment;
      next;
    }
    my $slice_name = $segment->slice->seq_region_name.':'.$segment->slice->start.','.$segment->slice->end.':'.$segment->slice->strand;
    $self->{_features}{$slice_name}= {
      'REGION'   => $segment->slice->seq_region_name,
      'START'    => $segment->slice->start,
      'STOP'     => $segment->slice->end,
      'FEATURES' => [],
    };

    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $logic_name (@logic_names) {
        foreach my $feature ( @{$segment->slice->$call($logic_name,undef,undef,$db_key) } ) {
          $self->_feature( $feature );
        }
      }
    }
  }
  my $dafa_hashref = {};
  foreach my $id ( @group_ids, @feature_ids ) {
    foreach my $db ( keys %$dba_hashref ) {
      $dafa_hashref->{$db} ||= $dba_hashref->{$db}->$adapter_call;
      foreach my $logic_name (@logic_names) {
        foreach my $align ( @{$dafa_hashref->{$db}->fetch_all_by_hit_name( $id, $logic_name )} ) {
          $self->_feature( $align );
        }
      }
    }
  }
  push @features, values %{ $self->{'_features'} };
  return \@features;
}


sub _feature {
  my( $self, $feature ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $marker        = $feature->marker;
  my $feature_id    = $marker->display_MarkerSynonym->name;
  my $feature_type  = $marker->display_MarkerSynonym->source;
  my $type          = $feature->analysis->logic_name;
  my $display_label = $feature->analysis->display_label;
  my $slice_name    = $self->slice_cache( $feature->slice );
  my $note_array    = [
    'Mapweight: '.   $feature->map_weight,
    'Left primer: '. $marker->left_primer,
    'Right primer: '.$marker->right_primer,
    'Type: '.        $marker->type
  ];
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $feature_id,
   'LABEL'       => "$feature_id",
   'TYPE'        => "marker:$type:$feature_type",
   'ORIENTATION' => $self->ori($feature->seq_region_strand),
#   'TARGET'      => {
#     'ID'        => $feature_id,
#     'START'     => $feature->hstart,
#     'STOP'      => $feature->hend,
#   },
   'NOTE'        => $note_array,
   'SCORE'       => 0,#$feature->score,
   'METHOD'      => "$type:$feature_type",
   'CATEGORY'    => "$type:$feature_type",
   'START'       => $feature->seq_region_start,
   'END'         => $feature->seq_region_end
  };
## Return the reference to an array of the slice specific hashes.
}

1;
