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

package EnsEMBL::Web::Object::Regulation;

### NAME: EnsEMBL::Web::Object::Regulation
### Wrapper around a Bio::EnsEMBL::Funcgen::RegulatoryFeature object

use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use EnsEMBL::Web::Object::Slice;

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

sub activity {
  my ($self, $epigenome) = @_;
  return unless $epigenome;

  if (ref $epigenome ne 'Bio::EnsEMBL::Funcgen::Epigenome') {
    my $db      = $self->hub->database('funcgen');
    my $adaptor = $db->get_adaptor('Epigenome');
    $epigenome  = $adaptor->fetch_by_short_name($epigenome);
  }
  return unless $epigenome;

  my $regact = $self->Obj->regulatory_activity_for_epigenome($epigenome);
  return $regact->activity if $regact;
  return undef;
}

sub cell_type_count {
  my ($self) = @_;

  # Can be simple accessor for 76, but avoid breaking master
  return $self->Obj->cell_type_count if $self->Obj->can('cell_type_count');
  return 0;
}
#fetch_all_by_stable_id is depracted
sub fetch_all_objs {
  my $self = shift;
  return $self->_adaptor->fetch_all_by_stable_ID($self->stable_id);
}

sub fetch_by_stable_id {
  my $self = shift;
  return $self->_adaptor->fetch_by_stable_id($self->stable_id);
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
  my $self    = shift;
  my $hub     = $self->hub;
  my $action  = $self->hub->action eq 'Multi' ? 'Multi' : 'View';

  my @other_spp_params = grep {$_ =~ /^s[\d+]$/} $hub->param;
  my %other_spp;
  foreach (@other_spp_params) {
    $other_spp{$_} = $hub->param($_);
  }

  return $self->hub->url({
    type   => 'Location',
    action => $action,
    rf     => $self->stable_id,
    fdb    => 'funcgen',
    r      => $self->location_string,
    %other_spp,
  });
}

sub get_bound_location_url {
  my $self    = shift;
  my $hub     = $self->hub;
  my $action  = $self->hub->action eq 'Multi' ? 'Multi' : 'View';

  my @other_spp_params = grep {$_ =~ /^s[\d+]$/} $hub->param;
  my %other_spp;
  foreach (@other_spp_params) {
    $other_spp{$_} = $hub->param($_);
  }

  return $self->hub->url({
    type   => 'Location',
    action => $action,
    rf     => $self->stable_id,
    fdb    => 'funcgen',
    r      => $self->bound_location_string,
    %other_spp,
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
  my $rf                  = $reg_feature_adaptor->fetch_by_stable_id($self->stable_id);
  if ($bound_start >= $rf->bound_start){ $bound_start = $rf->bound_start; }
  if ($bound_end <= $rf->bound_end){ $bound_end = $rf->bound_end; }

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
  my $self = shift;
  my $data = {};

  my $reg_feature = $self->Obj;
  my $hub         = $self->hub;

  my $active_epigenomes     = {};
  my @activities            = @{$reg_feature->regulatory_activity||[]};
  foreach my $activity (@activities) {
    my $epigenome = $activity->get_Epigenome;
    $active_epigenomes->{$epigenome->short_name} = 1;
  }

  my $peak_calling_adaptor  = $hub->get_adaptor('get_PeakCallingAdaptor', 'funcgen');
  my $all_peak_calling      = $peak_calling_adaptor->fetch_all;

  foreach my $peak_calling (@{$all_peak_calling||[]}) {

    my $epigenome   = $peak_calling->get_Epigenome;
    my $cell_line   = $epigenome->short_name;
    next unless $active_epigenomes->{$cell_line};

    my $ftype       = $peak_calling->get_FeatureType;
    my $ftype_name  = $ftype->name;

    $data->{$cell_line}{$ftype_name} = $peak_calling;
  }

  return $data;
}

sub all_epigenomes {
  my ($self) = @_;
  
  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    return [sort keys %{$self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'names'}}];
  }

  return [];
}

sub regbuild_epigenomes {
  my ($self) = @_;

  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    return $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'regbuild_names'};
  }

  return {};
}

################ Calls for Feature in Detail view ###########################

sub get_focus_set_block_features {
  my ($self, $slice, $opt_focus) = @_;

  return unless $opt_focus eq 'yes';

  my (%data, %colours);

#  foreach (@{$self->Obj->get_focus_attributes}) {
#    next if $_->isa('Bio::EnsEMBL::Funcgen::MotifFeature');
#    my $unique_feature_set_id      = $_->feature_set->cell_type->name . ':' . $_->feature_set->feature_type->name;
#    $data{$unique_feature_set_id} = $_->feature_set->get_Features_by_Slice($slice);
#    $colours{$_->feature_set->feature_type->name} = 1;
#  }

  return (\%data, \%colours);
}

1;
