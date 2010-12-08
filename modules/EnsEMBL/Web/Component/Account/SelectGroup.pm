package EnsEMBL::Web::Component::Account::SelectGroup;

use strict;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Share Record';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $form = $self->new_form({'id' => 'select_group', 'action' => '/Account/ShareRecord'});
  my $fieldset = $form->add_fieldset;
  my $user = $object->user;
  my @admin_groups = $user->find_administratable_groups;

  my $count = scalar @admin_groups;

  return '<p>No groups found</p>' unless $count;
  
  $fieldset->add_hidden([
    {'name'  => 'id',   'value' => $object->param('id')},
    {'name'  => 'type', 'value' => $object->param('type')}
  ]);

  my $element = {'type' => 'radiolist', 'name' => 'webgroup_id', 'values' => []};
  push @{$element->{'values'}}, {'value' => $_->id, 'caption' => $_->name} for @admin_groups;
  $element->{'value'} = $admin_groups[0] if $count == 1;

  $fieldset->add_element([$element, {'type'  => 'Submit', 'name'  => 'submit', 'value' => 'Share', 'class' => 'modal_link'}]);

  return $form->render;
}

1;
