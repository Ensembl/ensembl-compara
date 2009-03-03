package EnsEMBL::Web::Command::Account::UseBookmark;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url;

  if ($cgi->param('id') =~ /\D/) {
    ## Fallback in case of XSS exploit
    $url = $object->species_defs->ENSEMBL_BASEURL;
  }
  else {
    my $bookmark;
    if ($object->param('owner_type') && $object->param('owner_type') eq 'group') {
      $bookmark = EnsEMBL::Web::Data::Record::Bookmark::Group->new($object->param('id'));
    }
    else {
      $bookmark = EnsEMBL::Web::Data::Record::Bookmark::User->new($object->param('id'));
    }

    my $click = $bookmark->click;
    if ($click) {
      $bookmark->click($click + 1)
    } else {
      $bookmark->click(1);
    }
    $bookmark->save;
    $url = $bookmark->url;
    if ($url !~ /^http/ && $url !~ /^ftp/) { ## bare addresses of type 'www.domain.com' don't redirect
      $url = 'http://'.$url;
    }
  }
  $object->redirect($url);
}

}

1;
