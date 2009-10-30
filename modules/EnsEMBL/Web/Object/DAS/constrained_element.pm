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
			     ]
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



  my $h =  $self->{data}->{_databases}->get_databases('compara');

  if (my $cdb = $h->{'compara'}) {
      my $mlssa = $cdb->get_adaptor('MethodLinkSpeciesSet');
      my $mlss = $mlssa->fetch_all_by_method_link_type("GERP_CONSTRAINED_ELEMENT")->[0];

      if ($mlss) {      
	  my $gdba = $cdb->get_adaptor("GenomeDB");
	  (my $sys_name = $self->species) =~ s/_/ /;
	  my $species_db = $gdba->fetch_by_name_assembly($sys_name); 

	  warn "Species $sys_name :  $species_db";	  

	  if ($species_db) {
	      my $dnafrag_adaptor = $cdb->get_adaptor("DnaFrag");
	      my $constrained_element_adaptor = $cdb->get_adaptor("ConstrainedElement");

	      foreach my $segment (@segments) {
		  if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
		      push @features, $segment;
		      next;
		  }
		  warn "Segment: ", join (' * ', $segment->slice->seq_region_name,$segment->slice->start, $segment->slice->end);

		  my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($species_db, $segment->slice->seq_region_name);

		  my $slice = $dnafrag->slice->sub_Slice($segment->slice->start, $segment->slice->end);

		  warn "QUERY SLICE ($dnafrag * $slice) : ", $slice->name, "\n";

		  my $constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice( $mlss, $slice);
	  
		  warn "E COUNT: ", scalar(@{$constrained_elements || []});
		  foreach my $feature ( @{$constrained_elements || []} ) {
		      $self->_feature( $feature );
		  }
	      }
	      push @features, values %{ $self->{'_features'} };
	  }
      }
  }

  return \@features;
}


sub _feature {
  my( $self, $feature ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $feature_id    = $feature->dbID;

  my $slice_name    = $self->slice_cache( $feature->slice );
  my $note_array    = [];
  my $pvalue = $feature->p_value;
  push @$note_array, "p-value: $pvalue";

  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $feature_id,
   'LABEL'       => $feature_id,
   'TYPE'        => "constrained_element",
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
