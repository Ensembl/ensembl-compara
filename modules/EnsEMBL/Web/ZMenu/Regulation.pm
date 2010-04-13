# $Id$

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object = $self->object; 
 
  return unless $object->param('rf'); 
  
  my $reg_obj = $self->model->object('Regulation');
  
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
