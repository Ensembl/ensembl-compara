package EnsEMBL::Web::Command::Account::Interface::AnnotationSave;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Filter::Spam;
use EnsEMBL::Web::Filter::DuplicateUser;
use EnsEMBL::Web::Tools::RandomString;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $interface = $object->interface;
  $interface->cgi_populate($object);
  my $data = $interface->data;
  $data->save;

  my $var = lc(substr($data->type, 0, 1));
  my $url = '/'.$data->species.'/'.$data->type.'/UserAnnotation';
  my $param = {$var => $data->stable_id};

  ## We need to close down the popup window if using AJAX and refresh the page!
  my $r = Apache2::RequestUtil->request();
  my $ajax_flag = $r && (
    $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'||
    $object->param('x_requested_with') eq 'XMLHttpRequest'
  );
  #warn "@@@ AJAX $ajax_flag";
  if( $ajax_flag ) {
    CGI::header( 'text/plain' );
    print "SUCCESS";
  } else {
    $object->redirect($self->url($url, $param));
  }

}

}

1;
