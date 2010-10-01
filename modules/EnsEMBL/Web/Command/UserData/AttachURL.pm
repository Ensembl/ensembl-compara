# $Id$

package EnsEMBL::Web::Command::UserData::AttachURL;

use strict;

use EnsEMBL::Web::Tools::Misc qw(get_url_filesize);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/';
  my $name     = $hub->param('name');
  my $param    = {};
  
  if (!$name) {
    my @path = split '/', $hub->param('url');
    $name    = $path[-1];
  }

  if (my $url = $hub->param('url')) {
    $url = "http://$url" unless $url =~ /^http/;

    ## Check file size
    my $feedback = get_url_filesize($url);
    
    if ($feedback->{'error'}) {
      $redirect .= 'SelectURL';
      
      if ($feedback->{'error'} eq 'timeout') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'}   = 'no_response';
      } elsif ($feedback->{'error'} eq 'mime') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'}   = 'invalid_mime_type';
      } else {
        ## Set message in session
        $session->add_data(
          type     => 'message',
          code     => 'AttachURL',
          message  => "Unable to access file. Server response: $feedback->{'error'}",
          function => '_error'
        );
      }
    } elsif (defined $feedback->{'filesize'} && $feedback->{'filesize'} == 0) {
      $redirect .= 'SelectURL';
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'}   = 'empty';
    } else {
      my $data = $session->add_data(
        type     => 'url',
        url      => $url,
        name     => $name,
        species  => $hub->data_species,
        filesize => $feedback->{'filesize'},
      );
      
      $self->object->move_to_user(type => 'url', code => $data->{'code'}) if $hub->param('save');
      
      $redirect .= 'UrlFeedback';
    }
  } else {
    $redirect .= 'SelectURL';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'}   = 'no_url';
  }

  $self->ajax_redirect($redirect, $param); 
}

1;
