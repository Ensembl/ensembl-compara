=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  ### Needed for:    EnsEMBL::Draw::GlyphSet::variation.pm,     
  ###                EnsEMBL::Draw::GlyphSet::genotyped_variation.pm
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

  my %sources;
  foreach my $source (@sources) {
    my $source_vkey = $source;
    $source_vkey =~ s/ /_/g;
    if (exists($valids->{'opt_' . lc $source_vkey})) {
      $sources{$source} = 1;
    }
  }

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

  my ($self, $subslices, $gene, $so_terms) = @_;
  
  if ($so_terms) {
    my $vfa = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation');
    $vfa->{_ontology_adaptor} ||= $self->hub->get_databases('go')->{'go'}->get_OntologyTermAdaptor;
  }
  my $all_snps = $self->Obj->get_all_VariationFeatures($so_terms);
  my $ngot =  scalar(@$all_snps);
  push @$all_snps, @{$self->Obj->get_all_somatic_VariationFeatures()};

  my @on_slice_snps = 
    map  { $_->[1] ? [ $_->[0]->start + $_->[1], $_->[0]->end + $_->[1], $_->[0] ] : () } # [ fake_s, fake_e, SNP ] Filter out any SNPs not on munged slice
    map  {[ $_, $self->munge_gaps($subslices, $_->start, $_->end) ]}                      # [ SNP, offset ]         Create a munged version of the SNPS
    grep { $_->map_weight < 4 }                                                           # [ SNP ]                 Filter out all the multiply hitting SNPs
    @$all_snps;
    
  my $count_snps            = scalar @on_slice_snps;
  my $filtered_context_snps = scalar @$all_snps - $count_snps;
  
  return (0, [], $filtered_context_snps) unless $count_snps;
  
  my $filtered_snps = $self->filter_munged_snps(\@on_slice_snps, $gene);
  return ($count_snps, $filtered_snps, $filtered_context_snps);
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

sub make_all_source_opt_hash {
  my $self   = shift;
  my @sources;
  my %allsources;

  eval {
    @sources = @{$self->variation_adaptor->get_VariationAdaptor->get_all_sources || []};
  };
  foreach my $source (@sources) {
    $source =~ s/ /_/g;
    $allsources{'opt_' . lc $source} = 1;
  }
     
  return \%allsources;
}

sub need_source_filter {
  my $self   = shift;
  my $valids = $self->valids;
  my $allsources;
  
  $allsources = $self->make_all_source_opt_hash();
  
  foreach my $sourcekey (keys %$allsources) {
    if (!exists($valids->{$sourcekey})) { 
      return 1;
    }
  }
     
  return 0;
}

sub need_consequence_filter {
  my( $self ) = @_;

  my %options =  EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  my $hub  = $self->hub;

  foreach ($hub->param) {
    if ($hub->param($_) eq 'off' && $_ =~ /opt_/ && exists($options{'type'}{$_})) {
      return 1;
    }
  }

  return 0;
}

sub need_validation_filter {
  my( $self ) = @_;

  my %options =  EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  my $hub  = $self->hub;

  foreach ($hub->param) {
    if ($hub->param($_) eq 'off' && $_ =~ /opt_/ && exists($options{'variation'}{$_})) {
      return 1;
    }
  }

  return 0;
}

sub need_class_filter {
  my( $self ) = @_;

  my %options =  EnsEMBL::Web::Constants::VARIATION_OPTIONS;

  my $hub  = $self->hub;

  foreach ($hub->param) {
    if ($hub->param($_) eq 'off' && $_ =~ /opt_/ && exists($options{'class'}{$_})) {
      return 1;
    }
  }

  return 0;
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

  my $needvalidation  = $self->need_validation_filter();
  my $needconsequence = $self->need_consequence_filter();
  my $needclass       = $self->need_class_filter();

  my $needsource      = $self->need_source_filter();
  
  if (!$needvalidation && !$needsource && !$needconsequence && !$needclass) {
    return $snps;
  } else {

    my @filtered_snps = @$snps;

    if ($needsource) {
      @filtered_snps =
 # Will said to change this to ->source (get_all_sources does a db query for each one - not good!).       grep { scalar map { $sources->{$_} ? 1 : () } @{$_->[2]->get_all_sources} }              # [ fake_s, fake_e, SNP ] Filter our unwanted sources
        grep { $sources->{$_->[2]->source} }                                 # [ fake_s, fake_e, SNP ] Filter our unwanted classes
        @filtered_snps;
    }
 
    if ($needvalidation) {
      @filtered_snps =
        grep {( @{$_->[2]->get_all_validation_states} ? 
          (grep { $valids->{"opt_" . lc $_} } @{$_->[2]->get_all_validation_states}) : 
          $valids->{'opt_noinfo'}
        )} @filtered_snps;                                                                                      # [ fake_s, fake_e, SNP ] Grep features to see if they are valid
    }
    if ($needconsequence) {
      @filtered_snps =
        grep { scalar map { $valids->{'opt_' . lc $_} ? 1 : () } @{$_->[2]->consequence_type} }  # [ fake_s, fake_e, SNP ] Filter our unwanted consequence types
        @filtered_snps;
    }
    if ($needclass) {
      @filtered_snps =
        grep { $valids->{'opt_class_' . lc $_->[2]->var_class} }                                 # [ fake_s, fake_e, SNP ] Filter our unwanted classes
        @filtered_snps;
    }
    
    return \@filtered_snps;
  }
}

# Sequence Align View ---------------------------------------------------

sub get_samples {
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
  my $sample_adaptor;
  
  eval {
   $sample_adaptor = $self->variation_adaptor->get_SampleAdaptor;
  };
  
  if ($@) {
    warn "Error getting sample adaptor off variation adaptor " . $self->variation_adaptor;
    return ();
  }
  
  if ($options eq 'default') {
    return sort  @{$sample_adaptor->get_default_strains};
  } elsif ($options eq 'reseq') {
    return @{$sample_adaptor->fetch_all_strains};
  } elsif ($options eq 'reference') {
    return $sample_adaptor->get_reference_strain_name || $self->species;
  }

  my %default_pops;
  map { $default_pops{$_} = 1 } @{$sample_adaptor->get_default_strains};
  my %db_pops;
  
  foreach (sort  @{$sample_adaptor->get_display_strains}) {
    next if $default_pops{$_};
    $db_pops{$_} = 1;
  }

  return (sort keys %default_pops), (sort keys %db_pops) if $options eq 'display'; # return list of pops with default first
  return ();
}

# Cell line Data retrieval  ---------------------------------------------------

# Because it can be slow and isn't always needed in the end
sub get_cell_line_data_closure {
  my ($self,$image_config) = @_;

  return sub {
    $self->get_cell_line_data($image_config);
  };
}

sub get_cell_line_data {
  my ($self, $image_config) = @_;
  
  # First work out which tracks have been turned on in image_config
  my %cell_lines = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  my @sets       = qw(core non_core);  
  my $data;

  foreach my $cell_line (keys %cell_lines) {
    $cell_line =~ s/:\w*//;
    
    foreach my $set (@sets) {
      my $node = $image_config->get_node("reg_feats_${set}_$cell_line");
      
      next unless $node;
      
      my $display = $node->get('display');
      
      $data->{$cell_line}{$set}{'renderer'} = $display if $display ne 'off';
      
      foreach ($node->nodes) {
        my $feature_name = $_->data->{'name'};
        
        $data->{$cell_line}{$set}{'available'}{$feature_name} = 1; 
        $data->{$cell_line}{$set}{'on'}{$feature_name}        = 1 if $_->get('display') eq 'on'; # add to configured features if turned on
      }
    }
  }
  
  return $self->get_data($data);
}

sub get_data {
  my ($self, $data) = @_;
  my $hub                  = $self->hub;
  my $dataset_adaptor      = $hub->get_adaptor('get_DataSetAdaptor', 'funcgen');
  my $associated_data_only = $hub->param('opt_associated_data_only') eq 'yes' ? 1 : undef; # If on regulation page do we show all data or just used to build reg feature?
  my $reg_object           = $associated_data_only ? $hub->core_object('regulation') : undef;
  my $count                = 0;
  my @result_sets;
  my %feature_sets_on;

  return $data unless scalar keys %$data;
  
  foreach my $regf_fset (@{$hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen')->fetch_all_by_feature_class('regulatory')}) {
    my $regf_data_set = $dataset_adaptor->fetch_by_product_FeatureSet($regf_fset);
    my $cell_line     = $regf_data_set->cell_type->name;

    next unless exists $data->{$cell_line};

    foreach my $reg_attr_fset (@{$regf_data_set->get_supporting_sets}) {
      my $feature_type_name     = $reg_attr_fset->feature_type->name;
      my $unique_feature_set_id = $reg_attr_fset->cell_type->name . ':' . $feature_type_name;
      my $focus_flag            = $reg_attr_fset->is_focus_set ? 'core' : 'non_core';

      $count++;
      my $key = "$unique_feature_set_id:$count";
      
      next unless $data->{$cell_line}{$focus_flag}{'on'}{$feature_type_name};
      
      my $display_style = $data->{$cell_line}{$focus_flag}{'renderer'};
      
      $feature_sets_on{$feature_type_name} = 1;
      
      if ($display_style  eq 'compact' || $display_style eq 'tiling_feature') {
        my @block_features = @{$reg_attr_fset->get_Features_by_Slice($self->Obj)};
        
        if ($reg_object && scalar @block_features) {
          my $obj = $reg_object->Obj;
          @block_features = grep $obj->has_attribute($_->dbID, 'annotated'), @block_features
        }
       
        $data->{$cell_line}{$focus_flag}{'block_features'}{$key} = \@block_features if scalar @block_features;
      }
      
      if ($display_style eq 'tiling' || $display_style eq 'tiling_feature') {
        my $reg_attr_dset = $dataset_adaptor->fetch_by_product_FeatureSet($reg_attr_fset); 
        my $sset          = $reg_attr_dset->get_displayable_supporting_sets('result');
        
        if (scalar @$sset) {
          # There should only be one
          throw("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t" . $reg_attr_dset->name) if scalar @$sset > 1;
        
          push @result_sets, $sset->[0];
          $data->{$cell_line}{$focus_flag}{'wiggle_features'}{$unique_feature_set_id . ':' . $sset->[0]->dbID} = 1;  
        }
      }
    }
  }

  foreach (@result_sets) { 
    my $unique_feature_set_id = join ':', $_->cell_type->name, 
                                          $_->feature_type->name, 
                                          $_->dbID;
    $data->{'wiggle_data'}{$unique_feature_set_id} = $_->dbfile_path;
  }
    
  $data->{'colours'} = \%feature_sets_on;
  
  return $data;
}

1;
