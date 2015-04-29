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

package EnsEMBL::Web::ZMenu::SegFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my $self              = shift;
  my $hub               = $self->hub; 
  my $object            = $self->object;  
  my $cell_line         = $hub->param('cl');
  my $dbid              = $hub->param('dbid');
     
  my $funcgen_db          = $hub->database('funcgen');
  my $seg_feature_adaptor = $funcgen_db->get_SegmentationFeatureAdaptor; 
  my $seg_feat            = $seg_feature_adaptor->fetch_by_dbID($dbid);  
  my $location            = $seg_feat->slice->seq_region_name . ':' . $seg_feat->start . '-' . $seg_feat->end;
  
  $self->caption('Regulatory Segment - ' . $cell_line);

  $self->add_entry ({
    type   => 'Type',
    label  => $seg_feat->feature_type->name,
  });
  
  $self->add_entry({
    type       => 'Location',
    label_html => $location,
    link       => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $location
    })
  });
  
  $self->add_entry ({
    type        => 'Analysis',
    label_html  => $seg_feat->analysis->description,
  });

  $self->_add_nav_entries;      
}

1;
