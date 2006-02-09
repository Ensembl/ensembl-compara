package EnsEMBL::Web::Object::Slice;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub snp_display {
  my $self = shift; 
  my $value = $self->param('snp_display');
  my $SNPS = [];
  if( $value eq 'snp' ){
    my $slice = $self->Obj();
    eval {
      if( $self->species_defs->databases->{'ENSEMBL_GLOVAR'} ) {
        $self->database('glovar');
        $SNPS = $slice->get_all_ExternalFeatures('GlovarSNP');
      } elsif( $self->species_defs->databases->{'ENSEMBL_VARIATION'} ) {
        $SNPS = $slice->get_all_VariationFeatures;
      }
    };
  }
  return $SNPS;
}

sub exon_display {
  my $self = shift;
  my $exontype = $self->param('exon_display');
  my @exons;
  my( $s, $e ) = ( $self->Obj->start, $self->Obj->end );
  if( $exontype eq 'vega' or $exontype eq 'est' ){
    @exons = ( grep { $_->seq_region_start <= $e && $_->seq_region_end   >= $s }
               map  { @{$_->get_all_Exons } }
               @{ $self->Obj->get_all_Genes('',$exontype) } );
  } elsif( $exontype eq 'prediction' ){
    @exons = ( grep{ $_->seq_region_start<=$e && $_->seq_region_end  >=$s }
               map { @{$_->get_all_Exons } }
               @{$self->Obj->get_all_PredictionTranscripts } );
  } else {
    @exons = @{$self->Obj->get_all_Exons};
  }
  my $ori = $self->param('exon_ori');
  if( $ori eq 'fwd' ) {
    @exons = grep{$_->seq_region_strand > 0} @exons; # Only fwd exons
  } elsif( $ori eq 'rev' ){
    @exons = grep{$_->seq_region_strand < 0} @exons; # Only rev exons
  }
  return \@exons;
}

sub highlight_display {
  my $self = shift;
  if( @_ ){
    my @features = @{$_[0] || []}; # Validate arg list
    map{$_->isa('Bio::EnsEMBL::Feature') or die( "$_ is not a Bio::EnsEMBL::Feature" ) } @features;
    $self->{_highlighted_features} = [@features];
  }
  return( $self->{_highlighted_features} || [] );
}

sub line_numbering {
  my $self  = shift;
  my $linenums = $self->param('line_numbering');
  if( $linenums eq 'sequence' ){ #Relative to sequence
    return( 1, $self->Obj->length );
  } elsif( $linenums eq 'slice' ){ #Relative to slice. May need to invert
    return $self->Obj->strand > 0 ? ( $self->Obj->start, $self->Obj->end ) : ( $self->Obj->end, $self->Obj->start );
  }
  return();
}


sub valids {
  my $self = shift;
  my %valids = ();    ## Now we have to create the snp filter....
  foreach( $self->param() ) {
    $valids{$_} = 1 if $_=~/opt_/ && $self->param( $_ ) eq 'on';
  }
  return \%valids;
}

sub getVariationFeatures {
  my ( $self, $subslices, $gene ) = @_;
  my $valids = $self->valids;

  my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
  my @on_slice_snps = 
# [ fake_s, fake_e, SNP ]   Filter out any SNPs not on munged slice...
    map  { $_->[1]?[$_->[0]->start+$_->[1],$_->[0]->end+$_->[1],$_->[0]]:() } # Filter out anything that misses
# [ SNP, offset ]           Create a munged version of the SNPS
    map  { [$_, $self->munge_gaps( $subslices, $_->start, $_->end)] }    # Map to "fake coordinates"
# [ SNP ]                   Filter out all the multiply hitting SNPs
    grep { $_->map_weight < 4 }
# [ SNP ]                   Get all features on slice
    @{ $self->Obj->get_all_VariationFeatures() };

  my $count_snps = scalar @on_slice_snps;
  return (0, []) unless $count_snps;

  my @filtered_snps =
# [fake_s, fake_e, SNP]              Remove the schwartzian index
    map  { $_->[1] }
# [ index, [fake_s, fake_e, SNP] ]   Sort snps on schwartzian index
    sort { $a->[0] <=> $b->[0] }
# [ index, [fake_s, fake_e, SNP] ]   Compute schwartzian index [ consequence type priority, fake SNP ]
    map  { [ $_->[1] - $ct{$_->[2]->get_consequence_type($gene)} *1e9, $_ ] }
# [ fake_s, fake_e, SNP ]   Grep features to see if the area valid
    grep { ( @{$_->[2]->get_all_validation_states()} ?
           (grep { $valids->{"opt_$_"} } @{$_->[2]->get_all_validation_states()} ) :
           $valids->{'opt_noinfo'} ) }
# [ fake_s, fake_e, SNP ]   Filter our unwanted consequence classifications
    grep { $valids->{'opt_'.lc($_->[2]->get_consequence_type()) } }

# [ fake_s, fake_e, SNP ]   Filter our unwanted sources
    grep { $valids->{'opt_'.lc($_->[2]->source)} }

# [ fake_s, fake_e, SNP ]   Filter our unwanted classes
    grep { $valids->{'opt_'.$_->[2]->var_class} }
      @on_slice_snps;

  return ($count_snps, \@filtered_snps);
}

sub munge_gaps {
  my( $self, $subslices, $bp, $bp2  ) = @_;

  foreach( @$subslices ) {
    if( $bp >= $_->[0] && $bp <= $_->[1] ) {
      my $return =  defined($bp2) && ($bp2 < $_->[0] || $bp2 > $_->[1] ) ? undef : $_->[2] ;
      return $return;
    }
  }
  return undef;
}

1;
