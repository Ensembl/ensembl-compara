package EnsEMBL::Web::Component::UserData::SelectShare;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Share Your Data';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  my $form = $self->modal_form('share', '/'.$object->data_species.'/UserData/CheckShare', {'wizard' => 1, 'back_button' => 0});
  $form->add_element('type' => 'SubHeader', 'value' => 'Share with');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @groups = $user->find_administratable_groups;
  my $has_groups = $#groups > -1 ? 1 : 0;

  if ($has_groups) {
    my @ids = ({'value' => 0, 'name' => 'Anyone, via URL'});
    foreach my $group (@groups) {
      push @ids, {'value'=>$group->id, 'name'=>$group->name};
    }
    $form->add_element('type'  => 'RadioGroup', 'name'  => 'webgroup_id', 'values' => \@ids);
    $form->add_element('type' => 'Hidden', 'name' => 'type', 'value' => $object->param('type'));
  }
  else {
    $form->add_notes({
      heading => 'How it works',
      text    => qq(You can share your uploaded data with anyone, even if they don't have an
                  account with $sitename. Just select one or more of your uploads and click on 'Next'
                  to get a shareable URL.
                  Please note that these URLs expire after 72 hours, but if you save the upload
                  to your account, you can create a new shareable URL at any time.)
    });
  }

  $form->add_attribute('class', 'narrow-labels');
  $form->add_element('type' => 'SubHeader', 'value' => 'Data to share');

  my @values = ();

  ## Session data
  my @session_uploads = $object->get_session->get_data(type => 'upload');
  foreach my $upload (@session_uploads) {
    push @values, {
      name  => 'Temporary upload: ' . $upload->{name},
      value => $upload->{code},
    };
  }

  if ($user) {
    foreach my $record ($user->uploads) {
      push @values, {
        name  => 'Saved upload: '. $record->name,
        value => $record->id,
      };
    }
  }

  ## If only one record, have the checkbox automatically checked
  my $autoselect = (@values == 1) ? [$values[0]->{'value'}] : '';

  $form->add_element(
    type   => 'MultiSelect',
    name   => 'share_id',
    label  => 'Uploaded files',
    value  => $autoselect,
    values => \@values
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => '_referer',
    'value'   => $object->param('_referer'),
  );
  $form->add_element(
    'type'    => 'Hidden',
    'name'    => 'x_requested_with',
    'value'   => $object->param('x_requested_with'),
  );

  return $form->render;
}

1;
