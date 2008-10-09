package EnsEMBL::Web::Component::Account::SelectGroup;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

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

  my $form = EnsEMBL::Web::Form->new( 'select_group', "/Account/ShareRecord", 'post' );

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @admin_groups = $user->find_administratable_groups;

  my $count = $#admin_groups;
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
  $form->add_element('type'  => 'Hidden', 'name'  => 'id', 'value' => $self->object->param('id'));
  $form->add_element('type'  => 'Hidden', 'name'  => 'type', 'value' => $self->object->param('type'));
  $form->add_element('type'  => 'Hidden', 'name'  => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Share', 'class' => 'cp-internal');

  return $form->render;
}

1;
