package EnsEMBL::Web::Command::UserData::SaveRemote;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $url = '/'.$self->object->data_species.'/UserData/';
  my ($node, $param);

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @sources = grep {$_} $self->object->param('dsn');

  if ($user && scalar @sources) {
    my $all_das = $self->object->get_session->get_all_das;
    foreach my $logic_name  (@sources) {
      my $das = $all_das->{$logic_name} || warn "*** $logic_name";
      my $result = $user->add_das( $das );
      if ( $result ) {
        $node = 'ManageData';
      }
      else {
        $node = 'ShowRemote';
        $param->{'filter_module'} = 'UserData';
        $param->{'filter_code'} = 'no_das';
      }
    }
    # Just need to save the session to remove the source - it knows it has changed
    $self->object->get_session->save_das;
  }

  ## Save any URL data
  if (my @codes = $self->object->param('code')) {
    my $error = 0;
    foreach my $code (@codes) {
      next unless $code;
      my $url = $self->object->get_session->get_data(type => 'url', code => $code);
      if ($url && $user->add_to_urls($url)) {
        $self->object->get_session->purge_data(type => 'url', code => $code);
      } else {
        $error = 1;
      }
    }
    if ($error) {
        $node = 'ShowRemote';
        $param->{'filter_module'} = 'UserData';
        $param->{'filter_code'} = 'no_url';
    }
    else {
      $node = 'ManageData';
    }
  }
  $url .= $node;
  warn ">>> URL = $url";
  $self->ajax_redirect($url, $param); 

}

}

1;
