# $Id$

package EnsEMBL::Web::Command::UserData::AttachRemote;

use strict;

use EnsEMBL::Web::Root;
use Digest::MD5    qw(md5_hex);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self     = shift;
  my $hub      = $self->hub;
  my $object   = $self->object;
  my $session  = $hub->session;
  my $redirect = $hub->species_path($hub->data_species) . '/UserData/';
  my $name     = $hub->param('name');
  my $param    = {};
  my $options  = {};
  my $error;

  my @path = split '/', $hub->param('url');
  my $filename = $path[-1];
  $name ||= $filename;

  ## Check file format
  my $format;
  my @bits = split /\./, $filename;
  my $extension = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
  my @small_formats = @{$hub->species_defs->USERDATA_FILE_FORMATS};
  my @big_formats   = @{$hub->species_defs->USERDATA_REMOTE_FORMATS};

  my $chosen_format = $hub->param('format');
  my $pattern = '^'.$extension.'$';

  ## We have to do some intelligent checking here, in case the user
  ## doesn't select a format, or tries to attach a large format file
  ## with a small format selected in the form
  if (!$chosen_format || (grep(/$chosen_format/i, @small_formats) && grep(/$pattern/i, @big_formats))) {
    $format = uc($extension);
  }
  else {
    $format = $chosen_format;
  }

  unless ($format) {
    $redirect .= 'SelectRemote';
    $session->add_data(
        'type'  => 'message',
        'code'  => 'AttachURL',
        'message' => 'Unknown format',
        function => '_error'
    );
  }

  if (my $url = $hub->param('url')) {

    my $check_method = 'check_'.lc($format).'_data';
    if ($object->can($check_method)) {
      ($error, $options) = $object->$check_method($url);
    }
    else {
      ($error, $options) = $object->check_url_data($url);
    }

    if ($error) {
      $redirect .= 'SelectRemote';
      $session->add_data(
          'type'  => 'message',
          'code'  => 'AttachURL',
          'message' => $error,
          function => '_error'
      );
    }
    else {
      ## This next bit is a hack - we need to implement userdata configuration properly! 
      if ($format eq 'BIGWIG') {
        $redirect .= 'ConfigureBigWig';
      }
      else {
        $redirect .= 'RemoteFeedback';
      }
      my $data = $session->add_data(
        type      => 'url',
        url       => $url,
        name      => $name,
        format    => $format,
        style     => $format,
        species   => $hub->data_species,
        timestamp => time(),
        %$options,
      );
      my $config_method = 'configure_'.lc($format).'_views';
      if ($session->can($config_method)) {
        $session->$config_method($data);
        $session->store;
      }
      if ($hub->param('save')) {
        $self->object->move_to_user(type => 'url', code => $data->{'code'});
      }
      $param->{'format'} = $format;
      $param->{'type'} = 'url';
      $param->{'code'} = $data->{'code'};
    }
  } else {
    $redirect .= 'SelectRemote';
      $session->add_data(
          'type'  => 'message',
          'code'  => 'AttachURL',
          'message' => 'No URL was provided',
          function => '_error'
      );
  }

  $self->ajax_redirect($redirect, $param);  
}

1;
