package EnsEMBL::Web::Command::Account::Interface::Group;

use strict;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $object    = $self->object;
  my $interface = $self->interface; ## Create interface object, which controls the forms
  my $data      = new EnsEMBL::Web::Data::Group($object->param('id'));
  
  $interface->data($data);
  $interface->discover;

  ## Customization
  ## Form elements
  $interface->caption({
    add  => 'Save group', 
    edit => 'Edit group'
  });
  
  $interface->permit_delete('yes');
  $interface->modify_element('name',  { type => 'String', label => 'Group name' });
  $interface->modify_element('blurb', { type => 'Text',   label => 'A brief description of your group'});
  $interface->element_order([ 'name', 'blurb' ]);

  ## Render page or munge data, as appropriate
  return $interface->configure($self);
}

1;
