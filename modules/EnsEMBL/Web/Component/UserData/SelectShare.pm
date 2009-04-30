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
  my $html;

  my $form = $self->modal_form('share', '/'.$object->data_species.'/UserData/CheckShare', {'wizard' => 1, 'back_button' => 0});

  my ($has_groups, @groups);
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && !$object->param('code')) { ## Can't share temp data with group
    @groups = $user->find_administratable_groups;
    $has_groups = $#groups > -1 ? 1 : 0;
  }
  my $info_text;
  if ($has_groups) {
    $form->add_element('type' => 'SubHeader', 'value' => 'Share with');
    $info_text = qq(You can share your saved data with one of the groups you administer,
                  or any data with anyone else even if they don't have an account with $sitename. 
                  Just select 'Anyone, via URL' to get a shareable link to your data.
    );
  }
  else {
    $info_text = qq(You can share your uploaded data with anyone, even if they don't have an
                  account with $sitename. Just select one or more of your uploads and click on 'Next'
                  to get a shareable link to your data.
    );
  }

  $info_text .= qq(Please note that these URLs expire after 72 hours, but if you save the upload
                  to your account, you can create a new shareable URL at any time.);

  $form->add_notes({heading => 'How it works', text => $info_text});

  if ($has_groups) {
    my @ids = ({'value' => 0, 'name' => 'Anyone, via URL'});
    foreach my $group (@groups) {
      push @ids, {'value'=>$group->id, 'name'=>$group->name};
    }
    $form->add_element('type'  => 'RadioGroup', 'name'  => 'webgroup_id', 'values' => \@ids);
    $form->add_element('type' => 'Hidden', 'name' => 'type', 'value' => $object->param('type'));
  }

  $form->add_attribute('class', 'narrow-labels');
  $form->add_element('type' => 'SubHeader', 'value' => 'Data to share');

  my @values = ();

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
  my @session_urls = $object->get_session->get_data(type => 'url');
  foreach my $url (@session_urls) {
    push @values, {
      name  => 'Temporary URL: ' . $url->{name},
      value => $url->{code},
    };
  }

  if ($user) {
    foreach my $record ($user->urls) {
      push @values, {
        name  => 'Saved URL: '. $record->name,
        value => $record->id,
      };
    }
  }

  ## If only one record, have the checkbox automatically checked
  my @autoselect = $object->param('id');
  push @autoselect, $object->param('code'); 
  warn "SELECTED: @autoselect";

  $form->add_element(
    type   => 'MultiSelect',
    name   => 'share_id',
    label  => 'Uploaded files',
    value  => \@autoselect,
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

  $html .= $form->render;
  return $html;
}

1;
