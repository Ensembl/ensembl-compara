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

package EnsEMBL::Web::Object::StructuralVariation;

### NAME: EnsEMBL::Web::Object::StructuralVariation
### Wrapper around a Bio::EnsEMBL::StructuralVariation

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-structural-variation-%d-%s-%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    'structural variation',
    $self->name;
  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;

  if (!$self->{'_availability'}) {
    my $counts = $self->counts;
    my $availability = $self->_availability;
    my $obj = $self->Obj;

    if ($obj->isa('Bio::EnsEMBL::Variation::StructuralVariation')) {
    
      my $counts = $self->counts;
      
      $availability->{'structural_variation'} = 1;
    
      $availability->{"has_$_"} = $counts->{$_} for qw(transcripts supporting_structural_variation phenotypes);
      
      $availability->{'has_phenotype'} = 1 if ($self->has_phenotype || $availability->{'has_transcripts'});
 
      $self->{'_availability'} = $availability;
    }
  }
  return $self->{'_availability'};
}


sub counts {
  my $self  = shift;
  my $obj   = $self->Obj;
  my $hub   = $self->hub;
  my $cache = $hub->cache;

  return {} unless $obj->isa('Bio::EnsEMBL::Variation::StructuralVariation');

  my $svf  = $hub->param('svf');
  my $key = sprintf '::Counts::StructuralVariation::%s::%s::%s::', $self->species, $hub->param('vdb'), $hub->param('sv');
  $key   .= $svf . '::' if $svf;

  my $counts = $self->{'_counts'};
  $counts ||= $cache->get($key) if $cache;

  unless ($counts) {
    $counts = {};
    $counts->{'transcripts'} = $self->count_transcripts;
    $counts->{'supporting_structural_variation'} = $self->count_supporting_structural_variation;
    $counts->{'phenotypes'} = $self->count_phenotypes;

    $cache->set($key, $counts, undef, 'COUNTS') if $cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}

sub count_phenotypes {
  my $self = shift;

  my $counts = 0;
  my $pf_objects = $self->hub->database('variation')->get_PhenotypeFeatureAdaptor->fetch_all_by_StructuralVariation($self->Obj);
  if ($pf_objects) {
    my %phenotypes = map { $_->phenotype_id => 1 } @$pf_objects;
    $counts = scalar keys %phenotypes;
  }

  return $counts;
}

sub count_supporting_structural_variation {
  my $self = shift;
  my @ssvs = @{$self->supporting_sv};
  my $counts = scalar @ssvs || 0; 
  return $counts;  
}

sub count_transcripts {
  my $self = shift;
  my $counts = 0;
    
  my $slice_adaptor = $self->hub->get_adaptor('get_SliceAdaptor');  
  
  foreach my $sv_feature_obj (@{ $self->get_structural_variation_features }) {
      
    my $type   = $sv_feature_obj->coord_system_name;
    my $region = $sv_feature_obj->seq_region_name;
    my $start  = $sv_feature_obj->seq_region_start;
    my $end    = $sv_feature_obj->seq_region_end;
    my $strand = $sv_feature_obj->seq_region_strand;
      
    my $slice = $slice_adaptor->fetch_by_region($type, $region, $start, $end, $strand);
   
    $counts = scalar @{$slice->get_all_Transcripts};
    last if ($counts != 0);
  }
  return $counts;
}

sub has_phenotype {
  my $self = shift;
  my @ssvs = @{$self->supporting_sv};
  foreach my $ssv (@ssvs) {
    my $pfs = $ssv->get_all_PhenotypeFeatures();
    foreach my $pf (@$pfs) {
      return 1 if ($pf->phenotype && $pf->phenotype->description);
    }
  }
  return undef;
}


sub short_caption {
  my $self = shift;

  my $type = 'Structural variant';
  if ($self->class eq 'CNV_PROBE') {
     $type = 'CNV probe';
  }
  elsif($self->is_somatic) {
     $type = 'Somatic SV';
  }
  my $short_type = 'S. Var';
  return $type.' displays' unless shift eq 'global';

  my $label = $self->name;
  return length $label > 30 ? "$short_type: $label" : "$type: $label";
}


sub caption {
 my $self = shift;
 my $type = 'Structural variant';
 if ($self->class eq 'CNV_PROBE') {
   $type = 'Copy number variant probe';
 }
 elsif($self->is_somatic) {
   $type = 'Somatic structural variant';
 }
 my $caption = $type.': '.$self->name;

 return $caption;
}

sub name                  { my $self = shift; return $self->Obj->variation_name;                                         }
sub class                 { my $self = shift; return $self->Obj->var_class;                                              }
sub source_name           { my $self = shift; return $self->Obj->source_name;                                            }
sub source_description    { my $self = shift; return $self->Obj->source_description;                                     }
sub study                 { my $self = shift; return $self->Obj->study;                                                  }
sub study_name            { my $self = shift; return (defined($self->study)) ? $self->study->name : undef;               }
sub study_description     { my $self = shift; return (defined($self->study)) ? $self->study->description : undef;        }
sub study_url             { my $self = shift; return (defined($self->study)) ? $self->study->url : undef;                }
sub external_reference    { my $self = shift; return (defined($self->study)) ? $self->study->external_reference : undef; }
sub supporting_sv         { my $self = shift; return $self->Obj->get_all_SupportingStructuralVariants;                   }
sub is_somatic            { my $self = shift; return $self->Obj->is_somatic;                                             }
sub clinical_significance { my $self = shift; return $self->Obj->get_all_clinical_significance_states;                   }
sub default_action        { return 'Explore'; }
sub max_display_length    { return 1000000; }

sub validation_status  { 
  my $self = shift; 
  my $status = $self->Obj->validation_status();
  return ($status) ? $status : '';
}    

# SSV associated colours
sub get_class_colour {
  my $self  = shift;
  my $class = shift;

  my $colour = $self->hub->species_defs->colour('structural_variant');
  my $c = $colour->{$class}{'default'};
  $c = '#B2B2B2' if (!$c);
  return $c;
}

sub get_phenotype_features {
  my $self = shift;
  return $self->Obj->get_all_PhenotypeFeatures;
}


# Variation sets ##############################################################

sub get_variation_set_string {
  my $self = shift;
  my @vs = ();
  my $vari_set_adaptor = $self->hub->database('variation')->get_VariationSetAdaptor;
  my $sets = $vari_set_adaptor->fetch_all_by_StructuralVariation($self->Obj);

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
  my $sets = $vari_set_adaptor->fetch_all_by_Variation($self->Obj); 
  return $sets;
}


# Structural Variation Feature ###########################################################

sub variation_feature_mapping { 

  ### Variation_mapping
  ### Example    : my @sv_features = $object->variation_feature_mapping
  ### Description: gets the Structural Variation features found on a structural variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::StructuralVariationFeatures

  my $self = shift;
 
  my %data;
  foreach my $sv_feature_obj (@{ $self->get_structural_variation_features }) { 
     my $svf_id = $sv_feature_obj->dbID;
     $data{$svf_id}{Type}             = $sv_feature_obj->slice->coord_system_name;
     $data{$svf_id}{Chr}              = $sv_feature_obj->seq_region_name;
     $data{$svf_id}{start}            = $sv_feature_obj->start;
     $data{$svf_id}{end}              = $sv_feature_obj->end;
     $data{$svf_id}{strand}           = $sv_feature_obj->strand;
     $data{$svf_id}{outer_start}      = $sv_feature_obj->outer_start;
     $data{$svf_id}{inner_start}      = $sv_feature_obj->inner_start;
     $data{$svf_id}{inner_end}        = $sv_feature_obj->inner_end;
     $data{$svf_id}{outer_end}        = $sv_feature_obj->outer_end;
     $data{$svf_id}{is_somatic}       = $sv_feature_obj->is_somatic;
     $data{$svf_id}{breakpoint_order} = $sv_feature_obj->breakpoint_order;
     $data{$svf_id}{transcript_vari}  = undef;
  }
  return \%data;
}

sub get_structural_variation_features {

  ### Structural_Variation_features
  ### Example    : my @sv_features = $object->get_structural_variation_features;
  ### Description: gets the Structural Variation features found  on a variation object;
  ### Returns Arrayref of Bio::EnsEMBL::Variation::StructuralVariationFeatures

   my $self = shift; 
   return $self->Obj ? $self->Obj->get_all_StructuralVariationFeatures : [];
}

sub not_unique_location {
  my $self = shift;
  unless ($self->hub->core_param('svf') ){
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

sub show_size {
  my $self = shift;
  my $obj  = shift;
  $obj ||= $self->Obj;
  my $SO_term = $obj->class_SO_term;
  return 1 if ($SO_term =~ /copy|deletion|duplication|inversion/);
  return 0;
}


1;
