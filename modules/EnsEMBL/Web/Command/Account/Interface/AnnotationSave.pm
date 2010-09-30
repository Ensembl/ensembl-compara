# $Id$

package EnsEMBL::Web::Command::Account::Interface::AnnotationSave;

use strict;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my $interface = $self->interface;
  
  $interface->cgi_populate($hub);

  ## Add user ID to new entries in the user/group_record tables
  if (!$hub->param('id') && ref($interface->data) =~ /Record/) {
    my $user = $hub->user;
    $interface->data->user_id($user->id);
  }
  
  $interface->data->save;

  ## We need to close down the popup window if using AJAX and refresh the page!
  my $r = $self->r;
  my $ajax_flag = $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest';
  
  if( $ajax_flag ) {
    $r->content_type('text/plain');
    print '{"success":true}';
  } else {
    my $data  = $interface->data;
    my $var   = lc(substr $data->type, 0, 1);
    my $url   = $hub->species_path($data->species).'/'.$data->type.'/UserAnnotation';
    my $param = {$var => $data->stable_id};
    
    $hub->redirect($self->url($url, $param));
  }
}

1;
