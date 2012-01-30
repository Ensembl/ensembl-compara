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

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::Object);

sub consequence_types { return $_[0]->{'consequence_types'} ||= { map { $_->display_term => $_->rank } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES }; }

sub valids {
  ### Gets all the user's selected parameters from $self->params()
  ### Returns        Hashref of options with keys as valid options, value = 1 if they are on
  ### Needed for:     Bio::EnsEMBL::GlyphSet::variation.pm,     
  ###                Bio::EnsEMBL::GlyphSet::genotyped_variation.pm
  ###                TranscriptSNPView
  ###                GeneSNPView
  ### Called from:   self

  my $self = shift;
  my $hub  = $self->hub;
  my %valids;
  
  foreach ($hub->param) {
    $valids{$_} = 1 if $_=~ /opt_/ && $hub->param($_) eq 'on';
  }
  
  return \%valids;
}

sub variation_adaptor {
  ### Fetches the variation adaptor and puts it on the object hash
  
  my $self = shift;
  
  if (!exists $self->{'variation_adaptor'}) {
    my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
    
    warn "ERROR: Can't get variation adaptor" unless $vari_adaptor;
    
    $self->{'variation_adaptor'} = $vari_adaptor;
  }
  
  return $self->{'variation_adaptor'};
}

sub sources {
 ### Gets all variation sources
 ### Returns hashref with keys as valid options, value = 1

  my $self   = shift;
  my $valids = $self->valids;
  my @sources;
  
  eval {
    @sources = @{$self->variation_adaptor->get_VariationAdaptor->get_all_sources || []};
  };
  
  my %sources = map { $valids->{'opt_' . lc $_} ? ($_ => 1) : () } @sources;
     %sources = map { $_ => 1 } @sources unless keys %sources;
     
  return \%sources;
}

sub getFakeMungedVariationFeatures {
  ### Arg1        : Subslices
  ### Arg2        : Optional: gene
  ### Example     : Called from {{EnsEMBL::Web::Object::Transcript.pm}} for TSV
  ### Gets SNPs on slice for display + counts
  ### Returns scalar - number of SNPs on slice post context filtering, prior to other filters
  ### arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]
  ### scalar - number of SNPs filtered out by the context filter

  my ($self, $subslices, $gene) = @_;
  my $all_snps = $self->Obj->get_all_VariationFeatures;
  push @$all_snps, @{$self->Obj->get_all_somatic_VariationFeatures};

  my @on_slice_snps = 
    map  { $_->[1] ? [ $_->[0]->start + $_->[1], $_->[0]->end + $_->[1], $_->[0] ] : () } # [ fake_s, fake_e, SNP ] Filter out any SNPs not on munged slice
    map  {[ $_, $self->munge_gaps($subslices, $_->start, $_->end) ]}                      # [ SNP, offset ]         Create a munged version of the SNPS
    grep { $_->map_weight < 4 }                                                           # [ SNP ]                 Filter out all the multiply hitting SNPs
    @$all_snps;

  my $count_snps            = scalar @on_slice_snps;
  my $filtered_context_snps = scalar @$all_snps - $count_snps;
  
  return (0, [], $filtered_context_snps) unless $count_snps;
  return ($count_snps, $self->filter_munged_snps(\@on_slice_snps, $gene), $filtered_context_snps);
}

sub munge_gaps {
  ### Needed for  : TranscriptSNPView, GeneSNPView
  ### Arg1        : Subslices
  ### Arg2        : bp position 1: start
  ### Arg3        : bp position 2: end
  ### Example     : Called from within
  ### Description : Calculates new positions based on subslice
  
  my ($self, $subslices, $bp, $bp2) = @_;

  foreach (@$subslices) {
    return defined $bp2 && ($bp2 < $_->[0] || $bp2 > $_->[1]) ? undef : $_->[2] if $bp >= $_->[0] && $bp <= $_->[1];
  }
  
  return undef;
}

sub filter_munged_snps {
  ### Arg1        : arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]
  ### Arg2        : gene (optional)
  ### Example     : Called from within
  ### filters 'fake snps' based on source, conseq type, validation etc
  ### Returns arrayref of munged 'fake snps' = [ fake_s, fake_e, SNP ]

  my ($self, $snps, $gene) = @_;
  my $valids            = $self->valids;
  my $sources           = $self->sources;
  my $consequence_types = $self->consequence_types;

  my @filtered_snps =
    map  { $_->[1] }                                                                         # [ fake_s, fake_e, SNP ] Remove the schwartzian index
    sort { $a->[0] <=> $b->[0] }                                                             # [ index, [fake_s, fake_e, SNP] ] Sort snps on schwartzian index
    map  {[ $_->[1] + $consequence_types->{$_->[2]->display_consequence($gene)} * 1e9, $_ ]} # [ index, [fake_s, fake_e, SNP] ] Compute schwartzian index [ consequence type priority, fake SNP ]
    grep {( @{$_->[2]->get_all_validation_states} ? 
      (grep { $valids->{"opt_$_"} } @{$_->[2]->get_all_validation_states}) : 
      $valids->{'opt_noinfo'}
    )}                                                                                       # [ fake_s, fake_e, SNP ] Grep features to see if they are valid
    grep { scalar map { $valids->{'opt_' . lc $_} ? 1 : () } @{$_->[2]->consequence_type} }  # [ fake_s, fake_e, SNP ] Filter our unwanted consequence types
    grep { scalar map { $sources->{$_} ? 1 : () } @{$_->[2]->get_all_sources} }              # [ fake_s, fake_e, SNP ] Filter our unwanted sources
    grep { $valids->{'opt_class_' . lc $_->[2]->var_class} }                                 # [ fake_s, fake_e, SNP ] Filter our unwanted classes
    @$snps;

  return \@filtered_snps;
}

# Sequence Align View ---------------------------------------------------

sub get_individuals {
  ### SequenceAlignView
  ### Arg (optional) : type string
  ###  - "default"   : returns samples checked by default
  ###  - "reseq"     : returns all resequencing sames
  ###  - "reference" : returns the reference (golden path name)
  ###  - "display"   : returns all samples (for dropdown list) with default ones first
  ### Description    : returns selected samples (by default)
  ### Returns list

  my $self    = shift;
  my $options = shift;
  my $individual_adaptor;
  
  eval {
   $individual_adaptor = $self->variation_adaptor->get_IndividualAdaptor;
  };
  
  if ($@) {
    warn "Error getting individual adaptor off variation adaptor " . $self->variation_adaptor;
    return ();
  }

  if ($options eq 'default') {
    return sort  @{$individual_adaptor->get_default_strains};
  } elsif ($options eq 'reseq') {
    return @{$individual_adaptor->fetch_all_strains_with_coverage};
  } elsif ($options eq 'reference') {
    return $individual_adaptor->get_reference_strain_name;
  }

  my %default_pops;
  map { $default_pops{$_} = 1 } @{$individual_adaptor->get_default_strains};
  my %db_pops;
  
  foreach (sort  @{$individual_adaptor->get_display_strains}) {
    next if $default_pops{$_};
    $db_pops{$_} = 1;
  }

  return (sort keys %default_pops), (sort keys %db_pops) if $options eq 'display'; # return list of pops with default first
  return ();
}


# Cell line Data retrieval  ---------------------------------------------------
sub get_cell_line_data {
  my ($self, $image_config) = @_;
  
  # First work out which tracks have been turned on in image_config
  my %cell_lines = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  my @types      = ('core', 'other');  
  my %data;

  foreach my $cell_line (keys %cell_lines){ 
    $cell_line =~ s/\:\d*//;   
    
    foreach my $type (@types) {
      my $node = $image_config->get_node('functional')->get_node("reg_feats_${type}_$cell_line");
      
      next unless $node;
      
      my $display = $node->get('display');
      $data{$cell_line}{$type}{'renderer'} = $display if $display ne 'off';
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
  
  foreach my $cell_line (keys %cell_lines) { 
    $cell_line =~ s/\:\d*//; 
    next if !exists $data->{$cell_line};    

    foreach my $evidence_feature (keys %evidence_features) { 
      my ($feature_name, $feature_id) = split /\:/, $evidence_feature; 
      
      if (exists $feature_type_ids{$cell_line}{$feature_id}) {  
        my $focus_flag = $cell_line eq 'MultiCell' || exists $focus_set_ids{$cell_line}{$feature_id} ? 'core' : 'other';
        next if ! exists $data->{$cell_line}->{$focus_flag};
        
        if (!exists $data->{$cell_line}{$focus_flag}{'available'}) {
           $data->{$cell_line}{$focus_flag}{'available'}   = [];
           $data->{$cell_line}{$focus_flag}{'configured'}  = [];
        }
        
        push @{$data->{$cell_line}{$focus_flag}{'available'}},  $feature_name; 
        push @{$data->{$cell_line}{$focus_flag}{'configured'}}, $feature_name if $hub->param("opt_cft_$cell_line:$feature_name") eq 'on'; # add to configured features if turned on
      }
    }
  }
  
  return $data;
}

sub get_data {
  my ($self, $data) = @_;
  my $hub                  = $self->hub;
  my $dataset_adaptor      = $hub->get_adaptor('get_DataSetAdaptor', 'funcgen');
  my $associated_data_only = $hub->param('opt_associated_data_only') eq 'yes' ? 1 : undef; # If on regulation page do we show all data or just used to build reg feature?
  my $reg_object           = $associated_data_only ? $hub->core_objects->{'regulation'} : undef;
  my $count                = 0;
  my @result_sets;
  my %feature_sets_on;
  
  foreach my $regf_fset (@{$hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen')->fetch_all_by_type('regulatory')}) { 
    my $regf_data_set = $dataset_adaptor->fetch_by_product_FeatureSet($regf_fset);
    my $cell_line     = $regf_data_set->cell_type->name;

    next unless exists $data->{$cell_line};

    foreach my $reg_attr_fset (@{$regf_data_set->get_supporting_sets}) {
      my $feature_type_name     = $reg_attr_fset->feature_type->name;
      my $unique_feature_set_id = $reg_attr_fset->cell_type->name . ':' . $feature_type_name; 
      my $name                  = $cell_line eq 'MultiCell' ? "opt_cft_$cell_line:$feature_type_name" : "opt_cft_$unique_feature_set_id";
      
      $count++;
      
      next unless $hub->param($name) eq 'on';
      
      my $type          = $reg_attr_fset->is_focus_set ? 'core' : 'other';
      my $display_style = $data->{$cell_line}{$type}{'renderer'};
      
      $feature_sets_on{$feature_type_name} = 1;
      
      if ($display_style  eq 'compact' || $display_style eq 'tiling_feature') {
        my @block_features = @{$reg_attr_fset->get_Features_by_Slice($self->Obj)};
        
        if ($reg_object && scalar @block_features) {
          my $obj = $reg_object->Obj;
          @block_features = grep $obj->has_attribute($_->dbID, 'annotated'), @block_features
        }
        
        $data->{$cell_line}{$type}{'block_features'}{"$unique_feature_set_id:$count"} = \@block_features if scalar @block_features;
      }
      
      if ($display_style eq 'tiling' || $display_style eq 'tiling_feature') {
        my $reg_attr_dset = $dataset_adaptor->fetch_by_product_FeatureSet($reg_attr_fset); 
        my $sset          = $reg_attr_dset->get_displayable_supporting_sets('result');
        
        if (scalar @$sset) {
          # There should only be one
          throw("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t" . $reg_attr_dset->name) if scalar @$sset > 1;
          
          push @result_sets, $sset->[0];
          $data->{$cell_line}{$type}{'wiggle_features'}{$unique_feature_set_id .":". $sset->[0]->dbID} = 1;
        }
      }
    }
  }

  # retrieve all the data to draw wiggle plots
  if (scalar @result_sets > 0) {   
    my $resultfeature_adaptor = $hub->get_adaptor('get_ResultFeatureAdaptor', 'funcgen');
    my $max_bins              = $ENV{'ENSEMBL_IMAGE_WIDTH'} - 228; 
    my $wiggle_data           = $resultfeature_adaptor->fetch_all_by_Slice_ResultSets($self->Obj, \@result_sets, $max_bins);
    
    foreach my $rset_id (keys %$wiggle_data) { 
      my $results_set           = $hub->get_adaptor('get_ResultSetAdaptor', 'funcgen')->fetch_by_dbID($rset_id);
      my $unique_feature_set_id = $results_set->cell_type->name . ':' . $results_set->feature_type->name .":". $results_set->dbID;
      my $features              = $wiggle_data->{$rset_id};
      
      $data->{'wiggle_data'}{$unique_feature_set_id} = $features;
    }
  }      
  
  $data->{'colours'} = \%feature_sets_on;
  
  return $data;
}

1;
