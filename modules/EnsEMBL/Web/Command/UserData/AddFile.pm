=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Command::UserData::AddFile;

use strict;

use List::Util qw(first);
use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return $self->set_format if $hub->function eq 'set_format';
 
  my ($method)    = first { $hub->param($_) } qw(url file text);
  my $format      = $hub->param('format');
  my $url_params  = {};

  if ($method eq 'url') {
    ## Attach the file from the remote URL
    $url_params = $self->attach_data($hub->param('url'), $format); 
  }
  else {
    ## Upload the data
    my %remote_formats = map { lc $_ => 1 } @{$self->hub->species_defs->multi_val('REMOTE_FILE_FORMATS')||[]};
    if ($remote_formats{$format}) {
      $url_params->{'restart'} = 1;
      $hub->session->add_data(
        type     => 'message',
        code     => 'userdata_error',
        message  => "We are unable to upload files of this type. Please supply a URL for this data.",
        function => '_error'
      );
    }
    else {
      $url_params = $self->upload($method);
      $url_params->{ __clear} = 1;
      $url_params->{'action'} = 'UploadFeedback';
    }
  }

  if ($url_params->{'restart'}) {
    $url_params->{'action'} = 'SelectFile';
  }

  return $self->ajax_redirect($self->hub->url($url_params));
}

sub attach_data {
  my ($self, $url, $format_name) = @_;
  my $hub     = $self->hub;

  my $format_package = 'EnsEMBL::Web::File::AttachedFormat::' . uc $format_name;
  my $trackline      = $self->hub->param('trackline');
  my $url_params     = {};
  my $format;

  if ($self->dynamic_use($format_package)) {
    $format = $format_package->new($self->hub, $format_name, $url, $trackline);
  } else {
    $format = EnsEMBL::Web::File::AttachedFormat->new($self->hub, $format_name, $url, $trackline);
  }

  ## For datahubs, pass assembly info so we can check if there's suitable data
  my $assemblies = $species_defs->assembly_lookup;

  my ($url, $error, $options) = $format->check_data($assemblies);

  if ($error) {
    $url_params->{'restart'} = 1;

    $session->add_data(
      type     => 'message',
      code     => 'AttachURL',
      message  => $error,
      function => '_error'
    );
  } 
  else {
    ## This next bit is a hack - we need to implement userdata configuration properly! 
    my $extra_config_page   = $format->extra_config_page;
    my $name                = $hub->param('name') || $options->{'name'} || $filename;
    $url_params->{'action'} = $extra_config_page || 'RemoteFeedback';

    delete $options->{'name'};

    my $assemblies = $options->{'assemblies'} || [$hub->species_defs->get_config($hub->data_species, 'ASSEMBLY_VERSION')];
    my %ensembl_assemblies = %{$hub->species_defs->assembly_lookup};

    my ($flag_info, $code);

    foreach (@$assemblies) {

      my ($current_species, $assembly, $is_old) = @{$ensembl_assemblies{$_}||[]};

      ## This is a bit messy, but there are so many permutations!
      if ($assembly) {
        if ($current_species eq $hub->param('species')) {
          $flag_info->{'species'}{'this'} = 1;
          if ($is_old) {
            $flag_info->{'assembly'}{'this_old'} = 1;
          }
          else {
            $flag_info->{'assembly'}{'this_new'} = 1;
          }
        }
        else {
          $flag_info->{'species'}{'other'}++;
          if ($is_old) {
            $flag_info->{'assembly'}{'other_old'} = 1;
          }
          else {
            $flag_info->{'assembly'}{'other_new'} = 1;
          }
          unless ($is_old) {
            my $data = $session->add_data(
              type        => 'url',
              code        => join('_', md5_hex($name . $current_species . $assembly . $url), $session->session_id),
              url         => $url,
              name        => $name,
              format      => $format->name,
              style       => $format->trackline,
              species     => $current_species,
              assembly    => $assembly,
              timestamp   => time,
              %$options,
            );

            $session->configure_user_data('url', $data);

            if ($current_species eq $hub->param('species')) {
              $code = $data->{'code'};
            }

            $object->move_to_user(type => 'url', code => $data->{'code'}) if $hub->param('save');
          }
        }
      }
      ## For datahubs, work out what feedback we need to give the user
      my ($species_flag, $assembly_flag);
      if ($flag_info->{'species'}{'other'} && !$flag_info->{'species'}{'this'}) {
        $species_flag = 'other_only';
      }

      if ($flag_info->{'assembly'}{'this_new'} && $flag_info->{'assembly'}{'this_old'}) {
        $assembly_flag = 'old_and_new';
      }
      elsif (!$flag_info->{'assembly'}{'this_new'} && !$flag_info->{'assembly'}{'other_new'}) {
        $assembly_flag = 'old_only';
      }

      $url_params->{'format'}         = $format->name;
      $url_params->{'type'}           = 'url';
      $url_params->{'name'}           = $name;
      $url_params->{'species'}        = $hub->param('species');
      $url_params->{'species_flag'}   = $species_flag;
      $url_params->{'assembly_flag'}  = $assembly_flag;
      $url_params->{'code'}           = $code;
    }
  }          
  return $url_params;
}

sub set_format {
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $code    = $hub->param('code');
  my $format  = $hub->param('format');
  
  $session->set_data(%{$session->get_data(code => $code)}, format => $format) if $format;
  
  $self->ajax_redirect($hub->url({
    action   => $format ? 'UploadFeedback' : 'MoreInput',
    function => undef,
    format   => $format,
    code     => $code
  }));
}

1;
