# $Id$

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object; 
 
  return unless $object->param('rf'); 
  
  my $core_reg_obj;
  my $funcgen_db = $object->database('funcgen');
  my $reg_feature_adaptor = $funcgen_db->get_RegulatoryFeatureAdaptor; 
  my $reg_objs = $reg_feature_adaptor->fetch_all_by_stable_ID($object->param('rf'));  
  foreach my $rf ( @$reg_objs){
    if ($object->param('cl')){
      my $cell_line = $object->param('cl');
      if ($rf->feature_set->cell_type->name =~/$cell_line/i){
        $core_reg_obj = $rf;
      }
    } else {
      if ($rf->feature_set->cell_type->name =~/multi/i){
        $core_reg_obj = $rf;
      }
    } 
  }

 my $reg_obj = $self->new_object('Regulation', $core_reg_obj, $object->__data); 

 
  $self->caption('Regulatory Feature');
  
  $self->add_entry({
    type  => 'Stable ID',
    label => $reg_obj->stable_id,
    link  => $reg_obj->get_details_page_url
  });
  
  $self->add_entry({
    type  => 'Type',
    label => $reg_obj->feature_type->name
  });
  
  $self->add_entry({
    type  => 'bp',
    label => $reg_obj->location_string,
    link  => $reg_obj->get_location_url
  });
  
  $self->add_entry({
    type  => 'Attributes',
    label => $reg_obj->get_attribute_list
  });
}

1;
