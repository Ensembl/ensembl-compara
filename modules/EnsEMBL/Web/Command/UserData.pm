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

package EnsEMBL::Web::Command::UserData;

use strict;

use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::File::User;

use base qw(EnsEMBL::Web::Command);

sub ajax_redirect {
  ## Provide default value for redirectType and modalTab
  my ($self, $url, $param, $anchor, $redirect_type, $modal_tab) = @_;
  $self->SUPER::ajax_redirect($url, $param, $anchor, $redirect_type || 'modal', $modal_tab || 'modal_user_data');
}

sub upload {
### Simple wrapper around File::User 
  my ($self, $method, $format) = @_;
  my $hub       = $self->hub;
  my $params    = {};

  my $file  = EnsEMBL::Web::File::User->new('hub' => $hub, 'empty' => 1);
  my $error = $file->upload('method' => $method, 'format' => $format);

  if ($error) {
    $params->{'restart'} = 1;
    $hub->session->add_data(
      type     => 'message',
      code     => 'userdata_error',
      message  => "There was a problem uploading your data: $error.<br />Please try again.",
      function => '_error'
    );
  } else {
    $params->{'species'}  = $hub->param('species') || $hub->species;
    $params->{'code'}     = $file->code;
  } 
 
  return $params;
}

sub check_attachment {
  my ($self, $url) = @_;
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;

  my $already_attached = 0;
  my ($redirect, $params);

  ## Check for pre-configured hubs
  my %preconfigured = %{$species_defs->ENSEMBL_INTERNAL_TRACKHUB_SOURCES||{}};
  while (my($k, $v) = each (%preconfigured)) {
    my $hub_info = $species_defs->get_config($hub->species, $k);
    if ($hub_info->{'url'} eq $url) {
      $already_attached = 'preconfig';
      last;
    }
  }

  ## Check user's own data
  unless ($already_attached) {
    my @attachments = $hub->session->get_data('type' => 'url');
    foreach (@attachments) {
      if ($_->{'url'} eq $url) {
        $already_attached = 'user';
        last;
      }
    }
  }

  if ($already_attached) {
    $redirect = 'RemoteFeedback';
    $params = {'format' => 'TRACKHUB', 'reattach' => $already_attached};
  }

  return ($redirect, $params);
}

sub attach {
### Attach a remote file and return the parameters needed for a redirect
### @param attachable EnsEMBL::Web::File::AttachedFormat object
### @return array - redirect action plus hashref of parameters
  my ($self, $attachable, $filename) = @_;
  my $hub = $self->hub;

  ## For datahubs, pass assembly info so we can check if there's suitable data
  my $ensembl_assemblies = $hub->species_defs->assembly_lookup;

  my ($url, $error, $options) = $attachable->check_data($ensembl_assemblies);
  my ($redirect, $params);

  if ($error) {
    $redirect = 'SelectFile';

    $hub->session->add_data(
                        type     => 'message',
                        code     => 'AttachURL',
                        message  => $error,
                        function => '_error'
                      );
  } 
  else {
    ## This next bit is a hack - we need to implement userdata configuration properly! 
    my $extra_config_page = $attachable->extra_config_page;
    my $name              = $hub->param('name') || $options->{'name'} || $filename;
    $redirect             = $extra_config_page || 'RemoteFeedback';

    delete $options->{'name'};

    my $assemblies = $options->{'assemblies'} || [$hub->species_defs->get_config($hub->data_species, 'ASSEMBLY_VERSION')];

    my ($flag_info, $code);

    foreach (@$assemblies) {

      my ($current_species, $assembly, $is_old) = @{$ensembl_assemblies->{$_}||[]};

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
        }

        unless ($is_old) {
          my $data = $hub->session->add_data(
                                        type        => 'url',
                                        code        => join('_', md5_hex($name . $current_species . $assembly . $url), 
                                                                  $hub->session->session_id),
                                        url         => $url,
                                        name        => $name,
                                        format      => $attachable->name,
                                        style       => $attachable->trackline,
                                        species     => $current_species,
                                        assembly    => $assembly,
                                        timestamp   => time,
                                        %$options,
                                        );

          $hub->session->configure_user_data('url', $data);

          if ($current_species eq $hub->param('species')) {
            $code = $data->{'code'};
          }
    
          $self->object->move_to_user(type => 'url', code => $data->{'code'}) if $hub->param('save');
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

    $params = {
                format          => $attachable->name,
                name            => $name,
                species         => $hub->param('species') || $hub->species,
                species_flag    => $species_flag,
                assembly_flag   => $assembly_flag,
                code            => $code,
                };
  }

  return ($redirect, $params);
}

1;
