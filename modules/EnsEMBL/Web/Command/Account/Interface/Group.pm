package EnsEMBL::Web::Command::Account::Interface::Group;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  ## Create interface object, which controls the forms
  my $interface = EnsEMBL::Web::Interface->new;
  my $data = EnsEMBL::Web::Data::Group->new($object->param('id'));
  
  $interface->data($data);
  $interface->discover;

  ## Customization
## Form elements
  $interface->caption({add  => 'Save group'});
  $interface->caption({edit => 'Edit group'});
  $interface->permit_delete('yes');
  $interface->modify_element('name',         { type => 'String', label => 'Group name'});
  $interface->modify_element('blurb',  { type => 'Text',   label => 'A brief description of your group'});
  $interface->element_order([qw/name blurb/]);

  ## Render page or munge data, as appropriate
  $interface->configure($self->webpage, $object);
}

}

1;
