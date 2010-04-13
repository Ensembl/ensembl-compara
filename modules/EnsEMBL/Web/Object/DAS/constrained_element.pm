package EnsEMBL::Web::Object::DAS::constrained_element;

use strict;
use warnings;
use Data::Dumper;
use base qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
          {
              'REGION' => '*',
              'FEATURES' => [
                   { 'id' => 'constrained_element'  }
                   ],
          }
      ];
}

sub Features {
  my $self = shift;

  $self->{_feature_label} = 'constrained_element';
  my @segments      = $self->Locations;
  my %feature_types = map { $_ ? ($_=>1) : () } @{$self->FeatureTypes  || []};
  my @group_ids     = grep { $_ }               @{$self->GroupIDs      || []};
  my @feature_ids   = grep { $_ }               @{$self->FeatureIDs    || []};

  my @features;


  my $constrained_element_hash = $self->{data}->{_species_defs}->multi_hash->
      {'DATABASE_COMPARA'}{CONSTRAINED_ELEMENTS};

  my $h =  $self->{data}->{_databases}->get_databases('compara');

  if (my $cdb = $h->{'compara'}) {

    foreach my $mlss_id (keys %$constrained_element_hash) {
      # Check that we have this MLSS is defined for this species
      next if (!defined($constrained_element_hash->{$mlss_id}->{species}->{$self->species}));

      # Get type and filter features if any type has been selected
      my $type = $constrained_element_hash->{$mlss_id}->{name};
      if ($type =~ /Gerp Constrained Elements \((.+)\)/) {
        $type = $1;
      }
      $type =~ s/\W/_/g;
      next if (%feature_types and !$feature_types{$type});

      (my $sys_name = $self->species) =~ s/_/ /;
      my $gdba = $cdb->get_adaptor("GenomeDB");
      my $species_db = $gdba->fetch_by_name_assembly($sys_name); 

      if ($species_db) {
        my $mlssa = $cdb->get_adaptor('MethodLinkSpeciesSet');
        my $dnafrag_adaptor = $cdb->get_adaptor("DnaFrag");
        my $constrained_element_adaptor = $cdb->get_adaptor("ConstrainedElement");
        foreach my $segment (@segments) {
          if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
            push @features, $segment;
            next;
          }

          my $mlss = $mlssa->fetch_by_dbID($mlss_id);

          my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($species_db, $segment->slice->seq_region_name);

          my $slice = $dnafrag->slice->sub_Slice($segment->slice->start, $segment->slice->end);

          my $constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice( $mlss, $slice);

          foreach my $feature ( @{$constrained_elements || []} ) {
	    $feature->start($feature->start + $segment->slice->start - 1);
	    $feature->end($feature->end + $segment->slice->start - 1);
            $self->_feature( $feature, $type );
          }
        }
      }
    }
    push @features, values %{ $self->{'_features'} };
  }

  return \@features;
}


sub _feature {
  my( $self, $feature, $type ) = @_;

  ## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $feature_id    = $feature->dbID;

  my $slice_name    = $self->slice_cache( $feature->slice );
  my $note_array    = [];
  my $pvalue = $feature->p_value;
  push @$note_array, "p-value: $pvalue" if ($pvalue);

  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
    'ID'          => $feature_id,
    'LABEL'       => $feature_id,
    'TYPE'        => $type,
    'ORIENTATION' => $self->ori($feature->strand), 
    'NOTE'        => $note_array,
    'SCORE'       => $feature->score,
    'METHOD'      => "GERP",
    'START'       => $feature->start,
    'END'         => $feature->end,
  };
  ## Return the reference to an array of the slice specific hashes.
}

1;
