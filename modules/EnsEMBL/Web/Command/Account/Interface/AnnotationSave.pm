# $Id$

package EnsEMBL::Web::Command::Account::Interface::AnnotationSave;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $interface = $object->interface;
  $interface->cgi_populate($object);

  ## Add user ID to new entries in the user/group_record tables
  if (!$object->param('id') && ref($interface->data) =~ /Record/) {
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
    $interface->data->user_id($user->id);
  }
  $interface->data->save;

  ## We need to close down the popup window if using AJAX and refresh the page!
  my $r = $self->r;
  my $ajax_flag = $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
  
  if( $ajax_flag ) {
    $r->content_type('text/plain');
    print "{'success':true}";
  } else {
    my $data = $interface->data;
    my $var = lc(substr($data->type, 0, 1));
    my $url = $object->species_path($data->species).'/'.$data->type.'/UserAnnotation';
    my $param = {$var => $data->stable_id};
    $object->redirect($self->url($url, $param));
  }
}

1;
