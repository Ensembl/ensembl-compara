package EnsEMBL::Web::Object::Slice;

use strict;
use warnings;
no warnings "uninitialized";
use Data::Dumper;

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);
our %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

### This object is called from a Component object
### e.g.  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();
### This class consists of methods for calls on a slice object.


sub snp_display {

  ### GeneSeqAlignView

  my $self = shift; 
  my $SNPS = [];
  my $slice = $self->Obj();
  eval {
      $SNPS = $slice->get_all_VariationFeatures;
  };

  return $SNPS;
}

sub exon_display {

  ### GeneSeqAlignView

  my $self = shift;
  my $exontype = $self->param('exon_display');
  my @exons;

  my( $slice_start, $slice_end ) = ( $self->Obj->start, $self->Obj->end );

  # Get all exons within start and end for genes of $exontype
  if( $exontype eq 'vega' or $exontype eq 'est' or $exontype eq 'otherfeatures'){
    @exons = ( grep { $_->seq_region_start <= $slice_end && $_->seq_region_end   >= $slice_start }
               map  { @{$_->get_all_Exons } }
               @{ $self->Obj->get_all_Genes('',$exontype) } );
  } elsif( $exontype eq 'Ab-initio' ){
    @exons = ( grep{ $_->seq_region_start<=$slice_end && $_->seq_region_end  >=$slice_start }
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

  ### GeneSeqAlignView

  my $self = shift;
  if( @_ ){
    my @features = @{$_[0] || []}; # Validate arg list
    map{$_->isa('Bio::EnsEMBL::Feature') or die( "$_ is not a Bio::EnsEMBL::Feature" ) } @features;
    $self->{_highlighted_features} = [@features];
  }
  return( $self->{_highlighted_features} || [] );
}

sub line_numbering {

  ### GeneSeqAlignView

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

  ### Arg1 : Web Proxy::Object (slice)
  ### Gets all the user's selected parameters from $self->params()
  ### Returns        Hashref of options with keys as valid options, value = 1 if they are on
  ### Needed for:     Bio::EnsEMBL::GlyphSet::variation.pm,     
  ###                Bio::EnsEMBL::GlyphSet::genotyped_variation.pm
  ###                TranscriptSNPView
  ###                GeneSNPView
  ### Called from:   self

  my $self = shift;
  my %valids = ();    ## Now we have to create the snp filter....
  foreach( $self->param() ) {
    $valids{$_} = 1 if $_=~/opt_/ && $self->param( $_ ) eq 'on';
  }
  return \%valids;
}

sub variation_adaptor {

  ### Fetches the variation adaptor and puts it on the object hash
  my $self = shift;
  unless ( exists $self->{'variation_adaptor'} ) {
    my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
    unless ($vari_adaptor) {
      warn "ERROR: Can't get variation adaptor"; 
    }
    $self->{'variation_adaptor'} = $vari_adaptor;
  }

  return $self->{'variation_adaptor'};
}

sub sources {

 ### Arg1        : Web slice obj
 ### gets all variation sources
 ### Returns hashref with keys as valid options, value = 1

  my $self = shift;
  my $valids = $self->valids;
  my @sources;
  eval {
    @sources = @{ $self->variation_adaptor->get_VariationAdaptor->get_all_sources() || []};
  };
  my %sources = map { $valids->{'opt_'.lc($_)} ? ( $_ => 1 ):()  } @sources;
  %sources = map{( $_ => 1 ) } @sources unless keys %sources;
  return \%sources;
}


sub getVariationFeatures {

  ### Arg1        : Web Proxy::Object (slice)
  ### fetches all variation features on Slice object 
  ### Calls $self->filter_snps to filter these by the user's selected parameters (e.g.type, class etc)
  ### Returns scalar- total number of SNPs in the arry before filtering
  ### Returns arrayref- of VariationFeature objects after filtering
  ### Needed for:        Bio::EnsEMBL::GlyphSet::variation.pm
  ### Called from:   SNP component

  my ( $self ) = @_;
  my @snps = @{ $self->Obj->get_all_VariationFeatures() || [] };
  return (0, []) unless scalar @snps;

  my $filtered_snps = $self->filter_snps(\@snps);
  return (scalar @snps, $filtered_snps || []);
}



sub get_genotyped_VariationFeatures {

  ### Arg1        : Web Proxy::Object (slice)
  ### fetches all variation features on Slice object 
  ### Calls $self->filter_snps to filter these by the user's selected parameters (e.g.type, class etc)
  ### Returns scalar- total number of SNPs in the arry before filtering
  ### Returns arrayref- of VariationFeature objects after filtering
  ### Needed for: Bio::EnsEMBL::GlyphSet::genotyped_variation.pm
  ### Called from:  SNP component

  my ( $self ) = @_;
  my @snps = @{ $self->Obj->get_all_genotyped_VariationFeatures() || [] };
  return (0, []) unless scalar @snps;

  my $filtered_snps = $self->filter_snps(\@snps);
  return (scalar @snps, $filtered_snps || []);
}



sub filter_snps {

  ### Arg1        : Web Proxy::Object (slice)
  ### Arg2        : arrayref VariationFeature objects
  ### Example     : Called from within
  ### filters snps based on users' selected parameters (which are obtained from $self->valids)
  ### e.g. on source, conseq type, validation etc
  ### Returns An arrayref of VariationFeature objects

  my ( $self, $snps ) = @_;
  my $sources = $self->sources;
  my $valids  = $self->valids;
  my @filtered_snps = 
    map  { $_->[1] }               # Remove the schwartzian index
      sort { $a->[0] <=> $b->[0] }   #   Sort snps on schwartzian index

	#  Compute schwartzian index [ consequence type priority, fake SNP ]
	map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }

	  # [ fake_s, fake_e, SNP ]   Grep features to see if the area valid
	 grep { ( @{$_->get_all_validation_states()} ?
		  (grep { $valids->{"opt_$_"} } @{$_->get_all_validation_states()} ) :
		  $valids->{'opt_noinfo'} ) }

   # Filter unwanted consequence classifications
    grep { scalar map { $valids->{'opt_'.lc($_)}?1:() } @{$_->get_consequence_type()}  }

      # Filter our unwanted sources
      grep { scalar map { $sources->{$_} ?1:() } @{$_->get_all_sources()}  }
      #grep { $valids->{'opt_'.lc($_->source)} }

	# Filter our unwanted classes
	grep { $valids->{'opt_'.$_->var_class} }

	  grep { $_->map_weight < 4 }
	    # [ SNP ]  Get all features on slice
	    @$snps;
  return \@filtered_snps;
}



sub getFakeMungedVariationFeatures {

  ### Arg1        : Web slice obj
  ### Arg2        : Subslices
  ### Arg3        : Optional: gene
  ### Example     : Called from {{EnsEMBL::Web::Object::Transcript.pm}} for TSV
  ### Gets SNPs on slice for display + counts
  ### Returns scalar - number of SNPs on slice post context filtering, prior to other filters
  ### arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]
  ### scalar - number of SNPs filtered out by the context filter

  my ( $self, $subslices, $gene ) = @_;
  my $all_snps = $self->Obj->get_all_VariationFeatures();

  my @on_slice_snps = 
# [ fake_s, fake_e, SNP ]   Filter out any SNPs not on munged slice...
    map  { $_->[1]?[$_->[0]->start+$_->[1],$_->[0]->end+$_->[1],$_->[0]]:() } # Filter out anything that misses
# [ SNP, offset ]           Create a munged version of the SNPS
    map  { [$_, $self->munge_gaps( $subslices, $_->start, $_->end)] }    # Map to "fake coordinates"
# [ SNP ]                   Filter out all the multiply hitting SNPs
    grep { $_->map_weight < 4 }
# [ SNP ]                   Get all features on slice
    @{ $all_snps };

  my $count_snps = scalar @on_slice_snps;
  my $filtered_context_snps = scalar @$all_snps - $count_snps;
  return (0, [], $filtered_context_snps) unless $count_snps;
  return ( $count_snps, $self->filter_munged_snps(\@on_slice_snps, $gene), $filtered_context_snps );
}


sub munge_gaps {

  ### Needed for  : TranscriptSNPView, GeneSNPView
  ### Arg1        : Proxy::Object (slice)
  ### Arg2        : Subslices
  ### Arg3        : bp position 1: start
  ### Arg4        : bp position 2: end
  ### Example     : Called from within
  ### Description:  Calculates new positions based on subslice

  my( $self, $subslices, $bp, $bp2  ) = @_;

  foreach( @$subslices ) {
    if( $bp >= $_->[0] && $bp <= $_->[1] ) {
      my $return =  defined($bp2) && ($bp2 < $_->[0] || $bp2 > $_->[1] ) ? undef : $_->[2] ;
      return $return;
    }
  }
  return undef;
}


sub filter_munged_snps {

 ### Arg1        : Web slice obj
 ### Arg2        : arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]
 ### Arg3        : gene (optional)
 ### Example     : Called from within
 ### filters 'fake snps' based on source, conseq type, validation etc
 ### Returns arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]

  my ( $self, $snps, $gene ) = @_;
  my $valids = $self->valids;
  my $sources = $self->sources;

  my @filtered_snps =
# [fake_s, fake_e, SNP]              Remove the schwartzian index
    map  { $_->[1] }
# [ index, [fake_s, fake_e, SNP] ]   Sort snps on schwartzian index
    sort { $a->[0] <=> $b->[0] }
# [ index, [fake_s, fake_e, SNP] ]   Compute schwartzian index [ consequence type priority, fake SNP ]
    map  { [ $_->[1] - $ct{$_->[2]->display_consequence($gene)} *1e9, $_ ] }
# [ fake_s, fake_e, SNP ]   Grep features to see if the area valid
    grep { ( @{$_->[2]->get_all_validation_states()} ?
           (grep { $valids->{"opt_$_"} } @{$_->[2]->get_all_validation_states()} ) :
           $valids->{'opt_noinfo'} ) }
# [ fake_s, fake_e, SNP ]   Filter our unwanted consequence classifications
    grep { scalar map { $valids->{'opt_'.lc($_)}?1:() } @{$_->[2]->get_consequence_type()}  }

# [ fake_s, fake_e, SNP ]   Filter our unwanted sources
      #grep { $valids->{'opt_'.lc($_->[2]->source)} }
      grep { scalar map { $sources->{$_} ?1:() } @{$_->[2]->get_all_sources()}  }

# [ fake_s, fake_e, SNP ]   Filter our unwanted classes
    grep { $valids->{'opt_'.$_->[2]->var_class} }
      @$snps;

  return \@filtered_snps;
}

# Sequence Align View ---------------------------------------------------

sub get_individuals {

  ### SequenceAlignView
  ### Arg (optional) : type string
  ###  -"default": returns samples checked by default
  ###  -"reseq": returns all resequencing sames
  ###  -"reference": returns the reference (golden path name)
  ###  -"display": returns all samples (for dropdown list) with default ones first
  ### Description: returns selected samples (by default)
  ### Returns list

  my $self    = shift;
  my $options = shift;
  my $individual_adaptor;
  eval {
     $individual_adaptor = $self->variation_adaptor->get_IndividualAdaptor;
   };
  if ($@) {
    warn "Error getting individual adaptor off variation adaptor ", $self->variation_adaptor;
    return ();
  }

  if ($options eq 'default') {
    return sort  @{$individual_adaptor->get_default_strains};
  }
  elsif ($options eq 'reseq') {
    return @{$individual_adaptor->fetch_all_strains_with_coverage};
  }
  elsif ($options eq 'reference') {
    return $individual_adaptor->get_reference_strain_name();
  }

  my %default_pops;
  map {$default_pops{$_} = 1 } @{$individual_adaptor->get_default_strains};
  my %db_pops;
  foreach ( sort  @{$individual_adaptor->get_display_strains} ) {
    next if $default_pops{$_};
    $db_pops{$_} = 1;
  }

  if ($options eq 'display') { # return list of pops with default first
    return (sort keys %default_pops), (sort keys %db_pops);
  }
  return ();
}



1;







