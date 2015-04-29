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

package EnsEMBL::Draw::GlyphSet::fg_segmentation_features;

### Draw regulatory segmentation features track (semi-continuous
### track of colour blocks)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub squish { return 1; }

sub features {
  my $self    = shift;
  my $slice   = $self->{'container'};    
  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $fg_db;  
  
  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    
    if(!$fg_db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }
  
  return $self->fetch_features($fg_db);
}

sub fetch_features {
  my ($self, $db) = @_;
  my $slice     = $self->{'container'};
  my $cell_line = $self->my_config('cell_line');  
  my $fsa       = $db->get_FeatureSetAdaptor();
  my $cta       = $db->get_CellTypeAdaptor;
  
  if (!$fsa || !$cta) {
    warn ("Cannot get get adaptors: $fsa");
    return [];
  }
  
  my $ctype = $cta->fetch_by_name($cell_line);
  my $fsets = $fsa->fetch_all_displayable_by_type('segmentation', $ctype); 
  
  warn "Failed to get unique $cell_line segmentation feature set" unless scalar @$fsets == 1;
  
  $self->{'legend'}{'fg_regulatory_features_legend'} ||= { priority => 1020, legend => [] };  
  
  return $fsets->[0]->get_Features_by_Slice($slice);
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    action   => 'SegFeature',
    ftype    => 'Regulation',
    dbid     => $f->dbID,
    species  => $self->species,
    fdb      => 'funcgen',
    cl       => $self->my_config('cell_line'),
  });
}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name;
 
  if ($type =~ /Repressed/ or $type =~ /low activity/) {
    $type = 'repressed';
  } elsif ($type =~ /CTCF/) {
    $type = 'ctcf';
  } elsif ($type =~ /Enhancer/) {
    $type = 'enhancer';
  } elsif ($type =~ /Flank/) {
    $type = 'promoter_flanking';
  } elsif ($type =~ /TSS/) {
    $type = 'promoter';
  } elsif ($type =~ /Transcribed/) {
    $type = 'region';
  } elsif ($type =~ /Weak/) {
    $type = 'weak';
  } elsif ($type =~ /Heterochr?omatin/i) { # ? = typo in e76
    $type = 'heterochromatin';
  } else {
    $type = 'default';
  }
  return lc $type;
}

1;
