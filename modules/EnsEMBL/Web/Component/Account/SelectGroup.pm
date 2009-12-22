package EnsEMBL::Web::Component::Account::SelectGroup;

### Module to create user login form 

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Form;

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
  my $objcet = $self->object;
  my $form = EnsEMBL::Web::Form->new( 'select_group', "/Account/ShareRecord", 'post' );
  my $user = $object->user;
  my @admin_groups = $user->find_administratable_groups;

  my $count = scalar(@admin_groups);
  if ($count > 1) {
    my @ids;
    foreach my $group (@admin_groups) {
      push @ids, {'value'=>$group->id, 'name'=>$group->name};
    }
    $form->add_element('type'  => 'RadioGroup', 'name'  => 'webgroup_id',
                        'label' => '', 'values' => \@ids);
  }
  else {
    my $group = $admin_groups[0];
    $form->add_element('type'  => 'RadioButton', 'name'  => 'webgroup_id', 
                      'label' => $group->name, 'value' => $group->id, 'checked' => 'checked');
  }
  $form->add_element('type'  => 'Hidden', 'name'  => 'id', 'value' => $object->param('id'));
  $form->add_element('type'  => 'Hidden', 'name'  => 'type', 'value' => $object->param('type'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Share', 'class' => 'modal_link');

  return $form->render;
}

1;
