# $Id$

package EnsEMBL::Web::Component::UserData::SelectShare;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  return 'Share Your Data';
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $form     = $self->modal_form('share', $hub->species_path($hub->data_species).'/UserData/CheckShare', {'wizard' => 1, 'back_button' => 0});
  my $user     = $hub->user;
  my ($html, $has_groups, @groups);
  
  if ($user && !$hub->param('code')) { ## Can't share temp data with group
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
    $form->add_element('type' => 'Hidden', 'name' => 'type', 'value' => $hub->param('type'));
  }

  $form->set_attribute('class', 'narrow-labels');
  $form->add_element('type' => 'SubHeader', 'value' => 'Data to share');

  my @values = ();

  my @session_uploads = $session->get_data(type => 'upload');
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
  my @session_urls = $session->get_data(type => 'url');
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

  my @session_bams = $session->get_data(type => 'bam');
  foreach my $bam (@session_bams) {
    push @values, {
      name  => 'Temporary BAM: ' . $bam->{name},
      value => $bam->{code},
    };
  }

  if ($user) {
    foreach my $record ($user->bams) {
      push @values, {
        name  => 'Saved BAM: '. $record->name,
        value => $record->id,
      };
    }
  }


  ## If only one record, have the checkbox automatically checked
  my @autoselect = $hub->param('id');
  push @autoselect, $hub->param('code'); 
  warn "SELECTED: @autoselect";

  $form->add_element(
    type   => 'MultiSelect',
    name   => 'share_id',
    label  => 'Uploaded files',
    value  => \@autoselect,
    values => \@values
  );

  $html .= $form->render;
  return $html;
}

1;
