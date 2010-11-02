# $Id$

package EnsEMBL::Web::Object::Slice;

### NAME: EnsEMBL::Web::Object::Slice
### Wrapper around a Bio::EnsEMBL::Slice object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION
### This is a 'helper' object which is created by other objects
### when a slice is needed
### e.g.  my ($count_snps, $filtered_snps) = $sliceObj->getVariationFeatures();

use strict;

use base qw(EnsEMBL::Web::Object);

our %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

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

  my ($self, $snps) = @_;
  my $sources = $self->sources;
  my $valids  = $self->valids;
  
  my @filtered_snps = 
    map  { $_->[1] }                                                                      # Remove the schwartzian index
    sort { $a->[0] <=> $b->[0] }                                                          # Sort snps on schwartzian index
	  map  {[ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ]}                         # Compute schwartzian index [ consequence type priority, fake SNP ] 
	  grep {( @{$_->get_all_validation_states} ?
		  (grep { $valids->{"opt_$_"} } @{$_->get_all_validation_states}) :
		  $valids->{'opt_noinfo'}
		)}                                                                                    # [ fake_s, fake_e, SNP ] Grep features to see if the area valid
    grep { scalar map { $valids->{'opt_'. lc $_} ? 1 : () } @{$_->get_consequence_type} } # Filter unwanted consequence classifications
    grep { scalar map { $sources->{$_} ? 1 : () } @{$_->get_all_sources} }                # Filter our unwanted sources
	  grep { $valids->{'opt_class_' . $_->var_class} }                                      # Filter our unwanted classes
	  grep { $_->map_weight < 4 }
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
  push @$all_snps, @{$self->Obj->get_all_somatic_VariationFeatures()};

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

  my ($self, $snps, $gene) = @_;
  my $valids  = $self->valids;
  my $sources = $self->sources;

  my @filtered_snps =
    map  { $_->[1] }                                                                            # [fake_s, fake_e, SNP] Remove the schwartzian index
    sort { $a->[0] <=> $b->[0] }                                                                # [ index, [fake_s, fake_e, SNP] ] Sort snps on schwartzian index
    map  {[ $_->[1] - $ct{$_->[2]->display_consequence($gene)} * 1e9, $_ ]}                     # [ index, [fake_s, fake_e, SNP] ] Compute schwartzian index [ consequence type priority, fake SNP ]
    grep {( @{$_->[2]->get_all_validation_states} ? 
      (grep { $valids->{"opt_$_"} } @{$_->[2]->get_all_validation_states}) : 
      $valids->{'opt_noinfo'}
    )}                                                                                          # [ fake_s, fake_e, SNP ] Grep features to see if they are valid
    grep { scalar map { $valids->{'opt_' . lc $_} ? 1 : () } @{$_->[2]->get_consequence_type} } # [ fake_s, fake_e, SNP ] Filter our unwanted consequence types
    grep { scalar map { $sources->{$_} ? 1 : () } @{$_->[2]->get_all_sources} }                 # [ fake_s, fake_e, SNP ] Filter our unwanted sources
    grep { $valids->{'opt_class_' . $_->[2]->var_class} }                                       # [ fake_s, fake_e, SNP ] Filter our unwanted classes
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


# Cell line Data retrieval  ---------------------------------------------------
sub get_cell_line_data {
  my ($self, $image_config) = @_;
  
  # First work out which tracks have been turned on in image_config
  my %cell_lines        =  %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};

  my @types = ('core', 'other');  
  my %data;

  foreach my $cell_line (keys %cell_lines){ 
    $cell_line =~s/\:\d*//;    
    foreach my $type (@types){
      next unless $image_config->get_node('functional')->get_node('reg_feats_'.$type.'_'.$cell_line);
      my $display = $image_config->get_node('functional')->get_node('reg_feats_'.$type.'_'.$cell_line)->get('display');
      if( $display ne 'off') { $data{$cell_line}{$type}{'renderer'} = $display; }
    }
  }

  %data = %{$self->get_configured_tracks($image_config, \%data)}; 
  %data = %{$self->get_data(\%data)};

  return \%data;
}

sub get_configured_tracks {
  my ($self, $image_config, $data) = @_;
  my $hub               = $self->hub;
  my $tables            = $hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'};
  my %cell_lines        = %{$tables->{'cell_type'}{'ids'}};
  my %evidence_features = %{$tables->{'feature_type'}{'ids'}};
  my %focus_set_ids     = %{$tables->{'meta'}{'focus_feature_set_ids'}};
  my %feature_type_ids  = %{$tables->{'meta'}{'feature_type_ids'}};
  my $page_object       = $hub->type; 
  my $view_config       = $hub->get_viewconfig($page_object, 'Cell_line');
  
  foreach my $cell_line (keys %cell_lines) { 
    $cell_line =~ s/\:\d*//; 
    next if !exists $data->{$cell_line};    

    foreach my $evidence_feature (keys %evidence_features) { 
      my ($feature_name, $feature_id ) = split /\:/, $evidence_feature; 
      
      if (exists $feature_type_ids{$cell_line}{$feature_id}) {  
        my $focus_flag = $cell_line eq 'MultiCell' || exists $focus_set_ids{$cell_line}{$feature_id} ? 'core' : 'other';
        next if ! exists $data->{$cell_line}->{$focus_flag};
        
        if (!exists $data->{$cell_line}{$focus_flag}{'available'}) {
           $data->{$cell_line}{$focus_flag}{'available'}   = [];
           $data->{$cell_line}{$focus_flag}{'configured'}  = [];
        }
        
        push @{$data->{$cell_line}{$focus_flag}{'available'}},  $feature_name; 
        push @{$data->{$cell_line}{$focus_flag}{'configured'}}, $feature_name if $view_config->get("opt_cft_$cell_line:$feature_name") eq 'on'; # add to configured features if turned on
      }
    }
  }
  
  return $data;
}

sub get_data {
  my ($self, $data) = @_;
  my $hub           = $self->hub;
  my $page_object   = $self->hub->type;
  my $view_config   = $hub->get_viewconfig($page_object, 'Cell_line');
  my $dset_a        = $hub->get_adaptor('get_DataSetAdaptor', 'funcgen');
  my @result_sets;

  # If on regulation page do we show all data or just used to build reg feature?
  my $associated_data_only  = $view_config->get('opt_associated_data_only') eq 'yes' ? 1 : undef; 
  my $reg_object;
  if ($associated_data_only ){
    $reg_object = $self->hub->{'_core_objects'}->{'regulation'};
  }


  foreach my $regf_fset (@{$hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen')->fetch_all_by_type('regulatory')}) { 
    my $regf_data_set = $dset_a->fetch_by_product_FeatureSet($regf_fset);
    my $cell_line     = $regf_data_set->cell_type->name;

    next unless exists $data->{$cell_line};

    foreach my $reg_attr_fset (@{$regf_data_set->get_supporting_sets}) {   
      my $unique_feature_set_id = $reg_attr_fset->cell_type->name . ':' . $reg_attr_fset->feature_type->name; 
      my $name = "opt_cft_$unique_feature_set_id";
      my $type = $reg_attr_fset->is_focus_set ? 'core' : 'other';

      if ( $cell_line eq 'MultiCell'){
        $name = 'opt_cft_' . $cell_line . ':' . $reg_attr_fset->feature_type->name;
      }

      if ($view_config->get($name) eq 'on') { 
        my $display_style = $data->{$cell_line}{$type}{'renderer'};
        if ($display_style  eq 'compact' || $display_style eq 'tiling_feature') {
          my @block_features = @{$reg_attr_fset->get_Features_by_Slice($self->Obj)};
          if ($reg_object && scalar @block_features >> 0){
            my @temp_block_features;
            foreach my $annotated_feature( @block_features ){ 
             push (@temp_block_features, $annotated_feature) if $reg_object->Obj->has_attribute($annotated_feature->dbID, 'annotated');   
            }
            @block_features = @temp_block_features;
          }  
          $data->{$cell_line}{$type}{'block_features'}{$unique_feature_set_id} = \@block_features if scalar @block_features;
        } if ($display_style eq 'tiling' || $display_style eq 'tiling_feature') {
          my $reg_attr_dset = $dset_a->fetch_by_product_FeatureSet($reg_attr_fset); 
          my $sset          = $reg_attr_dset->get_displayable_supporting_sets('result');

          # There should only be one
          throw("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t" . $reg_attr_dset->name) if scalar @$sset > 1;
          push (@result_sets, $sset->[0]) if scalar @$sset;
          $name =~s/opt_cft_//;
          $data->{$cell_line}{$type}{'wiggle_features'}{$name} = 1 if scalar @$sset;
        }
      }
    }  
  }

  # retrieve all the data to draw wiggle plots
  if (scalar @result_sets >> 0) {   
    my $resultfeature_adaptor = $hub->get_adaptor('get_ResultFeatureAdaptor', 'funcgen');
    my $max_bins =  $ENV{'ENSEMBL_IMAGE_WIDTH'} - 228; 
    my $wiggle_data = $resultfeature_adaptor->fetch_all_by_Slice_ResultSets($self->Obj, \@result_sets, $max_bins);
    foreach my $rset_id ( keys %{$wiggle_data} ){ 
      my $rs = $hub->get_adaptor('get_ResultSetAdaptor', 'funcgen')->fetch_by_dbID($rset_id); 
      my $unique_feature_set_id = $rs->cell_type->name . ':' .$rs->feature_type->name;        
      my $features = $wiggle_data->{$rset_id};   
      $data->{'wiggle_data'}{$unique_feature_set_id} = $features;
    }
  }      

  return $data;
}


1;







