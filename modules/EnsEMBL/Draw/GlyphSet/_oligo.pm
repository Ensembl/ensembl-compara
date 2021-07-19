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

package EnsEMBL::Draw::GlyphSet::_oligo;

### Draws oligoprobe tracks

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Draw::GlyphSet::_alignment);

sub features { 
  my ($self) = @_;
  my $slice = $self->{'container'};
  
  my $fg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($self->{'container'}->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $self->{'container'}->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }; 
  my $probe_feature_adaptor = $fg_db->get_ProbeFeatureAdaptor();

  my ($vendor_name, $array_name ) = split (/__/, $self->my_config('array')); 
  my $T = $probe_feature_adaptor->fetch_all_by_Slice_array_vendor( $slice, $array_name, $vendor_name );
  return ( $self->my_config('array') => [$T] );
}

sub feature_group {
  my( $self, $f ) = @_; 
  next unless ( $f && $f->isa('Bio::EnsEMBL::Funcgen::ProbeFeature'));
  my ($vendor_name, $array_name ) = split (/__/, $self->my_config('array')); 
  if ( $f->probe_set_id) { 
    return $f->probe->probeset->name;
  } else { 
    return $f->probe->get_probename($array_name);
  }  
}

sub feature_label {
  my( $self, $f ) = @_;
  return $self->feature_group($f);
}

sub feature_title {
  my( $self, $f ) = @_; 
  return $self->feature_group($f);
}

sub href {
### Links to /Location/Genome with type of 'ProbeFeature'
  my ($self, $f ) = @_;
  my ($vendor, $array_name ) = split (/__/, $self->my_config('array'));
  my ($probe_name, $probe_type);
  if ( $f->probe_set_id) {
    $probe_name = $f->probe->probeset->name;
    $probe_type = 'pset';
  } else { 
    $probe_name = $f->probe->get_probename($array_name);
    $probe_type = 'probe';
  }  

  return $self->_url({
    'type' => 'Location',
    'action' => 'Oligo',
    'fdb'    => 'funcgen',
    'ftype'  => 'ProbeFeature',
    'id'     => $probe_name,
    'ptype'  => $probe_type,
    'vendor' => $vendor,
    'array'  => $array_name,
  }); 
}

sub export_feature {
  my $self = shift;
  my ($feature, $source) = @_;
  return; 
#  return $self->_render_text($feature, 'Oligo', {
#    'headers' => [ 'probeset' ],
#    'values' => [ $feature->can('probeset') ? $feature->probeset : '' ]
#  }, { 'source' => $source });
}

1
