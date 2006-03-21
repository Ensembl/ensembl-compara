package EnsEMBL::Web::Object::Slice;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);
our %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

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
  my ( $self ) = @_;
  my @snps = @{ $self->Obj->get_all_VariationFeatures() || [] };
  return (0, []) unless scalar @snps;

  my $filtered_snps = $self->filter_snps(\@snps);
  return (scalar @snps, $filtered_snps || []);
}



sub get_genotyped_VariationFeatures {
  my ( $self ) = @_;
  my @snps = @{ $self->Obj->get_all_genotyped_VariationFeatures() || [] };
  return (0, []) unless scalar @snps;

  my $filtered_snps = $self->filter_snps(\@snps);
  return (scalar @snps, $filtered_snps || []);
}


sub filter_snps {
  my ( $self, $snps ) = @_;

  my $valids = $self->valids;
  my @filtered_snps = 
    map  { $_->[1] }               # Remove the schwartzian index
      sort { $a->[0] <=> $b->[0] }   #   Sort snps on schwartzian index

	#  Compute schwartzian index [ consequence type priority, fake SNP ]
	map  { [ $ct{$_->get_consequence_type} * 1e9 + $_->start, $_ ] }

	  # [ fake_s, fake_e, SNP ]   Grep features to see if the area valid
	 grep { ( @{$_->get_all_validation_states()} ?
		  (grep { $valids->{"opt_$_"} } @{$_->get_all_validation_states()} ) :
		  $valids->{'opt_noinfo'} ) }

   # Filter unwanted consequence classifications
    grep { $valids->{'opt_'.lc($_->get_consequence_type()) } }

      # Filter our unwanted sources
      grep { $valids->{'opt_'.lc($_->source)} }

	# Filter our unwanted classes
	grep { $valids->{'opt_'.$_->var_class} }

	  grep { $_->map_weight < 4 }
	    # [ SNP ]  Get all features on slice
	    @$snps;
  return \@filtered_snps;
}

sub filter_munged_snps {
  my ( $self, $snps, $gene ) = @_;
  my $valids = $self->valids;

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
      @$snps;

  return \@filtered_snps;
}

sub getFakeMungedVariationFeatures {
  my ( $self, $subslices, $gene ) = @_;

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
  return ( $count_snps, $self->filter_munged_snps(\@on_slice_snps, $gene) );
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
__END__

=head1 Object::Slice

=head2 SYNOPSIS

This object is called from a Component object


e.g.
 my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();



=head2 DESCRIPTION

This class consists of methods for calls on a slice object.


=head2 METHODS



=head3 B<valids>

Description:    Gets all the user's selected parameters from $self->params()

Arguments:      Proxy::Object (slice)

Returns:        Hashref of options if they are on

Needed for:     Bio::EnsEMBL::GlyphSet::variation.pm,     
                Bio::EnsEMBL::GlyphSet::genotyped_variation.pm
                TranscriptSNPView
                GeneSNPView

Called from:    self


=head3 B<getVariationFeatures>

Description:    Gets all the variation features on this slice.  Calls $self->filter_snps to filter these based on the user's selected parameters

Arguments:      Proxy::Object (slice)

Returns:        The number of SNPs in the array before filtering
                An arrayref of VariationFeature objects after filtering

Needed for:        Bio::EnsEMBL::GlyphSet::variation.pm

Called from:    SNP component


=head3 B<get_genotyped_VariationFeatures>

Description:    Gets all the genotyped variation features on this slice.  Calls $self->filter_snps to filter these based on the user's selected parameters

Arguments:      Proxy::Object (slice)

Returns:        The number of SNPs in the array before filtering
                An arrayref of VariationFeature objects after filtering

Needed for:        Bio::EnsEMBL::GlyphSet::genotyped_variation.pm

Called from:    SNP component


=head3 B<filter_snps>

Description:    Filters SNPs based on the users' selected parameters (which are obtained from $self->valids)

Arguments:      Proxy::Object (slice)
                Array ref of VariationFeature objects

Returns:        An arrayref of VariationFeature objects

Called from:    self


=head3 B<getFakeVariationFeatures>

Description:    Gets all the genotyped variation features on this slice
                From these calls munge_gaps to calculate the positions of the 
                VariationFeatures on a subslice.  The VariationFeatures are 
                also filtered based on the user's selected parameters.  Filters
                consequence types based on a gene if a gene is provided.

Arguments:      Proxy::Object (slice)
                sub slice object
                Gene (optional)

Returns:        An arrayref of [fake_VF_start, fake_VF_end, VariationFeature] objects after filtering

Needed for:     TranscriptSNPView, GeneSNPView

Called from:    Transcript Object, Gene Object



=head3 B<munge_gaps>

Description:    Calculates new positions based on subslice

Arguments:      Proxy::Object (slice)
                sub slice object
                bp1, bp2

Returns:

Needed for:     TranscriptSNPView, GeneSNPView

Called from:    self

