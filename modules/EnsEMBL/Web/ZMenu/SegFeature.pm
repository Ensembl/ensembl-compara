# $Id$

package EnsEMBL::Web::ZMenu::SegFeature;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

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
    type   => 'Analysis',
    label  => $seg_feat->analysis->description,
  });
      
}

1;