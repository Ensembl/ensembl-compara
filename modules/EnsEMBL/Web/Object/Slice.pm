=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION
### This is a 'helper' object which is created by other objects
### when a slice is needed

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;
use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

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
  my $vfa = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation');
  
  # find VCF config
  my $c = $self->species_defs->ENSEMBL_VCF_COLLECTIONS;

  if($c) {
    my $variation_db = $self->variation_adaptor;
    
    # set config file via ENV variable
    $ENV{ENSEMBL_VARIATION_VCF_CONFIG_FILE} = $c->{'CONFIG'};
    $variation_db->use_vcf($c->{'ENABLED'}) if $variation_db->can('use_vcf');
  }
  
  if ($so_terms) {
    $vfa->{_ontology_adaptor} ||= $self->hub->get_adaptor('get_OntologyTermAdaptor', 'go');
  }
  my $all_snps = [ @{$vfa->fetch_all_by_Slice_SO_terms($self->Obj, $so_terms)} ];
  my $ngot =  scalar(@$all_snps);
  push @$all_snps, @{$vfa->fetch_all_somatic_by_Slice_SO_terms($self->Obj)};

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
        grep { $sources->{$_->[2]->source->name} }                                 # [ fake_s, fake_e, SNP ] Filter our unwanted classes
        @filtered_snps;
    }
 
    if ($needvalidation) {
      @filtered_snps =
        grep {( @{$_->[2]->get_all_evidence_values} ? 
          (grep { $valids->{"opt_" . lc $_} } @{$_->[2]->get_all_evidence_values}) : 
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
  my ($self, $image_config, $filter) = @_;

  ## Check for cached data
  if ($image_config && $image_config->{'data_by_cell_line'} 
    && ref($image_config->{'data_by_cell_line'}) eq 'HASH') {
    return $image_config->{'data_by_cell_line'};
  }

  # First work out which tracks have been turned on in image_config
  my %cell_lines = ();
  if ( $self->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    %cell_lines = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  }
  my $data  = {};

  foreach my $cell_line (keys %cell_lines) {
    $cell_line =~ s/:[^:]*$//;
    my $ic_cell_line = $cell_line;
    clean_id($ic_cell_line);

    my $node;
    if ($image_config) {
      $node = $image_config->get_node("reg_feats_core_$ic_cell_line");
    }
    else {
      my $tmp_ic = $self->hub->get_imageconfig('reg_summary');
      $node   = $tmp_ic->get_node("reg_feats_core_$ic_cell_line");
    }
    next unless $node;

    ## Configure each track separately, instead of by column
    foreach my $track (@{$node->child_nodes||[]}) {
      my $id = $track->id;
      my @split = split('_', $id);
      my $experiment = $split[-1];

      if ($image_config) {
        my $display = $node->tree->user_data->{$id}{'display'};
        $data->{$cell_line}{$experiment}{'renderer'} = $display if ($display && $display ne 'off');
      }
      else {
        $data->{$cell_line}{$experiment} = {};
      }
    }
  }

  if ($image_config) {
    return $self->get_data($data, $filter);
  }
  else {
    return $self->get_table_data($data);
  }
}

sub get_data {
  my ($self, $data, $filter) = @_;
  return $data unless scalar keys %$data;

  $filter ||= {};
  my $is_image = keys %$filter ? 0 : 1;
  my $hub = $self->hub;

  ## Get only the data we need
  my $lookup        = $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}{'peak_calling'};
  my $pc_adaptor    = $hub->get_adaptor('get_PeakCallingAdaptor', 'funcgen');
  my $peak_adaptor  = $hub->get_adaptor('get_PeakAdaptor', 'funcgen');
  my %feature_sets_on;

  while (my($cell_line, $ftypes) = each(%$data)) {
    next if ($is_image && ($ftypes eq 'off' || !keys %{$ftypes||{}}));
    next if $filter->{'cell'} and !grep { $_ eq $cell_line } @{$filter->{'cell'}};
    next if $filter->{'cells_only'};
    next unless exists $data->{$cell_line};
    my $count = 0;

    while (my($ftype_name,$info) = each (%$ftypes)) {
      next unless $info->{'renderer'};
      ## Look up the peak calling ID from config.packed
      my $pc_id  = $lookup->{$cell_line}{$ftype_name};
      next unless $pc_id;

      ## Instantiate the peak calling object
      my $peak_calling  = $pc_adaptor->fetch_by_dbID($pc_id);
      next unless $peak_calling;

      $count++;

      my $unique_id = sprintf '%s:%s', $cell_line, $ftype_name;
      my $display_style = $is_image ? $info->{'renderer'} : '';
      $feature_sets_on{$ftype_name} = 1;
    
      if ($filter->{'block_features'}
          || grep { $display_style eq $_ } qw(compact tiling_feature signal_feature)) {
        my $key = $unique_id.':'.$count;
        my $block_features = $peak_adaptor->fetch_all_by_Slice_PeakCalling($self->Obj, $peak_calling);
        $data->{$cell_line}{$ftype_name}{'block_features'}{$key} = $block_features || [];
      }

      ## Get path to bigWig file
      if ($display_style && grep { $display_style eq $_ } qw(tiling tiling_feature signal signal_feature)) {
      
        my $alignment        = $peak_calling->get_signal_Alignment;
        my $bigwig_file      = $alignment->get_bigwig_DataFile;
        my $bigwig_file_name = $bigwig_file->path;
      
        my $file_path = join '/', 
          $hub->species_defs->DATAFILE_BASE_PATH, 
          lc $hub->species, 
          $hub->species_defs->ASSEMBLY_VERSION, 
          $bigwig_file_name;

        my $key = $unique_id.':'.$alignment->dbID;
      
        $data->{$cell_line}{$ftype_name}{'wiggle_features'}{$key} = $file_path;
      }
    }
  }

  $data->{'colours'} = \%feature_sets_on;
  return $data;
}

sub get_table_data {
  my ($self, $data, $filter) = @_;
  return $data unless scalar keys %$data;

  my $hub                   = $self->hub;
  my $peak_calling_adaptor  = $hub->get_adaptor('get_PeakCallingAdaptor', 'funcgen');
  my $all_peak_calling      = $peak_calling_adaptor->fetch_all;

  foreach my $peak_calling (@{$all_peak_calling||[]}) {

    my $ftype       = $peak_calling->get_FeatureType;
    my $ftype_name  = $ftype->name;

    my $epigenome   = $peak_calling->get_Epigenome;
    my $cell_line   = $epigenome->short_name;

    $data->{$cell_line}{$ftype_name} = $peak_calling;
  }
  return $data;
}

1;
