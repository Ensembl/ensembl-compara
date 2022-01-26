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

package EnsEMBL::Draw::GlyphSet::fg_background_regulation;

### Needed to shade the region covered by a regulatory feature in regulation detailed view.

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self              = shift;
  my $config            = $self->{'config'};
  my $slice             = $self->{'container'}; 
  my $target_feature_id = $self->{'config'}->core_object('regulation')->stable_id;  
  my $strand            = $self->strand; 
  my $colour            = 'lightcoral';
  my $x                 = 0;
  my $x_end             = 0;
  my $pix_per_bp        = $config->transform_object->scalex;

  return unless $config->get_parameter('opt_highlight') eq 'yes';

  my $fg_db   = undef;
  my $db_type = $self->my_config('db_type') || 'funcgen';
  
  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    
    if (!$fg_db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }
  
  my $reg_feat_adaptor = $fg_db->get_RegulatoryFeatureAdaptor;
  my $features         = $reg_feat_adaptor->fetch_all_by_Slice($slice);
  
  foreach my $f (@$features) {
    next unless $f->stable_id eq $target_feature_id;
    
    $x     = $f->start -1;
    $x_end = $f->end;
  }
   
  my $glyph = $self->Space({
    x      => $x,
    y      => 0,
    width  => $x_end - $x + 1,
    height => 0,
    colour => $colour
  });

  $self->join_tag($glyph, 'regfeat-start', 0, 0, $colour, '', 99999);
  $self->join_tag($glyph, 'regfeat-end',   1, 0, $colour, '', 99999);
  $self->push($glyph);
}

1;
