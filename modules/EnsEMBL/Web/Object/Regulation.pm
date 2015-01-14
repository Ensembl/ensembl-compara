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

package EnsEMBL::Web::Object::Regulation;

### NAME: EnsEMBL::Web::Object::Regulation
### Wrapper around a Bio::EnsEMBL::Funcgen::RegulatoryFeature object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION


use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use base qw(EnsEMBL::Web::Object);

sub short_caption {
  my $self = shift;
  return "Regulation-based displays" unless shift eq 'global';
  return 'Regulation: ' . $self->Obj->stable_id;
}

sub caption {
  my $self    = shift;
  my $caption = 'Regulatory Feature: '. $self->Obj->stable_id;
  return $caption;    
}

sub default_action { return 'Summary'; }

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  $hash->{'regulation'} = 1 if $self->Obj->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature');
  return $hash;
}

sub counts {
  my $self = shift;
  my $obj  = $self->Obj;
  return {} unless $obj->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature');
  return {};  
}

sub _adaptor {
  my $self = shift;
  return $self->hub->get_adaptor('get_RegulatoryFeatureAdaptor', 'funcgen');
}

sub regulation        { my $self = shift; return $self->Obj;                            }
sub display_label     { my $self = shift; return $self->Obj->display_label;             }
sub stable_id         { my $self = shift; return $self->Obj->stable_id;                 }
sub analysis          { my $self = shift; return $self->Obj->analysis;                  }
sub attributes        { my $self = shift; return $self->Obj->regulatory_attributes;     }
sub bound_start       { my $self = shift; return $self->Obj->bound_start;               }
sub bound_end         { my $self = shift; return $self->Obj->bound_end;                 }
sub coord_system      { my $self = shift; return $self->Obj->slice->coord_system->name; }
sub seq_region_type   { my $self = shift; return $self->coord_system;                   }
sub seq_region_name   { my $self = shift; return $self->Obj->slice->seq_region_name;    }
sub seq_region_start  { my $self = shift; return $self->Obj->start;                     }
sub seq_region_end    { my $self = shift; return $self->Obj->end;                       }
sub seq_region_strand { my $self = shift; return $self->Obj->strand;                    }
sub feature_set       { my $self = shift; return $self->Obj->feature_set;               }   
sub feature_type      { my $self = shift; return $self->Obj->feature_type;              }
sub slice             { my $self = shift; return $self->Obj->slice;                     }           
sub seq_region_length { my $self = shift; return $self->Obj->slice->seq_region_length;  }

sub has_evidence {
  my ($self) = @_;

  # Can be simple accessor for 76, but avoid breaking master
  return 1 unless $self->hub->is_new_regulation_pipeline;
  return !!$self->Obj->has_evidence if $self->Obj->can('has_evidence');
  return undef;
}
sub cell_type_count {
  my ($self) = @_;

  # Can be simple accessor for 76, but avoid breaking master
  return $self->Obj->cell_type_count if $self->Obj->can('cell_type_count');
  return 0;
}

sub fetch_all_objs {
  my $self = shift;
  return $self->_adaptor->fetch_all_by_stable_ID($self->stable_id);
}

sub fetch_all_objs_by_slice {
  my ($self, $slice) = @_;
  my $reg_feature_adaptor = $self->_adaptor;
  my $objects_on_slice    = $reg_feature_adaptor->fetch_all_by_Slice($slice);
  my @all_objects;
  
  foreach my $rf (@$objects_on_slice) {
    push @all_objects, $_ for @{$reg_feature_adaptor->fetch_all_by_stable_ID($rf->stable_id)};
  }  

  return \@all_objects;
}

sub get_attribute_list {
  my $self = shift;
  my @attrib_feats = @{$self->Obj->regulatory_attributes('annotated')};
  return '-' unless @attrib_feats; 
  
  my @temp = map $_->feature_type->name, @attrib_feats;
  my $c    = 1;
  my %att_label;
  
  foreach my $k (@temp) { 
    if (exists  $att_label{$k}) {
      my $old = $att_label{$k};
      $old++;
      $att_label{$k} = $old;
    } else {
      $att_label{$k} = $c;
    }
  }
  
  my $attrib_list;
  
  foreach my $k (keys %att_label) {
    my $v = $att_label{$k};
    $attrib_list .= "$k($v), ";
  }
  
  $attrib_list =~ s/\,\s$//;

  return $attrib_list;
}

sub get_motif_features {
  my $self = shift;
  my @motif_features = @{$self->Obj->regulatory_attributes('motif')};
  my %motifs;
  foreach my $mf (@motif_features){

    my %assoc_ftype_names;
    map {$assoc_ftype_names{$_->feature_type->name} = undef} @{$mf->associated_annotated_features};
    my $bm_ftname = $mf->binding_matrix->feature_type->name;
    my @other_ftnames;
    foreach my $af_ftname(keys(%assoc_ftype_names)){
      push @other_ftnames, $af_ftname if $af_ftname ne $bm_ftname;
    }

    my $other_names_txt = '';

    if(@other_ftnames){
      $other_names_txt = ' ('.join(' ', @other_ftnames).')';
    }
    
    $motifs{$mf->start .':'. $mf->end} = [ $bm_ftname.$other_names_txt,  $mf->score, $mf->binding_matrix->name];
  }

  return \%motifs;
}

sub get_fg_db {
  my $self = shift;
  return $self->hub->database('funcgen');
}

sub get_feature_sets {
  my $self                = shift;  
  my $fg_db               = $self->get_fg_db;
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;
  my $spp                 = $self->species;
  my @fsets;
  my @sources;
  
  if ($spp eq 'Homo_sapiens') {
    @sources = ('RegulatoryFeatures', 'miRanda miRNA targets', 'cisRED search regions', 'cisRED motifs', 'VISTA enhancer set');
  } elsif ($spp eq 'Mus_musculus') {
    @sources = ('cisRED search regions', 'cisRED motifs');
  } elsif ($spp eq 'Drosophila_melanogaster') {
    @sources = ('BioTIFFIN motifs', 'REDfly CRMs', 'REDfly TFBSs');
  }

  push @fsets, $feature_set_adaptor->fetch_by_name($_) for @sources;
  
  return \@fsets;
}

sub get_location_url {
  my $self = shift;
  
  return $self->hub->url({
    type   => 'Location',
    action => 'View',
    rf     => $self->stable_id,
    fdb    => 'funcgen',
    r      => $self->location_string,
  });
}

sub get_bound_location_url {
  my $self = shift;
  
  return $self->hub->url({
    type   => 'Location',
    action => 'View',
    rf     => $self->stable_id,
    fdb    => 'funcgen',
    r      => $self->bound_location_string,
  });
}

sub get_summary_page_url {
  my $self = shift;
  
  return $self->hub->url({
    type   => 'Regulation',
    action => 'Summary',
    rf     => $self->stable_id,
    fdb    => 'funcgen',
  });
}

sub get_regulation_slice {
  my $self  = shift;
  my $slice = $self->Obj->feature_Slice;
  return $slice ? $self->new_object('Slice', $slice, $self->__data) : 1;
}

sub get_context_slice {
  my $self    = shift;
  my $padding = shift || 25000;
  return $self->Obj->feature_Slice->expand($padding, $padding) || 1;
}

sub show_signal {
  $_[0]->{'show_signal'} = $_[1] if @_>1;
  return $_[0]->{'show_signal'};
}

sub get_seq {
  my ($self, $strand) = @_;
  $self->Obj->{'strand'} = $strand;
  return $self->Obj->seq; 
}

sub get_bound_context_slice {
  my $self           = shift;
  my $padding        = shift || 1000; 
  my $slice          = $self->Obj->feature_Slice;

  # Need to take into account bounds on feature in all cell_lines
  my $bound_start = $self->bound_start;
  my $bound_end = $self->bound_end;
  my $reg_feature_adaptor = $self->get_fg_db->get_RegulatoryFeatureAdaptor;
  my $reg_objs            = $reg_feature_adaptor->fetch_all_by_stable_ID($self->stable_id);
  foreach my $rf (@$reg_objs) {
    if ($bound_start >= $rf->bound_start){ $bound_start = $rf->bound_start; } 
    if ($bound_end <= $rf->bound_end){ $bound_end = $rf->bound_end; }
  }

  my $offset_start   = $bound_start -$padding;
  my $offset_end     = $bound_end + $padding;
  my $padding_start  = $slice->start - $offset_start;
  my $padding_end    = $offset_end - $slice->end;
  my $expanded_slice = $slice->expand($padding_start, $padding_end); 

  return $expanded_slice;
}

sub chromosome {
  my $self = shift;
  return undef if lc $self->coord_system ne 'chromosome';
  return $self->Obj->slice->seq_region_name;
}

sub length {
  my $self = shift;
  my $length = ($self->seq_region_end - $self->seq_region_start) + 1;
  return $length;
}

sub location_string {
  my $self   = shift;
  my $offset = shift || 0;
  my $start  = $self->seq_region_start + $offset;
  my $end    = $self->seq_region_end   + $offset;

  return sprintf '%s:%s-%s', $self->seq_region_name, $start, $end;
}

sub bound_location_string {
  my $self  = shift;
  my $start = $self->bound_start;
  my $end   = $self->bound_end;

  return sprintf '%s:%s-%s', $self->seq_region_name, $start, $end;
}

sub get_evidence_data {
  my ($self, $slice,$filter) = @_;
  my $hub    = $self->hub;
  my $fset_a = $hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen');
  my $dset_a = $hub->get_adaptor('get_DataSetAdaptor',    'funcgen');
  my %data;

  my %cells;
  $filter ||= {};
  foreach my $regf_fset (@{$fset_a->fetch_all_by_type('regulatory')}) {
    my $multicell     = $regf_fset->cell_type->name eq 'MultiCell' ? 'MultiCell' : '';
    my $regf_data_set = $dset_a->fetch_by_product_FeatureSet($regf_fset);
    
    foreach my $reg_attr_fset (@{$regf_data_set->get_supporting_sets}) {
      my $cell_type             = $reg_attr_fset->cell_type->name;
      $cells{$cell_type} = 1 unless $cell_type eq 'MultiCell';
      next if $filter->{'cell'} and !grep { $_ eq $cell_type } @{$filter->{'cell'}};
      next if $filter->{'cells_only'};
      my $reg_attr_dset = $dset_a->fetch_by_product_FeatureSet($reg_attr_fset);
      my @sset          = @{$reg_attr_dset->get_displayable_supporting_sets('result')};

      throw("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t" . $reg_attr_dset->name) if scalar @sset > 1; # There should only be one
      
      my $feature_type          = $reg_attr_fset->feature_type->name;
      my $block_features        = $reg_attr_fset->get_Features_by_Slice($slice);
      my $set                   = $multicell || $reg_attr_fset->is_focus_set ? 'core' : 'non_core';
      my $key                   = $multicell || $cell_type;
      my $unique_feature_set_id = join ':', $key, $feature_type, $multicell ? $cell_type : ();
      
      $data{$key}{$set}{'block_features'}{$unique_feature_set_id} = $block_features if scalar @$block_features;
    }
  }
  
  return { data => \%data, cells => [ keys %cells ] };
}

sub all_cell_types {
  my ($self) = @_;
  my $hub    = $self->hub;
  my $fset_a = $hub->get_adaptor('get_FeatureSetAdaptor', 'funcgen');
  my $dset_a = $hub->get_adaptor('get_DataSetAdaptor',    'funcgen');

  my %cells;
  foreach my $regf_fset (@{$fset_a->fetch_all_by_feature_class('regulatory')}) {
    my $regf_data_set = $dset_a->fetch_by_product_FeatureSet($regf_fset);
    foreach my $reg_attr_fset (@{$regf_data_set->get_supporting_sets}) {
      my $cell_name = $reg_attr_fset->cell_type->name;
      next if $cell_name eq 'MultiCell';
      $cells{$cell_name} = 1;
    }
  }
  return [ sort keys %cells ];
}

################ Calls for Feature in Detail view ###########################

sub get_focus_set_block_features {
  my ($self, $slice) = @_;
  
  return unless $self->hub->param('opt_focus') eq 'yes';
  
  my (%data, %colours);
  
  foreach (@{$self->Obj->get_focus_attributes}) { 
    next if $_->isa('Bio::EnsEMBL::Funcgen::MotifFeature');
    my $unique_feature_set_id      = $_->feature_set->cell_type->name . ':' . $_->feature_set->feature_type->name;
    $data{$unique_feature_set_id} = $_->feature_set->get_Features_by_Slice($slice); 
    $colours{$_->feature_set->feature_type->name} = 1;
  }
  
  return (\%data, \%colours);
}

1;
