package EnsEMBL::Web::Component::Account;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Form;

use CGI;

use strict;
use warnings;
no warnings "uninitialized";

our @ISA = qw( EnsEMBL::Web::Component);

sub edit_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Edit' if !$text;
  return sprintf(qq(<a href="/Account/%s?dataview=edit;id=%s">%s</a>), $module, $id, $text);
} 

sub delete_link {
  my ($self, $module, $id, $text) = @_;
  $text = 'Delete' if !$text;
  return sprintf(qq(<a href="/Account/%s?dataview=delete;id=%s">%s</a>), $module, $id, $text);
} 


sub share_link {
  my ($self, $call, $id) = @_;
  return sprintf(qq(<a href="/Account/SelectGroup?id=%s;type=%s">Share</a>), $id, $call);
} 

sub message {
  ### Displays a message (e.g. error) from the Controller::Command::Account module
  my ($panel, $object) = @_;
  my $command = $panel->{command};

  my $html;
  if ($command->get_message) {
    $html = $command->get_message;
  }
  else {
    $html = '<p>'.$command->filters->message.'</p>';
  }
  $panel->print($html);
}


1;

