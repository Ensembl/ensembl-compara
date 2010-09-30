package EnsEMBL::Web::Command::Account::UseBookmark;

use strict;

use EnsEMBL::Web::Data::Record::Bookmark;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  my $url;

  if ($hub->param('id') =~ /\D/) {
    ## Fallback in case of XSS exploit
    $url = $hub->species_defs->ENSEMBL_BASE_URL;
  } else {
    my $bookmark;
    
    if ($hub->param('group') || ($hub->param('owner_type') && $hub->param('owner_type') eq 'group')) {
      $bookmark = EnsEMBL::Web::Data::Record::Bookmark::Group->new($hub->param('id'));
    } else {
      $bookmark = EnsEMBL::Web::Data::Record::Bookmark::User->new($hub->param('id'));
    }

    my $click = $bookmark->click;
    
    if ($click) {
      $bookmark->click($click + 1)
    } else {
      $bookmark->click(1);
    }
    
    $bookmark->save;
    
    $url = $bookmark->url;
    $url = "http://$url" if $url !~ /^http/ && $url !~ /^ftp/; ## bare addresses of type 'www.domain.com' don't redirect
  }
  
  $hub->redirect($url);
}

1;
