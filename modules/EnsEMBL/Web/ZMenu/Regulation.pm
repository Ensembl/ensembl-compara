# $Id$

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $rf   = $hub->param('rf');
 
  return unless $rf; 
  
  my $object              = $self->object;
  my $cell_line           = $hub->param('cl');
  my $funcgen_db          = $hub->database('funcgen');
  my $reg_feature_adaptor = $funcgen_db->get_RegulatoryFeatureAdaptor; 
  my $reg_objs            = $reg_feature_adaptor->fetch_all_by_stable_ID($rf);
  my $core_reg_obj;
  
  foreach my $rf (@$reg_objs) {
    if ($cell_line) {
      $core_reg_obj = $rf if $rf->feature_set->cell_type->name =~ /$cell_line/i;
    } elsif ($rf->feature_set->cell_type->name =~ /multi/i) {
      $core_reg_obj = $rf;
    }
  }
  
  $self->caption('Regulatory Feature');
  
  $self->add_entry({
    type  => 'Stable ID',
    label => $object->stable_id,
    link  => $object->get_details_page_url
  });
  
  $self->add_entry({
    type  => 'Type',
    label => $object->feature_type->name
  });
  
  $self->add_entry({
    type  => 'Core bp',
    label => $object->location_string,
    link  => $object->get_location_url
  });

  unless ($object->bound_start == $object->seq_region_start && $object->bound_end == $object->seq_region_end) {
    $self->add_entry({
      type  => 'Bounds bp',
      label => $object->bound_location_string,
      link  => $object->get_bound_location_url
    });
  }
  
  $self->add_entry({
    type  => 'Attributes',
    label => $object->get_attribute_list
  });
}

1;
