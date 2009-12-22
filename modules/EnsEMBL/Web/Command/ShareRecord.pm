package EnsEMBL::Web::Command::ShareRecord;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $user = $object->user;

  my $url = $object->species_path($object->data_species) . '/';
  my $param = {};

  my $group = EnsEMBL::Web::Data::Group->new($object->param('webgroup_id'));
  my @ids = ($object->param('id'));

  if ($group && $user->is_administrator_of($group)) {
    foreach my $id (@ids) {
      next unless $id;
      my $user_record = EnsEMBL::Web::Data::Record->new('owner' => 'user', 'id' => $id);
      next unless $user_record && $user_record->user_id == $user->id;
      my $clone = $user_record->clone;
      $clone->owner($group);
      $clone->save;
    }
    $param->{'id'} = $group->id;
    $url .= 'Account/Group/List';
  } 
  else {
    $param->{'filter_module'} = 'Shareable';
    $param->{'filter_code'} = 'no_group';
    $url .= 'UserData/ManageData';
  }
 
  $self->ajax_redirect($url, $param);
}

1;
