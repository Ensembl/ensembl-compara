# $Id$

package EnsEMBL::Web::Component::UserData::SelectShare;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $form     = $self->modal_form('share', $hub->url({ action => 'CheckShare', __clear => 1 }), { wizard => 1, back_button => 0 });
  my $session  = $hub->session;
  my $user     = $hub->user;
  #my @groups   = $user && !$hub->param('code') ? $user->find_administratable_groups : (); ## Can't share temp data (code) with group
  my @groups; # GROUP SHARING ISN'T WORKING
  my ($info_text, @values);
  
  if (scalar @groups) {
    $form->add_element('type' => 'SubHeader', 'value' => 'Share with');
    $info_text = "
      You can share your saved data with one of the groups you administer,
      or any data with anyone else even if they don't have an account with $sitename. 
      Just select 'Anyone, via URL' to get a shareable link to your data.
    ";
  } else {
    $info_text = "
      You can share your uploaded data with anyone, even if they don't have an
      account with $sitename. Just select one or more of your uploads and click on 'Next'
      to get a shareable link to your data.
    ";
  }

  $info_text .= 'Please note that these URLs expire after 72 hours, but if you save the upload to your account, you can create a new shareable URL at any time.';

  $form->add_notes({ heading => 'How it works', text => $info_text });

  if (scalar @groups) {
    my @ids = ({ value => 0, name => 'Anyone, via URL' });
    push @ids, { value => $_->id, name => $_->name } for @groups;
    
    $form->add_element(type => 'RadioGroup', name => 'webgroup_id', values => \@ids);
    $form->add_element(type => 'Hidden',     name => 'source',      value  => $hub->param('source'));
  }

  $form->set_attribute('class', 'narrow-labels');
  $form->add_element(type => 'SubHeader', value => 'Data to share');
  
  if ($user) {
    push @values, { name => "Saved upload: $_->{'name'}", value => $_->id } for $user->uploads;
    push @values, { name => "Saved URL: $_->{'name'}",    value => $_->id } for $user->urls;
  }
  
  push @values, { name => "Temporary upload: $_->{'name'}", value => $_->{'code'} } for $session->get_data(type => 'upload');
  push @values, { name => "Temporary URL: $_->{'name'}",    value => $_->{'code'} } for $session->get_data(type => 'url');
  
  $form->add_element(
    type   => 'MultiSelect',
    name   => 'share_id',
    label  => 'Uploaded files',
    value  => $hub->param('id') || $hub->param('code'),
    values => \@values
  );

  return $form->render;
}

1;
