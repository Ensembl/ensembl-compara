package EnsEMBL::Web::Object::DAS::repeat;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => [
			     { 'id' => 'repeat'  }
			     ]
			     }
	  ];
}

sub Features {
  my $self = shift;

  $self->{_feature_label} = 'repeat';
  my @segments      = $self->Locations;
  my %feature_types = map { $_ ? ($_=>1) : () } @{$self->FeatureTypes  || []};
  my @group_ids     = grep { $_ }               @{$self->GroupIDs      || []};
  my @feature_ids   = grep { $_ }               @{$self->FeatureIDs    || []};

  my $dba_hashref;
  my( $db, $logic_name, @repeat_types ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
            $db = 'core'  unless $db;
    $logic_name = undef   unless $logic_name;
  @repeat_types = (undef) unless @repeat_types;
  my @features;
  foreach ($db) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    $dba_hashref->{$_}=$T if $T;
  }
  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $repeat_type (@repeat_types) {
        $repeat_type =~ s/_/ /g;
        $repeat_type =~ s/ ([LS]INE)/\/\1/g;
        foreach my $feature ( @{$segment->slice->get_all_RepeatFeatures($logic_name,$repeat_type,$db_key) } ) {
          $self->_feature( $feature );
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
warn "FEATURE .....";
  my $feature_id    = $feature->display_id;
  my $feature_type  = $feature->repeat_consensus->repeat_type;
  my $feature_class = $feature->repeat_consensus->repeat_class;
  my $type          = $feature->analysis->logic_name;
  my $display_label = $feature->analysis->display_label;
  my $slice_name    = $self->slice_cache( $feature->slice );
  my $consensus     = $feature->repeat_consensus->repeat_consensus;
  my $note_array    = [];
  push @$note_array, "Consensus sequence: $consensus" unless $consensus =~ /^N*$/;
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $feature_id,
   'LABEL'       => "$feature_class: $feature_id",
   'TYPE'        => "repeat:$type:$feature_type",
   'ORIENTATION' => $self->ori($feature->seq_region_strand), 
   'TARGET'      => {
     'ID'        => $feature_id,
     'START'     => $feature->hstart,
     'STOP'      => $feature->hend,
   },
   'NOTE'        => $note_array,
   'SCORE'       => $feature->score,
   'METHOD'      => "$type:$feature_type",
   'CATEGORY'    => "$type:$feature_type",
   'START'       => $feature->seq_region_start,
   'END'         => $feature->seq_region_end,
  };
## Return the reference to an array of the slice specific hashes.
}

1;
