=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::Variation;

### NAME: EnsEMBL::Web::Object::Variation
### Wrapper around a Bio::EnsEMBL::Variation 
### or EnsEMBL::Web::VariationFeature object  

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION

# FIXME Are these actually used anywhere???
# Is there a reason they come before 'use strict'?
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::REST;
use base qw(EnsEMBL::Web::Object);

sub availability {
  my $self = shift;
  
  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;
    
    if ($obj->isa('Bio::EnsEMBL::Variation::Variation')) {
      my $counts = $self->counts;
      
      $availability->{'variation'} = 1;
      
      $availability->{"has_$_"} = $counts->{$_} for qw(uniq_transcripts transcripts regfeats features populations population_freqs samples ega citation locations);
      if($self->param('vf')){
          ## only show these if a mapping available
          $availability->{"has_$_"}  = $counts->{$_} for qw(alignments ldpops);
      }
      $availability->{'is_somatic'}  = $obj->has_somatic_source;
      $availability->{'not_somatic'} = !$obj->has_somatic_source;
      $availability->{'is_coding'}   = $self->is_coding_variant;
      $availability->{'has_pdbe'}    = $self->has_pdbe_analysis();
      $availability->{'has_variation_source_db'} = $self->has_variation_source_db();
    }
    
    $self->{'_availability'} = $availability;
  }
  
  return $self->{'_availability'};
}

sub is_coding_variant {
  my $self = shift;
  my $rank;
  if(my $vf_object = $self->get_selected_variation_feature) {
    my $cons = $vf_object->most_severe_OverlapConsequence;
    $rank = $cons->rank;
  }
  else {
    my @vari_mappings = @{ $self->get_variation_features };
    return 0 if (!@vari_mappings);
    foreach my $f (@vari_mappings){
      my $cons = $f->most_severe_OverlapConsequence;
      my $cons_rank = $cons->rank;
      if (!$rank || $rank > $cons_rank) {
        $rank = $cons_rank;
      }
    }
  }
  return ($rank < 18) ? 1 : 0;
}

sub has_pdbe_analysis {
  my $self = shift;
  return ($self->table_info($self->get_db, 'protein_feature')->{'analyses'}{'sifts_import'}) ? 1 : 0;
}

sub has_variation_source_db {
  my $self = shift;
  my $hub   = $self->hub;
  my $variation_db  = $hub->species_defs->databases->{'DATABASE_VARIATION'};
  return $variation_db->{meta_info}->{1}->{'variation_source.database'}->[0];
}

sub counts {
  my $self  = shift;
  my $obj   = $self->Obj;
  my $hub   = $self->hub;
  my $cache = $hub->cache;

  return {} unless $obj->isa('Bio::EnsEMBL::Variation::Variation');

  my $vf  = $hub->param('vf');
  my $key = sprintf '::Counts::Variation::%s::%s::%s::', $self->species, $hub->param('vdb'), $hub->param('v');
  $key   .= $vf . '::' if $vf;

  my $counts = $self->{'_counts'};
  $counts ||= $cache->get($key) if $cache;

  unless ($counts) {
    $counts = {};
    $counts->{'uniq_transcripts'} = $self->count_uniq_transcripts;
    $counts->{'transcripts'} = $self->count_transcripts;
    $counts->{'regfeats'}    = $self->count_regfeats;
    $counts->{'features'}    = $counts->{'transcripts'} + $counts->{'regfeats'};
    $counts->{'samples'}     = $self->count_samples;
    $counts->{'ega'}         = $self->count_ega;
    $counts->{'ldpops'}      = $self->count_ldpops;
    $counts->{'alignments'}  = $self->count_alignments->{'multi'};
    $counts->{'citation'}    = $self->count_citations;
    $counts->{'locations'}   = scalar @{$self->get_variation_features};
    ($counts->{'population_freqs'}, $counts->{'populations'}) = @{$self->count_populations};

    $cache->set($key, $counts, undef, 'COUNTS') if $cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}
sub count_ega {
  my $self = shift;
  my @ega_links = @{$self->get_ega_links||[]};
  my $counts = scalar @ega_links || 0;
  return $counts;
}

sub get_ega_links {
  my $self = shift;
  my @ega_links = @{$self->get_external_data};

  if(my $vf_object = $self->get_selected_variation_feature) {
    my $chr   = $vf_object->seq_region_name;
    my $start = $vf_object->seq_region_start;
    my $end   = $vf_object->seq_region_end;
    @ega_links = grep {$_->seq_region_name eq $chr && $_->seq_region_start == $start && $_->seq_region_end == $end} @ega_links;
  }
  return \@ega_links;
}

sub count_features {
  my $self = shift;
  return $self->count_transcripts + $self->count_regfeats;
}

sub count_transcripts {
  return scalar @{($_[0]->selected_variation_feature_mapping || {})->{transcript_vari} || []};
}

sub count_regfeats {
  my $self = shift;
  my $counts = 0;
  # a MotifFeature is necessarily contained in a RegulatoryFeature so we don't need the count explicitly?
  # $counts += scalar map {@{$_->get_all_RegulatoryFeatureVariations}, @{$_->get_all_MotifFeatureVariations}} @{$self->get_variation_features};
  $counts += scalar map {@{$_->get_all_RegulatoryFeatureVariations}} @{$self->get_variation_features};
  return $counts;
}

sub count_uniq_transcripts {
  my %transcriptnames = map {$_->{transcriptname} => 1} @{$_[0]->selected_variation_feature_mapping->{transcript_vari} || []};
  return scalar keys %transcriptnames;
}

sub count_populations {
  my $self = shift;
  my $counts = 0;
  my $freqs = $self->freqs;
  my @freqs_pop = keys(%{$freqs});
  my $counts_pop = scalar(@freqs_pop) || 0;
  foreach my $pop_id (@freqs_pop) {
    $counts += scalar(keys %{$freqs->{$pop_id}{ssid}});
  }
  return [$counts,$counts_pop];
}

sub count_samples {
  my $self = shift;
  my $dbh  = $self->database('variation')->get_VariationAdaptor->dbc->db_handle;
  my $var  = $self->Obj;
  
  # somatic variations don't have genotypes currently
  return 0 if $var->has_somatic_source;
  
  my $gts = $var->get_all_SampleGenotypes();
  
  return defined($gts) ? scalar @$gts : 0;
}

# uncomment when including export data for variation
# sub can_export {
#   my $self = shift;
#   
#   return $self->action =~ /^Export$/ ? 0 : $self->availability->{'variation'};
# }

sub count_ldpops {
  my $self = shift;
  my $pa  = $self->database('variation')->get_PopulationAdaptor;
  my @ldpops = @{$pa->fetch_all_LD_Populations};
  return undef if (!scalar @ldpops);
  my $var  = $self->Obj;
  my $gts = $var->get_all_SampleGenotypes();
  return undef if (!scalar @$gts);
  my @gts_names = map {$_->sample->name} @$gts;
  my $count = 0;
  foreach (@ldpops) {
    my @ldpops_sample_names = map {$_->name} @{$_->get_all_Samples};
    foreach my $gts_name (@gts_names) {
      if (grep {$gts_name eq $_ } @ldpops_sample_names) {
        $count++;
        last;
      }
    }
  }
  return ($count > 0 ? $count : undef);
}

sub count_citations{
    my $self = shift;
    my $count = scalar @{$self->get_citation_data()};
    return ($count > 0 ? $count : undef);
}

sub short_caption {
  my $self = shift;
  
  my $type = $self->Obj->is_somatic ? 'Somatic mutation' : 'Variant';
  my $short_type = $self->Obj->is_somatic ? 'S. mut' : 'Var';
  return $type.' displays' unless shift eq 'global';   
  
  my $label = $self->name;  
  return length $label > 30 ? "$short_type: $label" : "$type: $label";
}

sub caption {
 my $self = shift; 
 my $caption = [$self->name, uc $self->vari_class];
 return $caption;
}

# Location ----------------------------------------------------------------------

sub not_unique_location {
  my $self = shift;
  unless ($self->hub->core_param('vf') ){
    my %mappings = %{ $self->variation_feature_mapping };
    my $count = scalar (keys %mappings);
    my $html;
    if ($count < 1) {
      $html = "<p>This feature has not been mapped.<p>";
    } elsif ($count > 1) { 
      $html = "<p>You must select a location from the panel above to see this information</p>";
    }
    return  $html;
  }
  return;
}

sub location_string {

  ### Variation_location
  ### Example    : my $location = $self->location_string;
  ### Description: Gets chr:start-end for the SNP with 100 bases on either side
  ### Returns string: chr:start-end

  my ($self, $unique) = @_;
  my( $sr, $st ) = $self->_seq_region_($unique);
  return $sr ? "$sr:@{[$st-100]}-@{[$st+100]}" : undef;
}

sub var_location {
  ### Variation_location
  ### Example    : my $location = $self->location_string;
  ### Description: Gets chr:start-end for the SNP 
  ### Returns string: chr:start-end

  my ($self, $unique) = @_;
  my( $sr, $st ) = $self->_seq_region_($unique);
  return $sr ? "$sr:@{[$st]}-@{[$st]}" : undef;
}

sub _seq_region_ {

  ### Variation_location
  ### Args        : $unique
  ###               if $unique=1 -> returns undef if there are more than one 
  ###               variation features returned)
  ###               if $unique is 0 or undef, it returns the data for the first
  ###               mapping postion
  ### Example    : my ($seq_region, $start) = $self->_seq_region_;
  ### Description: Gets the sequence region, start and coordinate system name
  ### Returns $seq_region, $start, $seq_type

  my $self = shift;
  my $unique = shift;
  my($seq_region, $start, $seq_type);
  if (  my $region  = $self->param('c') ) {
    ($seq_region, $start) = split /:/, $region;
    my $slice = $self->database('core')->get_SliceAdaptor->fetch_by_region(undef,$seq_region);
    return unless $slice;
    $seq_type = $slice->coord_system->name;
  }
  else {
    my @vari_mappings = @{ $self->get_variation_features };
    return (undef, undef, undef, "no") unless  @vari_mappings;

    if ($unique) {
      return (undef, undef, undef, "multiple") if $#vari_mappings > 0;
    }

    my $vf = $vari_mappings[0];
    $seq_region = $vf->seq_region_name;
    $start      = $vf->seq_region_start;;
    $seq_type   = $vf->slice->coord_system_name;
  }
  return ( $seq_region, $start, $seq_type );
}

sub seq_region_name    {

  ### Variation_location 
  ### a

  my( $sr,$st) = $_[0]->_seq_region_; return $sr; 
}

sub seq_region_start   {
  ### Variation_location 
  ### a
  my( $sr,$st) = $_[0]->_seq_region_; return $st; 
}

sub seq_region_end     {
  ### Variation_location 
  ### a
  my( $sr,$st) = $_[0]->_seq_region_; return $st; 
}

sub seq_region_strand  {
  ### Variation_location 
  ### a
  return 1; 
}

sub seq_region_type    { 
  ### Variation_location
  ### a
  my($sr,$st,$type) = $_[0]->_seq_region_; return $type; 
}

sub seq_region_data {

  ### Variation_location
  ### Args       : none
  ### Example    : my ($seq_region, $start, $type) = $object->seq_region_data;
  ### Description: Only returns sequence region, start and coordinate system name 
  ###              if this Variation Object maps to one Variation Feature obj
  ### Returns $seq_region, $start, $seq_type, $error(optional) which specifies
  ### 'no' if no mapping or 'multiple' if has several hits
  ### If there is an error, the first 3 args returned are undef

  my($sr,$st,$type, $error) = $_[0]->_seq_region_(1); 
  return ($sr, $st, $type, $error);
}


# Variation calls ----------------------------------------------------------------
sub vari {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $ensembl_vari = $object->vari
  ### Description: Gets the ensembl variation object stored on the variation data object
  ### Returns Bio::EnsEmbl::Variation

  my $self = shift;
  return $self->Obj;
}

sub name {

   ### Variation_object_calls
   ### a
   ### Arg (optional):   Variation object name (string)
   ### Example    : my $vari_name = $object->vari_name;
   ### Example    : $object->vari_name('12335');
   ### Returns String for variation name

  my $self = shift;
  if (@_) {
      $self->vari->name(shift);
  }
  return $self->vari->name;
}

sub source { $_[0]->source_name; }

sub source_name {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $vari_source = $object->source_name;
  ### Description: gets the Variation source
  ### Returns String

  $_[0]->vari->source_name;
}

sub source_description {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $vari_source_desc = $object->source_description;
  ### Description: gets the description for the Variation source
  ### Returns String

  $_[0]->vari->source_description;
}

sub get_genes {

  ### Variation_object_calls
  ### a
  ### Args: none
  ### Example    : my @genes = @ {$obj->get_genes};
  ### Returns arrayref of Bio::EnsEMBL::Gene objects

  $_[0]->vari->get_all_Genes; 
}


sub source_version { 

  ### Variation_object_calls
  ### a
  ### Example    : my $vari_source_version = $object->source
  ### Description: gets the Variation source version e.g. dbSNP version 119
  ### Returns String

  my $self    = shift;
  my $source  = $self->vari->source_name;
  my $version = $self->vari->source_version;
  return $version;
}


sub source_url {
  
  ### Variation_object_calls
  ### Args: none
  ### Example    : my $vari_source_url = $object->source_url
  ### Description: gets the Variation source URL
  ### Returns String
  
  my $self = shift;
  my $source_url = $self->vari->source_url;
  return $source_url;
}
 
sub dblinks {

  ### Variation_object_calls
  ### Args: none
  ### Example    : my $dblinks = $object->dblinks;
  ### Description: gets the SNPs links to external database
  ### Returns Hashref (external DB => listref of external IDs)

  my $self = shift;
  my @sources = @{  $self->vari->get_all_synonym_sources  };
  my %synonyms;
  foreach (@sources) {
    $synonyms{$_} = $self->vari->get_all_synonyms($_);
  }
  return \%synonyms;
}

sub consequence_type {
  my $self = shift;
  my $consequence_type;
  my @vari_mappings = @{ $self->get_variation_features };
  foreach my $f (@vari_mappings){
    return '-' unless $f->variation_name eq $self->name;
    $consequence_type = $f->display_consequence;
  }
  $consequence_type =~s/_/ /g;
 
  return $consequence_type;
}

sub evidence_status { 

  ### Variation_object_calls
  ### 
  ### Example    : my $evidence_status = $object->get_all_evidence_states;
  ### Returns List of supporting evidence types for variation

  my $self = shift;
  return $self->vari->get_all_evidence_values;
}


sub flanking_seq {

  ### Variation_object_calls
  ### Args: "up" or "down" (string)
  ### Example    : my $down_seq = $object->flanking_seq($down);
  ### Description: gets the sequence downstream of the SNP
  ### Returns String

  my $self = shift;
  my $direction = shift;
  my $call = $direction eq 'up' ? "five_prime_flanking_seq" : "three_prime_flanking_seq";
  my $sequence;
  eval { 
    $sequence = $self->vari->$call;
  };
  if ($@) {
    warn "*****[ERROR]: No flanking sequence!";
    return 'unavailable';
  }
  return uc($sequence);
}


sub alleles {

  ### Variation_object_call
  ### Args: none
  ### Example    : my $alleles = $object->alleles;
  ### Description: gets the SNP alleles
  ### Returns Array or string

  my $self = shift;

  # A selected variation feature
  if(my $vf_object = $self->get_selected_variation_feature) {
    return $vf_object->allele_string;
  }

  # A unique variation feature
  my  @vari_mappings = @{ $self->unique_variation_feature };
  return $vari_mappings[0]->allele_string if @vari_mappings;

  # Several mappings or no mappings
  my @allele_obj = @{$self->vari->get_all_Alleles};
  my %alleles;
  map { $alleles{$_->allele} = 1; } @allele_obj;

  my $observed_alleles = join "/", (keys %alleles);

  return "$observed_alleles";

}



sub vari_class{

  ### Variation_object_calls
  ### a
  ### Example    : my $vari_class = $object->vari_class
  ### Description: returns the variation class (indel, snp, het) for a varation
  ### Returns String
  
  return $_[0]->vari->var_class;
}


sub ancestor {

  ### Variation_object_calls 
  ### a
  ### Example    : $object->get_selected_variation_feature->ancestral_allele;
  ### Description: returns the ancestral allele for the variation
  ### Returns String

  my $self = shift;

  my $anc_allele;
  if($self->get_selected_variation_feature) {
    $anc_allele = $self->get_selected_variation_feature->ancestral_allele;
  }
  return $anc_allele;
}


sub clinical_significance {

  ### Variation_object_calls 
  ### a
  ### Example    : $object->clinical_significance;
  ### Description: returns the clinical significance and the corresponding display colour.
  ### Returns and array

  my $self = shift;
  return $self->vari->get_all_clinical_significance_states;
}


sub CADD_score {
  ### Args       : none
  ### Example    : my $data = $object->CADD_score;
  ### Description: gets CADD score and CADD score source. We know from the config file that we only expect one source for the website.
  ### Returns arrayref of data, 

  my $self = shift;
  return [undef, undef] unless $self->hub->species_defs->ENSEMBL_VCF_COLLECTIONS; 

  my $vf_object = $self->get_selected_variation_feature;
  return [undef, undef] unless $vf_object;

  my @alleles = split('/', $vf_object->allele_string);
  
  my $cadd_scores_for_all_alternatives = $vf_object->get_all_cadd_scores;
  my $cadd_scores = {};

  my $source = (keys %$cadd_scores_for_all_alternatives)[0];  
 
  my $cadd_scores_for_source = $cadd_scores_for_all_alternatives->{$source};

  foreach my $allele (@alleles) {
    $cadd_scores->{$allele} = $cadd_scores_for_source->{$allele} if (exists $cadd_scores_for_source->{$allele});
  }
  return [undef, undef] if (!scalar keys %$cadd_scores); 

  return [$cadd_scores, $source];
}

sub GERP_score {
  ### Args       : none
  ### Example    : my $data = $object->GERP_score;
  ### Description: gets GERP score and GERP score source. We know from the config file that we only expect one source for the website.
  ### Returns arrayref of data, 

  my $self = shift;
  return [undef, undef] unless $self->hub->species_defs->ENSEMBL_VCF_COLLECTIONS; 
  my $vf_object = $self->get_selected_variation_feature;
  return [undef, undef] unless $vf_object;

  my $variation_db = $self->Obj->adaptor->db->get_VariationAdaptor->db;
  $variation_db->gerp_root_dir($self->hub->species_defs->ENSEMBL_FTP_URL . '/release-' . $self->hub->species_defs->ENSEMBL_VERSION . '/compara/conservation_scores/');

  my $gerp_score = $vf_object->get_gerp_score;
  my $source = (keys %$gerp_score)[0];  
  my $score = $gerp_score->{$source}; 
  return [undef, undef] if (!defined $score); 
  return [$score, $source];
}

sub freqs {

  ### Population_allele_genotype_frequencies
  ### Args      : none
  ### Example    : my $data = $object->freqs;
  ### Description: gets allele and genotype frequencies for this Variation
  ### Returns hash of data, 

  my $self = shift;

  ## show genotypes for unmapped variants - get alleles from variation not variation feature

  my $allele_list = $self->vari->get_all_Alleles;
  return {} unless $allele_list;
  
  my (%data, $allele_missing);
  foreach my $allele_obj ( sort { $a->subsnp cmp $b->subsnp }@{ $allele_list } ) {  
    my $pop_obj = $allele_obj->population;  
    
    # no population, add to special data structure
    if(!defined($pop_obj) || (defined($pop_obj) && ($pop_obj->size == 1 || !defined($allele_obj->frequency)))) {
      next unless $allele_obj->subsnp_handle();
      push @{$data{no_pop}{$allele_obj->subsnp_handle}{$allele_obj->subsnp}}, $allele_obj->allele;
      next;
    }
    
    my $pop_id  = $self->pop_id($pop_obj);
    my $ssid = $allele_obj->subsnp;
    
    # failed status
    $data{$pop_id}{ssid}{$ssid}{failed_desc} = $allele_obj->failed_description if $allele_obj->is_failed;
   
    push (@{ $data{$pop_id}{ssid}{$ssid}{AlleleFrequency} }, $allele_obj->frequency);
    push (@{ $data{$pop_id}{ssid}{$ssid}{AlleleCount} }, $allele_obj->count);
    push (@{ $data{$pop_id}{ssid}{$ssid}{Alleles} },   $allele_obj->allele);    

    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj) unless exists $data{$pop_id}{pop_info};
    
    ## If frequency data is available, show frequency data submitter, else show observation submitter
    $data{$pop_id}{ssid}{$ssid}{submitter}  = $allele_obj->frequency_subsnp_handle($pop_obj);
    unless (defined $data{$pop_id}{ssid}{$ssid}{submitter} ){
      $data{$pop_id}{ssid}{$ssid}{submitter}  = $allele_obj->subsnp_handle() ;
    }

    # log missing alleles as recorded when reading data from VCF
    $data{$pop_id}{missing_alleles}{$_} = 1 for keys %{$allele_obj->{_missing_alleles} || {}};
  }
  
  # Add genotype data;
  foreach my $pop_gt_obj ( sort { $a->subsnp cmp $b->subsnp} @{ $self->pop_genotype_obj } ) {
    my $pop_obj = $pop_gt_obj->population; 
    
    # no population, add to special data structure
    if(!defined($pop_obj) || (defined($pop_obj) && ($pop_obj->size == 1 || !defined($pop_gt_obj->frequency)))) {
      next unless $pop_gt_obj->subsnp_handle();
      push @{$data{no_pop}{$pop_gt_obj->subsnp_handle}{$pop_gt_obj->subsnp}}, @{$pop_gt_obj->genotype};
      next;
    }
    
    my $pop_id  = $self->pop_id($pop_obj); 
    my $ssid = $pop_gt_obj->subsnp();  
    # No allele data for this population ...
    unless (exists $data{$pop_id}{ssid}{$ssid}{AlleleFrequency}){
      $allele_missing = 1;
      push (@{ $data{$pop_id}{ssid}{$ssid}{AlleleFrequency} }, "");
      push (@{ $data{$pop_id}{ssid}{$ssid}{AlleleCount} }, "");
      push (@{ $data{$pop_id}{ssid}{$ssid}{Alleles} }, "");
      $data{$pop_id}{ssid}{$ssid}{submitter} = $pop_gt_obj->subsnp_handle();
    }

    $data{$pop_id}{pop_info} = $self->pop_info($pop_obj);
    push (@{ $data{$pop_id}{ssid}{$ssid}{GenotypeFrequency} }, $pop_gt_obj->frequency);
    push (@{ $data{$pop_id}{ssid}{$ssid}{GenotypeCount} }, $pop_gt_obj->count);
    push (@{ $data{$pop_id}{ssid}{$ssid}{Genotypes} }, $self->pop_genotypes($pop_gt_obj)); 

    $data{$pop_id}{ssid}{$ssid}{count} = $pop_gt_obj->count();
  }

  if ($allele_missing == 1){
    #%data = %{ $self->calculate_allele_freqs_from_genotype($variation_feature, \%data) }; 
  }

  return \%data;
}

sub format_group_population_freqs {
  my ($self, $only_super_populations) = @_;
  my $hub = $self->hub;
  my $pop_freq;
  my $main_priority_level;

  my $freq_data = $self->freqs();

  # Get the main priority group level
  foreach my $pop_id (keys %$freq_data) {
    my $priority_level = $freq_data->{$pop_id}{'pop_info'}{'GroupPriority'};
    next if (!defined($priority_level));

    $main_priority_level = $priority_level if (!defined($main_priority_level) || $main_priority_level > $priority_level);
  }
  return undef if (!defined($main_priority_level));

  foreach my $pop_id (keys %$freq_data) {
    ## is it a priority project ?
    my $priority_level = $freq_data->{$pop_id}{'pop_info'}{'GroupPriority'};
    next if (!defined($priority_level) || $priority_level!=$main_priority_level);

    my $pop_name = $freq_data->{$pop_id}{'pop_info'}{'Name'};

    if ($only_super_populations && scalar(keys(%{$freq_data->{$pop_id}{'pop_info'}{'Sub-Population'}})) == 0) {
      next;
    }
    elsif (!$only_super_populations && scalar(keys(%{$freq_data->{$pop_id}{'pop_info'}{'Sub-Population'}})) != 0) {
      $pop_freq->{$pop_name}{'sub_pop'} = $freq_data->{$pop_id}{'pop_info'}{'Sub-Population'};
    }

    my @composed_name = split(':', $pop_name);
    $pop_freq->{$pop_name}{'label'} = $composed_name[$#composed_name];
    $pop_freq->{$pop_name}{'desc'}  = $freq_data->{$pop_id}{'pop_info'}{'Description'};
    $pop_freq->{$pop_name}{'group'} = $freq_data->{$pop_id}{'pop_info'}{'PopGroup'};

    foreach my $ssid (keys %{$freq_data->{$pop_id}{'ssid'}}) {
      next if $freq_data->{$pop_id}{$ssid}{'failed_desc'};

      my @allele_freq = @{$freq_data->{$pop_id}{'ssid'}{$ssid}{'AlleleFrequency'}};

      foreach my $gt (@{$freq_data->{$pop_id}{'ssid'}{$ssid}{'Alleles'}}) {
        next unless $gt =~ /(\w|\-)+/;

        my $freq = $self->format_freqs_number(shift @allele_freq);

        $pop_freq->{$pop_name}{'freq'}{$ssid}{$gt} = $freq if $freq ne 'unknown';
      }
    }
  }
  return $pop_freq;
}

sub format_freqs_number {
  ### Population_genotype_alleles
  ### Arg1 : null or a number
  ### Returns "unknown" if null or formats the number to 3 decimal places

  my ($self, $number) = @_;

  return 'unknown' if (!defined $number);
  return ($number < 0.01) ? sprintf '%.3f', $number : sprintf '%.2f', $number;
}


sub calculate_allele_freqs_from_genotype {
  my ($self, $variation_feature, $temp_data) = @_;
  my %data = %$temp_data;
  my ($a1, $a2) = split /\//, $variation_feature->allele_string;
  
  # check if have allele data, if not calculate it
  foreach my $pop_id(keys %data){
    foreach my $ssid (keys %{$data{$pop_id}{ssid}}){
      if (scalar @{$data{$pop_id}{ssid}{$ssid}{'Alleles'}} <= 1){
        my (%genotype_freqs, $i);
        
        next unless $data{$pop_id}{ssid}{$ssid}{'GenotypeFrequency'};
        
        foreach my $genotype (@{$data{$pop_id}{ssid}{$ssid}{'Genotypes'}}){
          $genotype_freqs{$genotype} = $data{$pop_id}{ssid}{$ssid}{'GenotypeFrequency'}[$i++];
        }
        
        my $genotype_1_same = $genotype_freqs{"$a1|$a1"} || 0;
        my $genotype_1_diff = $genotype_freqs{"$a1|$a2"} || $genotype_freqs{"$a2|$a1"} || 0;
        my $freq_a1         = ($genotype_1_diff + (2 * $genotype_1_same)) /2;
        my $freq_a2         = 1 - $freq_a1;
        
        @{$data{$pop_id}{ssid}{$ssid}{'Alleles'}} = ();
        @{$data{$pop_id}{ssid}{$ssid}{'AlleleFrequency'}} = ();
        
        push @{$data{$pop_id}{ssid}{$ssid}{'Alleles'}}, $a1; 
        push @{$data{$pop_id}{ssid}{$ssid}{'Alleles'}}, $a2;  
        push @{$data{$pop_id}{ssid}{$ssid}{'AlleleFrequency'}}, $freq_a1; 
        push @{$data{$pop_id}{ssid}{$ssid}{'AlleleFrequency'}}, $freq_a2; 
      }
    }
  }

  return \%data;
}


sub get_external_data {
  my $self = shift;
  $self->{'external_data'} ||= $self->hub->database('variation')->get_PhenotypeFeatureAdaptor->fetch_all_by_Variation($self->vari);
  return $self->{'external_data'};
}

sub slice {
  my $self = shift;

  my $feature_slice;
  
  if(my $vf = $self->get_selected_variation_feature) {
    $feature_slice = $vf->feature_Slice;
  }

  return $feature_slice;
}

sub is_somatic_with_different_ref_base {
  my $self = shift;
  return unless $self->Obj->is_somatic;
  # get slice for variation feature
  my $feature_slice = $self->slice;
  return unless $feature_slice;
  my $ref_base = $feature_slice->seq();
  my ($a1, $a2) = split(//,$self->alleles);
  return  $ref_base ne $a1 ? 1 : undef;
}
# Population genotype and allele frequency table calls ----------------

sub pop_genotype_obj {

  ### frequencies_table
  ### Example    : my $pop_genotype_obj = $object->pop_genotype_obj;
  ### Description: gets Population genotypes for this Variation
  ### Returns listref of Bio::EnsEMBL::Variation::PopulationGenotype

  my $self = shift;
  return  $self->vari->get_all_PopulationGenotypes;
}




sub pop_genotypes {

  ### frequencies_table
  ###  Args      : Bio::EnsEMBL::Variation::PopulationGenotype object
  ### Example    : $genotype_freq = $object->pop_genotypes($pop);
  ### Description: gets the Population genotypes
  ### Returns String

  my ($self, $pop_genotype_obj)  = @_;
  return $pop_genotype_obj->genotype_string(1);
}



sub pop_info {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : my $data = $self->pop_info
  ### Description: returns a hash with data about this population
  ### Returns hash of data

  my $self = shift;
  my $pop_obj = shift;
  my %data;
  $data{Name}               = $self->pop_name($pop_obj);
  $data{PopLink}            = $self->pop_links($pop_obj);
  $data{Size}               = $self->pop_size($pop_obj);
  $data{Description}        = $self->pop_description($pop_obj);
  $data{"Super-Population"} = $self->extra_pop($pop_obj,"super");
  $data{"Sub-Population"}   = $self->extra_pop($pop_obj,"sub");
  $data{PopGroup}           = $self->pop_display_group_name($pop_obj) ||undef;
  $data{GroupPriority}      = $self->pop_display_group_priority($pop_obj) ||undef;
 

  return \%data;
}



sub pop_name {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $object->pop_name($pop);
  ### Description: gets the Population name
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj;
  return $pop_obj->name;
}



sub pop_id {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $object->pop_id($pop);
  ### Description: gets the Population ID
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return unless $pop_obj; 
  return $pop_obj->dbID;
}



sub pop_links {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_links($pop);
  ### Description: gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->get_all_synonyms("dbSNP");
}



sub pop_size {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_size($pop);
  ### Description: gets the Population size
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->size;
}



sub pop_description {

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $genotype_freq = $object->pop_description($pop);
  ### Description: gets the Population description
  ### Returns String

  my ($self, $pop_obj)  = @_;
  return $pop_obj->description;
}



sub extra_pop {

  ### frequencies_table
  ### Args1      : Bio::EnsEMBL::Variation::Population object
  ### Args2      : string "super", "sub"
  ### Example    : $genotype_freq = $object->extra_pop($pop, "super");
  ### Description: gets any super/sub populations
  ### Returns String

  my ($self, $pop_obj, $type)  = @_;
  return {} unless $pop_obj;
  my $call = "get_all_$type" . "_Populations";
  my @populations = @{ $pop_obj->$call};
  
  my %extra_pop;
  foreach my $pop ( @populations ) {
    my $id = $self->pop_id($pop);
    $extra_pop{$id}{Name}       = $self->pop_name($pop);
    $extra_pop{$id}{Size}       = $self->pop_size($pop);
    $extra_pop{$id}{PopLink}    = $self->pop_links($pop);
    $extra_pop{$id}{Description}= $self->pop_description($pop);
  }
  return \%extra_pop;
}

sub pop_display_group_priority{

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $group_priority = $object->pop_display_group_priority($pop);
  ### Description: gets priority level for the display group the population is in
  ### Returns String

  my ($self, $pop_obj)  = @_;
  ## FIXME - temporary defensive coding until we have 76 handover! 
  return $pop_obj->display_group_priority() if $self->species_defs->ENSEMBL_VERSION > 75;
}
sub pop_display_group_name{

  ### frequencies_table
  ### Args      : Bio::EnsEMBL::Variation::Population object
  ### Example    : $group_priority = $object->pop_display_group_name($pop);
  ### Description: gets name for the display group the population is in
  ### Returns String


  my ($self, $pop_obj)  = @_;
  ## FIXME - temporary defensive coding until we have 76 handover! 
  return $pop_obj->display_group_name() if $self->species_defs->ENSEMBL_VERSION > 75;
}

 


# Sample table -----------------------------------------------------

sub sample_table {

  ### sample_table_calls
  ### Example    : my $sample_genotypes = $object->sample_table;
  ### Description: gets Sample Genotype data for this variation
  ### Returns hashref with all the data

  my $self = shift;
  my $selected_pop = shift;
  my $sample_genotypes = $self->sample_genotypes_obj($selected_pop);
  return {} unless defined $sample_genotypes && @$sample_genotypes; 

  ### limit populations shown to those with population genotypes 
  ### summarised by dbSNP or added in adaptor for 1KG
  my $pop_geno_adaptor   = $self->hub->database('variation')->get_PopulationGenotypeAdaptor();
  my $pop_genos = $self->pop_genotype_obj;

  my %synonym;
  my %pop_seen;
  my %pop_data;
  my %data;
  
  foreach my $sample_gt_obj ( @$sample_genotypes ) { 
    my $sample_obj = $sample_gt_obj->sample;
    my $ind_obj   = $sample_obj->individual;
    
    next unless $ind_obj;
    next unless $sample_obj;
    next if $sample_obj->name() =~/1000GENOMES:pilot_2/; ## not currently reporting these

    my $sample_id    = $sample_obj->dbID;
    $data{$sample_id}{Name}        = $sample_obj->name;
    $data{$sample_id}{Genotypes}   = $self->sample_genotype($sample_gt_obj);
    $data{$sample_id}{Gender}      = $ind_obj->gender;
    $data{$sample_id}{Description} = $self->description($sample_obj);
    $data{$sample_id}{Mother}      = $self->parent($ind_obj,"mother");
    $data{$sample_id}{Father}      = $self->parent($ind_obj,"father");
    $data{$sample_id}{Children}    = $self->child($ind_obj);
    $data{$sample_id}{Object}      = $sample_obj;
  
    my $pop_objs = $sample_obj->get_all_Populations();

    foreach my $pop_obj (@{$pop_objs}) {
      my $pop_id  = $pop_obj->dbID();

      ## look up samples in each population once
      if (!$pop_seen{$pop_id}) {

        ## look up synonyms (for dbSNP link) once
        $synonym{$pop_obj->name} = $pop_obj->get_all_synonyms(),

        # Add population information
        $pop_data{$pop_id} = {
          Name => $pop_obj->name(),
          Size => $pop_obj->size(),
          Link => $synonym{$pop_obj->name},
          ID   => $pop_obj->dbID(),
          Priority => $pop_obj->display_group_priority(),
          Group    => $pop_obj->display_group_name()
        };
        $pop_seen{$pop_id} = 1;
      }
      push (@{$data{$sample_id}{Population}}, $pop_data{$pop_id}); 
    }

    if (scalar @{$pop_objs} == 0) {
      push (@{$data{$sample_id}{Population}}, {
        Name => $sample_obj->name(),
        Size => 1,
        Link => [],
        ID   => 1000000
      });
    }
  }
  
  return \%data;
}



sub sample_genotypes_obj {

  ### Sample_genotype_table_calls
  ### Example    : my $sample_genotypes = $object->sample_genotypes;
  ### Description: gets SampleGenotypes for this Variation
  ### Returns listref of SampleGenotypes

  my $self = shift;
  my $selected_pop = shift;
  my $samples;
  eval {
    $samples = $self->vari->get_all_SampleGenotypes($selected_pop);
  };
  if ($@) {
    warn "\n\n************ERROR************:  Bio::EnsEMBL::Variation::Variation::get_all_SampleGenotypes fails. $@";
  }
  return $samples;
}



sub sample_genotype {

  ### Sample_genotype_table_calls
  ### Args      : Bio::EnsEMBL::Variation::SampleGenotype object
  ### Example    : $genotype_freq = $object->sample_genotypes($sample);
  ### Description: gets the Sample genotypes
  ### Returns String

  my ($self, $sample)  = @_;
  return $sample->genotype_string;

}


sub description {

  ### Sample_genotype_table_calls
  ### Args       : Bio::EnsEMBL::Variation::Sample object
  ### Example    : $description = $object->sample_description($sample);
  ### Description: gets the Sample description
  ### Returns String

  my ($self, $obj)  = @_;
  return $obj->description;
}



sub parent {

  ### Sample_genotype_table_calls
  ### Args1      : Bio::EnsEMBL::Variation::Individual object
  ### Arg2       : string  "mother" "father"
  ### Example    : $mother = $object->parent($individual, "mother");
  ### Description: gets any related individuals
  ### Returns Bio::EnsEMBL::Variation::Individual

  my ($self, $ind_obj, $type)  = @_;
  my $call =  $type. "_Individual";
  my $parent = $ind_obj->$call;
  return {} unless $parent;

  # Gender is obvious, not calling their parents
  return  { Name => $parent->name,
    ### Description=> $self->individual_description($ind_obj),
  };
}


sub child {

  ### Sample_genotype_table_calls
  ### Args       : Bio::EnsEMBL::Variation::Individual object
  ### Example    : %children = %{ $object->extra_individual($individual)};
  ### Description: gets any related individuals
  ### Returns Bio::EnsEMBL::Variation::Individual

  my ($self, $individual_obj)  = @_;
  my %children;

  foreach my $individual ( @{ $individual_obj->get_all_child_Individuals} ) {
    my $gender = $individual->gender;
    $children{$individual->name} = [$gender, 
           $self->description($individual)];
  }
  return \%children;
}


sub get_samples_pops {

  ### Sample_genotype_table_calls
  ### Args       : Bio::EnsEMBL::Variation::Sample object
  ### Example    : $pops =  $object->get_samples_pop($sample)};
  ### Description: gets any sample''s populations
  ### Returns Bio::EnsEMBL::Variation::Population

  my ($self, $sample) = @_;
  my @populations = @{$sample->get_all_Populations};
  my @pop_string;

  foreach (@populations) {
    push (@pop_string,  {
      Name => $self->pop_name($_), 
      Link => $self->pop_links($_),
      ID => $_->dbID
    });
  }
  return \@pop_string;
}



# Variation sets ##############################################################

sub get_variation_set_string {
  my $self = shift;
  my @vs = ();
  my $vari_set_adaptor = $self->hub->database('variation')->get_VariationSetAdaptor;
  my $sets = $vari_set_adaptor->fetch_all_by_Variation($self->vari);

  my $toplevel_sets = $vari_set_adaptor->fetch_all_top_VariationSets;
  my $variation_string;
  my %sets_observed; 
  foreach (sort { $a->name cmp $b->name } @$sets){
    $sets_observed{$_->name}  =1 
  } 

  foreach my $top_set (@$toplevel_sets){
    next unless exists  $sets_observed{$top_set->name};
    $variation_string = $top_set->name ;
    my $sub_sets = $top_set->get_all_sub_VariationSets(1);
    my $sub_set_string = " (";
    foreach my $sub_set( sort { $a->name cmp $b->name } @$sub_sets ){ 
      next unless exists $sets_observed{$sub_set->name};
      $sub_set_string .= $sub_set->name .", ";  
    }
    if ($sub_set_string =~/\(\w/){
      $sub_set_string =~s/\,\s+$//;
      $sub_set_string .= ")";
      $variation_string .= $sub_set_string;
    }
    push(@vs,$variation_string);
  }
  return \@vs;
}

sub get_variation_sets {
  my $self = shift;
  my $vari_set_adaptor = $self->hub->database('variation')->get_VariationSetAdaptor;
  my $sets = $vari_set_adaptor->fetch_all_by_Variation($self->vari); 
  return $sets;
}

sub get_variation_sub_sets {

  my $self          = shift;
  my $superset_name = shift;

  my $vari_set_adaptor = $self->hub->database('variation')->get_VariationSetAdaptor;

  my $superset_obj = $vari_set_adaptor->fetch_by_name($superset_name);
  return unless defined $superset_obj;

  ## FIXME - temporary defensive coding until we have 76 handover! 
  my $sets = $self->species_defs->ENSEMBL_VERSION > 75 ? $vari_set_adaptor->fetch_all_by_Variation_super_VariationSet($self->vari, $superset_obj) : []; 
  return $sets;
}


# Variation mapping ###########################################################


sub variation_feature_mapping { ## used for snpview

  ### Variation_mapping
  ### Example    : my @vari_features = $object->variation_feature_mappin
  ### Description: gets the Variation features found on a variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

  my $self = shift;
  my $recalculate = shift;
 
  my %data;
  foreach my $vari_feature_obj (@{ $self->get_variation_features }) { 
     my $varif_id = $vari_feature_obj->dbID || $vari_feature_obj->location_identifier;
     $data{$varif_id}{Type}            = $vari_feature_obj->slice->coord_system_name;
     $data{$varif_id}{Chr}             = $vari_feature_obj->seq_region_name;
     $data{$varif_id}{start}           = $vari_feature_obj->seq_region_start;
     $data{$varif_id}{end}             = $vari_feature_obj->seq_region_end;
     $data{$varif_id}{strand}          = $vari_feature_obj->strand;
     $data{$varif_id}{transcript_vari} = $self->transcript_variation($vari_feature_obj, undef, $recalculate);
  }
  return \%data;
}

sub selected_variation_feature_mapping {
  my $self = shift;
  my $recalculate = shift;

  my $mappings = $self->variation_feature_mapping($recalculate);
  my $param = $self->param('vf');

  return $param ? $mappings->{$param} : {};
}


# Calls for variation features -----------------------------------------------

sub unique_variation_feature { 

  ### Variation_features
  ### Description: returns {{Bio::Ensembl::Variation::Feature}} object if
  ### this {{Bio::Ensembl::Variation}} has a unique mapping
  ### Returns undef if no mapping
  ### Returns a arrayref of single Bio::Ensembl::Variation::Feature object if one mapping
  ### Returns a arrayref of Bio::Ensembl::Variation::Feature object if multiple mapping

  my $self = shift;
  my @variation_features = @{ $self->get_variation_features || [] };
  return [] unless  @variation_features;
  return \@variation_features unless $#variation_features > 0; # if unique mapping

  # Must have multiple mapping
  my ($sr, $start, $type) = $self->seq_region_data;
  return \@variation_features unless $sr; #$sr undef if no unique mapping

  my @return;
  foreach (@variation_features) {  # try to find vf which matches unique mapping
    next unless $self->start($_) eq $start;
    next unless $self->region_name($_) eq $sr;
    next unless $self->region_type($_) eq $type;
    push @return, $_;
  }
  return \@return;
}



sub get_variation_features {

  ### Variation_features
  ### Example    : my @vari_features = $object->get_variation_features;
  ### Description: gets the Variation features found  on a variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::VariationFeatures

   my $self = shift; 
   return $self->vari ? $self->vari->get_all_VariationFeatures : [];
}

sub get_selected_variation_feature {
  my $self = shift;

  my $variation_feature;

  # have vf
  if(my $vf_param = $self->param('vf')) {
    ($variation_feature) = grep {$_->dbID eq $vf_param} @{$self->get_variation_features};
  }

  return $variation_feature;
}


sub transcript_variation {

  ### Variation_features
  ### Args[0]    : Bio::EnsEMBL::Variation::Variation::Feature
  ### Args[1]    : string transcript stable id (optional)
  ### Args[2]    : boolean recalculate (optional) - discards DB consequences and recalculates (used for HGMD)
  ### Example    : my $consequence = $object->consequence($vari);
  ### Description: returns SNP consequence (synonymous, stop gained, ...). If a transcript stable id is specifed, will only return transcript_variations on that transcript
  ### Returns arrayref of transcript variation objs

  my ($self, $vari_feature, $tr_stable_id, $recalculate) = @_;
  
  $self->hub->database('variation')->dnadb($self->database('core'));
  
  if($recalculate) {
    $vari_feature->allele_string('A/C/G/T');
    delete $vari_feature->{transcript_variations};
    delete $vari_feature->{dbID};
  }
  
  my $transcript_variation_obj =  $vari_feature->get_all_TranscriptVariations;
  
  return [] unless $transcript_variation_obj;

  my @data;
  foreach my $tvari_obj ( @{ $transcript_variation_obj } )  {
    next unless $tvari_obj->transcript;
    next if $tr_stable_id && $tvari_obj->transcript->stable_id ne $tr_stable_id;
     
    foreach my $tva_obj(@{ $tvari_obj->get_all_alternate_TranscriptVariationAlleles }) {
      my $type = join ", " , map {$_->SO_term} @{ $tva_obj->get_all_OverlapConsequences || [] };
  
      push (@data, {
              vf_allele =>        $tva_obj->variation_feature_seq,
              tr_allele =>        $tva_obj->feature_seq,
              conseq =>           $type,
              transcriptname =>   $tvari_obj->transcript->stable_id,
              proteinname  =>     $tvari_obj->transcript->translation ? $tvari_obj->transcript->translation->stable_id : '-',
              cdna_start =>       $tvari_obj->cdna_start,
              cdna_end =>         $tvari_obj->cdna_end,
              cds_start =>        $tvari_obj->cds_start,
              cds_end =>          $tvari_obj->cds_end,
              translation_start =>$tvari_obj->translation_start,
              translation_end =>  $tvari_obj->translation_end,
              pepallele =>        $tva_obj->pep_allele_string,
              codon =>            $tva_obj->display_codon_allele_string,
              tva =>              $tva_obj,
              tv  =>              $tvari_obj,
              vf  =>              $vari_feature,
              hgvs_genomic =>     $tva_obj->hgvs_genomic,
              hgvs_transcript =>  $tva_obj->hgvs_transcript,
              hgvs_protein =>     $tva_obj->hgvs_protein,
      });
    }
  }

  return \@data;
}



# LD stuff ###################################################################


sub ld_pops_for_snp {

  ### LD
  ### Description: gets an LDfeature container for this SNP and calls all the populations on this
  ### Returns array ref of population IDs

  my $self = shift; 
  my @vari_mappings = @{ $self->unique_variation_feature }; 
  return [] unless @vari_mappings;                    # must have mapping
  return [] unless $self->counts->{'samples'};    # must have genotypes

  my $pa = $self->Obj->adaptor->db->get_PopulationAdaptor;
  return [map {$_->dbID} @{$pa->fetch_all_LD_Populations}];
}


sub ld_location {
  my $self = shift;
  my ($sr, $start) = $self->_seq_region_;
  my $end = $start;
  my $length = $end - $start +1;
  my $offset = (20000 - $length)/2;
  $start -= $offset;
  $end += $offset;
  $start =~s/\.5//;
  $end =~s/\.5//;
  my $location = $sr .":". $start .'-'. $end;
  return $location;
}

sub find_location {

  ### LD
  ### Example    : my $data = $object->find_location
  ### Description: returns the genomic location for the current slice
  ### Returns hash of data

  my $self = shift;
  my $width = shift || $self->param('w') || 50000;
  unless ( $self->{'_slice'} ) {
    $self->_get_slice($width);
  }

  my $slice = $self->{'_slice'};
  return {} unless $slice;
  return $slice->name;
}

sub pop_obj_from_id {

  ### LD
  ### Args      : Population ID
  ### Example    : my $pop_name = $object->pop_obj_from_id($pop_id);
  ### Description: returns population name for the given population dbID
  ### Returns population object

  my $self = shift;
  my $pop_id = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pa  = $variation_db->get_PopulationAdaptor;
  my $pop_obj = $pa->fetch_by_dbID($pop_id);
  return {} unless $pop_obj;
  my %data;
  $data{$pop_id}{Name}    = $self->pop_name($pop_obj);
  $data{$pop_id}{Size}    = $self->pop_size($pop_obj);
  $data{$pop_id}{PopLink} = $self->pop_links($pop_obj);
  $data{$pop_id}{Description}= $self->pop_description($pop_obj);
  $data{$pop_id}{PopObject}= $pop_obj;  ## ok maybe this is cheating..
  return \%data;
}


sub get_default_pop_name {

  ### LD
  ### Example: my $pop_id = $object->get_default_pop_name
  ### Description: returns population id for default population for this species
  ### Returns population dbID

  my $self = shift;
  my $variation_db = $self->database('variation')->get_db_adaptor('variation');
  my $pop_adaptor = $variation_db->get_PopulationAdaptor;
  return unless $pop_adaptor;
  my $pop = $pop_adaptor->fetch_default_LDPopulation();
  return unless $pop;
  return [ $self->pop_name($pop) ];
}



sub location { return $_[0]; }

sub get_source {
  my $self = shift;

  my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }
  return $vari_adaptor->get_VariationAdaptor->get_all_sources();
}

=head2 hgvs

 Arg[0]      : int $vfid (optional)
 Description : Returns a hash with unique HGVS strings for the variation and variation feature with allele as key. 
               If multiple mappings, will pick the one specified or alternatively, the one stored in the hub.
 Return type : a hash ref

=cut

sub hgvs {
  my $self = shift;
  my $vfid = shift;
  my $tr_stable_id = shift;
  
  # Pick out the correct variation feature
  my $mappings      = $self->variation_feature_mapping;
  my $mapping_count = scalar keys %$mappings;
  
  # skip if no mapping or somatic mutation with mutation ref base different to ensembl ref base
  return {} unless $mapping_count && !$self->is_somatic_with_different_ref_base; 
  
  my $vf = $self->get_selected_variation_feature;  
  return {} unless $vf;
  
  # Get all transcript variations and put them in a hash with allele seq as key
  my %tvs_by_allele;
  
  push @{$tvs_by_allele{$_->{'vf_allele'}}}, $_ for @{$self->transcript_variation($vf,$tr_stable_id)};

  # Sort the HGVS notations so that LRGs end up last
  $tvs_by_allele{$_} = [ map $_->[1], sort { $a->[0] <=> $b->[0] } map [ $_->{'hgvs_genomic'} =~ /^LRG/ ? 1 : 0, $_ ], @{$tvs_by_allele{$_}} ] for keys %tvs_by_allele;
  
  # Loop over the transcript variations and get the unique (and interesting to us) HGVS notations
  my %hgvs;
  
  foreach my $allele (keys %tvs_by_allele) {
    my %seen_genomic;
    
    # Loop over the transcript variations 
    foreach my $tv (@{$tvs_by_allele{$allele}}) {      
      # Loop over the genomic, coding and protein HGVS strings
      foreach my $type ('hgvs_genomic', 'hgvs_transcript', 'hgvs_protein') {
        my $h = $tv->{$type};
        
        next if !$h || $type eq 'hgvs_genomic' && $seen_genomic{$h}++;
        
        push @{$hgvs{$allele}}, $h;
      }
    }
  }
 
  # add hgvs notations from the variation feature if there are no transcript variations
  # for the variation (intergenic variation)
  unless (%hgvs) {
    my %seen_genomic;
    my %hgvs_notations = %{$vf->get_all_hgvs_notations()};
    foreach my $allele (keys %hgvs_notations) {
      next if $seen_genomic{$hgvs_notations{$allele}}++;
      push @{$hgvs{$allele}}, $hgvs_notations{$allele};
    }
  }
  return \%hgvs;
}

sub get_hgvs_names_url {
  my $self        = shift;
  my $display_all = shift;
  
  # Get the HGVS names
  my $hgvs_hash = $self->hgvs(@_);
 
  # Loop over and format the URLs
  my %url;
  
  foreach my $allele (keys %$hgvs_hash) {
    foreach my $hgvs (@{$hgvs_hash->{$allele}}) {
      my $url = $self->hgvs_url($display_all,$hgvs);
      push @{$url{$allele}}, $url ? qq{<a href="$url->[0]" class="constant">$url->[1]</a>$url->[2]} : $hgvs;

    }
  }
  
  return \%url;
}
  
=head2 hgvs_url

 Arg[0]      : string $hgvs
 Arg[1]      : hashref $params (optional)
 Example     : my $url = hgvs_url('LRG_5_t1.4:c.345G>A',{v => $object->name()});
               echo '<a href="' . $url->[0] . '">' . $url->[1] . '</a>' . $url->[2];
 Description : Returns a listref with the url string, display name and remaining part of the hgvs
 Return type : an array ref

=cut

sub hgvs_url {
  my $self        = shift;
  my $display_all = shift;
  my $hgvs        = shift || '';
  my $params      = shift || {};
  my $obj         = $self->Obj;
  my $hub         = $self->hub;
  my $max_length  = 40;
  
  # Split the HGVS string into components. We are mainly interested in 1) Reference sequence, 2) Version (optional), 3) Notation type (optional) and 4) The rest of the description 
  my ($refseq, $version, $type, $description) = $hgvs =~ m/^((?:ENS[A-Z]*[GTP]\d+)|(?:LRG_\d+[^\.]*)|(?:[^\:]+?))(\.\d+)?\:(?:([mrcngp])\.)?(.*)$/;

  # Return undef if the HGVS could not be properly parsed (i.e. if the refseq and the description could not be obtained)
  return undef unless $refseq && $description;

  my $p = {
    action => 'Explore',
    db     => 'core',
    source => $obj->source_name,
    v      => $obj->name,
    r      => undef,
  };
  
  my $config_param = ($obj->is_somatic ? 'somatic_mutation_COSMIC=normal' : 'variation_feature_variation=normal') . ($obj->failed_description ? ',variation_set_fail_all=normal' : '');
  
  # Treat the URL differently depending on if it will take us to a regular page or a LRG page
  if ($refseq =~ /^LRG/) {
    my ($id, $tr_pr, $tr_pr_id) = $refseq =~ m/^(LRG_\d+)(t|p)?(\d+)?$/; # Split the reference into LRG_id, transcript or protein
    
    $p->{'type'}    = 'LRG';
    $p->{'lrg'}     = $id;
    $p->{'__clear'} = 1;
     
    if ($type eq 'g') { # genomic position
      $p->{'action'}           = 'Summary';
      $p->{'contigviewbottom'} = $config_param;
    } else {
      $p->{'action'} = 'Variation_LRG/Table';
      $p->{'lrgt'} = "${id}t$tr_pr_id";
    }
  } else {
    if (($type eq 'g') || ($type eq 'm')) { # genomic position
      $p->{'type'}             = 'Location';
      $p->{'action'}           = 'View';
      $p->{'contigviewbottom'} = $config_param;
    } elsif ($type eq 'p') { # protein position
      $p->{'type'}   = 'Transcript';
      $p->{'action'} = 'ProtVariations';
      $p->{'t'}      = $refseq.$version;
    } elsif (($type eq 'n') || ($type eq 'c')) {
      # transcript links only set for type 'n' or 'c'
      # $type eq c: cDNA position 
      # $type eq n: non-coding e.g. special cases where the variation falls in e.g. a pseudogene
      $p->{'type'}   = 'Transcript';
      $p->{'action'} = ($hub->species_defs->databases->{'DATABASE_VARIATION'} && $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary');
      $p->{'t'}      = $refseq.$version;
    } else {
      # Do not assign an url
      return undef;
    }
  }
  
  # Add or override the parameters with the ones supplied to the method
  $p->{$_} = $params->{$_} for keys %$params;
  
  my $hgvs_string;
  if ($display_all) {
    $hgvs_string =   substr($hgvs, length $refseq);
  } else {
    $hgvs_string = substr($hgvs, length $refseq, ($max_length - length $refseq)) . (length $hgvs > $max_length ? '...' : '');
  }
  # Return an arrayref with the elements: [0] -> URL, [1] -> display_name, [2] -> the rest of the HGVS string (capped at a maximum length)
  return [ $hub->url($p), encode_entities($refseq), encode_entities($hgvs_string) ];
}


## extract the names of any variants whch would be in the same location
## if both were described at the most 3' location possible
## insertions/ deletions only
sub get_three_prime_co_located{

    my $self = shift;

    my $attribs = $self->Obj->get_all_attributes();

    @{$self->{'shifted_co_located'}}  = ( exists $attribs->{"co-located allele"} ? split/\,/, $attribs->{"co-located allele"} : '');
    return $self->{'shifted_co_located'};
}


## extract data for table of publications citing this variant
sub get_citation_data{

    my $self = shift;

    $self->{'citation_data'} ||= $self->hub->database('variation')->get_PublicationAdaptor->fetch_all_by_Variation($self->vari);
    return $self->{'citation_data'};
}


## Allele/genotype colours
sub get_allele_genotype_colours {
  my $self = shift;
  my $raw = $self->raw_allele_colours();
  my %colours = map {$_ => '<span style="color:'.$raw->{$_}.'">'.$_.'</span>'} keys %$raw;
  return \%colours;
}

sub raw_allele_colours {
  my $self = shift;

  return {
    'A' => 'green',
    'C' => 'blue',
    'G' => '#ff9000',
    'T' => 'red',
    '-' => 'black'
  };
}

# Get SNPedia description from snpedia.com
sub get_snpedia_data {
  my ($self, $var_id) = @_;
  my $hub = $self->hub;
  my $snpedia_url = $hub->get_ExtURL('SNPEDIA');
  my $rest = EnsEMBL::Web::REST->new($hub, $snpedia_url);
  my $args= {
    'url_params' => {
      'action' => 'query',
      'prop' => 'revisions',
      'titles' => $var_id,
      'rvprop' => 'content',
      'maxlag' => '5',
      'format' => 'json',
      '_delimiter' => '&'
    }
  };

  my ($ref, $error) = $rest->fetch('api.php', $args);

  if($error || ref $ref ne 'HASH') {
    return {};
  }

  # get the page id and the page hashref with title and revisions
  my ($pageid, $pageref) = each %{ $ref->{query}->{pages} };
  # get the first revision
  my $rev = @{ $pageref->{revisions } }[0];
  # delete the revision from the hashref
  delete($pageref->{revisions});
  # if the page is missing then return the pageref
  return $pageref if ( defined $pageref->{missing} );

  # Parse description from the result by applying some heuristics
  # Tested working for most cases
  
  # Convert all newlines to *** to remove newline characters
  $rev->{'*'} =~s/\n+/***/g;

  # Remove PMID and Title
  $rev->{'*'} =~s/((\*{3})+\{\{PMID\|(\d+).*?\}\}.*(\.)?\*{3})//g;

  # Remove PMID Auto and Title
  # $rev->{'*'} =~s/(\{\{PMID Auto(.*)?\|PMID=(\d+).*?\}\}.*(\.)?)//g;
  $rev->{'*'} =~s/\{\{PMID Auto\*+?.*\}\}//g;
  $rev->{'*'} =~s/\{\{PMID Auto.*?\}\}//g;

  # Remove all content inside {{ }} except 'PMIDs inside a paragraph'
  $rev->{'*'} =~s/(\{\{(?!PMID).*?\}\})//g;

  # Link all PMIDs to EPMC
  $rev->{'*'} =~s/\{\{PMID\|(\d+)?.*?\}\}/"[" . $hub->get_ExtURL_link("PMID:$1", 'EPMC_MED', { 'ID' => encode_entities($1) }) . "]"/ge;
  $rev->{'*'} =~s/PMID\s(\d+)/$hub->get_ExtURL_link("PMID:$1", 'EPMC_MED', { 'ID' => encode_entities($1) })/ge;

  # Remove starting newline characters
  $rev->{'*'} =~s/^(\*{3})+//g;

  # Remove 'Further reading (with comments)'
  $rev->{'*'} =~s/Further reading \(with comments\)//g;

  # Convert '''text''' s to <b>text</b>
  $rev->{'*'} =~s/'''([^']+)'''/<b>$1<\/b>/g;

  # Link content inside [[ rs id ]] back to e!
  $rev->{'*'} =~s/\[\[(rs\d+?)\]\]/($1 ne $var_id) ? "<a href=\"" . $hub->url({ v => $1 }) . "\">$1<\/a>" : "<b>$1<\/b>"/ge;
  $rev->{'*'} =~s/\[\[(?!rs\d+)(.*?)\]\]/($1 ne $var_id) ? $hub->get_ExtURL_link($1, 'SNPEDIA_SEARCH', { 'ID' => encode_entities($1) }) : "<b>$1<\/b>"/ge;

  # Create html links for content like [url linktext]
  $rev->{'*'} =~s/\[(https?:\/\/.*?)\s(.*?)\]/<a href="$1">$2<\/a>/g;

  # Display only the first paragraph
  my @desc_arr = split(/\*\*\*+/, $rev->{'*'});

  # combine the pageid, the latest revision and the page title into one hash
  return { 'pageid'=>$pageid, %{ $rev }, 'desc'=>\@desc_arr, %{ $pageref } };
}

# Get the allele URI and genomic allele id (CAid) for a genomic HGVS
# from the Allele Registry (http://reg.clinicalgenome.org) using API ver 1.01.xx
#
# Example:
# GET: http://reg.test.genome.network/allele?hgvs=NC_000023.11:g.57448699T>C&fields=none+@id
# {
#   "@id": "http://reg.test.genome.network/allele/CA149611"
# }
sub get_allele_registry_data {
  my ($self, $hgvsg) = @_;

  my $hub = $self->hub;
  my $allele_registry_url = $hub->get_ExtURL('ALLELE_REGISTRY');
  return {} if (! $allele_registry_url);

  my $endpoint = 'allele';

  my $rest = EnsEMBL::Web::REST->new($hub, $allele_registry_url);
  my $args= {
    'url_params' => {
      'hgvs' => $hgvsg,
      'fields' => 'none+@id',
      '_delimiter' => '&',
    }
  };

  my ($ref, $error) = $rest->fetch($endpoint, $args);

  if($error || ref $ref ne 'HASH') {
    return {};
  }
  return {} if (! exists $ref->{'@id'});
  my ($caid) = $ref->{'@id'} =~ m#/(CA\d+)$#;
  return {} if (! $caid);
  return {'caid' => $caid, 'caid_uri' => $ref->{'@id'}};
}

# Get all the allele synonyms for a variation
sub get_allele_synonyms {
  my $self = shift;
  return $self->vari->get_all_AlleleSynonyms();
}

sub get_hgvsg {
  my $self = shift;

  # Pick out the correct variation feature
  my $mappings      = $self->variation_feature_mapping;
  my $mapping_count = scalar keys %$mappings;

  # skip if no mapping or somatic mutation with mutation ref base different to ensembl ref base
  return {} unless $mapping_count && !$self->is_somatic_with_different_ref_base;

  my $vf = $self->get_selected_variation_feature;
  return {} unless $vf;

  my $hgvs = $vf->get_all_hgvs_notations();
  return $hgvs;
}

1;
