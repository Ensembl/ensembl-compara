# $Id$

package EnsEMBL::Web::Command::UserData::AttachRemote;

use strict;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Root;
use Bio::EnsEMBL::ExternalData::AttachedFormat;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self          = shift;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $species_defs  = $hub->species_defs;
  my $session       = $hub->session;
  my $redirect      = $hub->species_path($hub->data_species) . '/UserData/';
  my $url           = $hub->param('url');
  my $filename      = [split '/', $url]->[-1];
  my $name          = $hub->param('name') || $filename;
  my $chosen_format = $hub->param('format');
  my $formats       = $species_defs->DATA_FILE_FORMATS;
  my @small_formats = $species_defs->UPLOAD_FILE_FORMATS;
  my @big_exts      = map $formats->{$_}{'ext'}, $species_defs->REMOTE_FILE_FORMATS;
  my @bits          = split /\./, $filename;
  my $extension     = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
  my $pattern       = "^$extension\$";
  my %params;

  ## We have to do some intelligent checking here, in case the user
  ## doesn't select a format, or tries to attach a large format file
  ## with a small format selected in the form
  my $format_name = !$chosen_format || (grep(/$chosen_format/i, @small_formats) && grep(/$pattern/i, @big_exts)) ? uc $extension : $chosen_format;

  if (!$format_name) {
    $redirect .= 'SelectRemote';
    
    $session->add_data(
      type     => 'message',
      code     => 'AttachURL',
      message  => 'Unknown format',
      function => '_error'
    );
  }

  if ($url) {
    my $format;
    my $format_package = "Bio::EnsEMBL::ExternalData::AttachedFormat::".uc($format_name);
    my $trackline = $self->hub->param('trackline');
    if (EnsEMBL::Web::Root::dynamic_use(undef, $format_package)) {
      $format = $format_package->new($self->hub,$format_name,$url,$trackline);
    } else {
      $format = Bio::EnsEMBL::ExternalData::AttachedFormat->new($self->hub,$format_name,$url,$trackline);
    }

    my ($error,$options) = $format->check_data();
        
    if ($error) {
      $redirect .= 'SelectRemote';
      
      $session->add_data(
        type     => 'message',
        code     => 'AttachURL',
        message  => $error,
        function => '_error'
      );
    } else {
      ## This next bit is a hack - we need to implement userdata configuration properly! 
      my $extra_config_page = $format->extra_config_page;
      $redirect .= $extra_config_page || "RemoteFeedback";
            
      my $data = $session->add_data(
        type      => 'url',
        code      => join('_', md5_hex($name . $url), $session->session_id),
        url       => $url,
        name      => $name,
        format    => $format->name,
        style     => $format->trackline,
        species   => $hub->data_species,
        timestamp => time,
        %$options,
      );
      
      $session->configure_user_data('url', $data);
      
      $object->move_to_user(type => 'url', code => $data->{'code'}) if $hub->param('save');
      
      %params = (
        format => $format->name,
        type   => 'url',
        code   => $data->{'code'},
      );
    }
  } else {
    $redirect .= 'SelectRemote';
      $session->add_data(
        type     => 'message',
        code     => 'AttachURL',
        message  => 'No URL was provided',
        function => '_error'
      );
  }
  
  $self->ajax_redirect($redirect, \%params);  
}

1;
