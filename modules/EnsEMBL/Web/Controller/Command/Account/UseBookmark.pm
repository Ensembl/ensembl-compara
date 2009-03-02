package EnsEMBL::Web::Controller::Command::Account::UseBookmark;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = $self->action->cgi;
  if ($cgi->param('id') && $cgi->param('id') =~ /^\d+$/) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::Bookmark', $cgi->param('id'), $cgi->param('owner_type'));
  }

}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  return if $cgi->param('id') =~ /\D/;
  
  my $bookmark;
  if ($cgi->param('owner_type') && $cgi->param('owner_type') eq 'group') {
    $bookmark = EnsEMBL::Web::Data::Record::Bookmark::Group->new($cgi->param('id'));
  }
  else {
    $bookmark = EnsEMBL::Web::Data::Record::Bookmark::User->new($cgi->param('id'));
  }

  my $click = $bookmark->click;
  if ($click) {
    $bookmark->click($click + 1)
  } else {
    $bookmark->click(1);
  }
  $bookmark->save;
  my $url = $bookmark->url;
  if ($url !~ /^http/ && $url !~ /^ftp/) { ## bare addresses of type 'www.domain.com' don't redirect
    $url = 'http://'.$url;
  }
  $cgi->redirect($url);
}

}

1;
