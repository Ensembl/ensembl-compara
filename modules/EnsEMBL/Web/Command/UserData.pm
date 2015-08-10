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
### Separate out the upload, to make code reuse easier
### TODO refactor this method as a wrapper around E::W::File::User::upload
### - all it needs to do is return the required parameters
  my ($self, $method, $type) = @_;
  my $hub       = $self->hub;
  my $params    = {};
  my @orig_path = split '/', $hub->param($method);
  my $filename  = $orig_path[-1];
  my $name      = $hub->param('name');
  my $f_param   = $hub->param('format');
  my ($error, $format, $full_ext, %args);
  
  ## Need the filename (for handling zipped files)
  unless ($name) {
    if ($method eq 'text') {
      $name = 'Data';
    } else {
      my @orig_path = split('/', $hub->param($method));
      $args{'filename'} = $orig_path[-1];
      $name = $args{'filename'};
    }
  }
  
  $params->{'name'} = $name;

  ## Some uploads shouldn't be viewable as tracks, e.g. assembly converter input
  my $no_attach = $type eq 'no_attach' ? 1 : 0;

  ## Has the user specified a format?
  if ($f_param) {
    $format = $f_param;
  } elsif ($method ne 'text') {
    ## Try to guess the format from the extension
    my @parts       = split('\.', $filename);
    my $ext         = $parts[-1] =~ /gz|zip/i ? $parts[-2] : $parts[-1];
    my $format_info = $hub->species_defs->multi_val('DATA_FORMAT_INFO');
    my $extensions;
    
    foreach (@{$hub->species_defs->multi_val('UPLOAD_FILE_FORMATS')}) {
      $format = uc $ext if $format_info->{lc($_)}{'ext'} =~ /$ext/i;
    }
  }
  
  $params->{'format'} = $format;

  my %args = (
              'hub'             => $self->hub,
              'timestamp_name'  => 1,
              'absolute'        => 1,
            );

  if ($method eq 'url') {
    $args{'file'}          = $hub->param($method);
    $args{'upload'}        = 'url';
  } 
  elsif ($method eq 'text') {
    ## Get content straight from CGI, since there's no input file
    my $text = $hub->param('text');
    if ($type eq 'coords') {
      $text =~ s/\s/\n/g;
    }
    $args{'content'} = $text;
  }
  else { 
    $args{'file'}   = $hub->input->tmpFileName($hub->param($method));
    $args{'name'}   = "".$hub->param($method); # stringify the filehandle
    $args{'upload'} = 'cgi';
  }

  my $file = EnsEMBL::Web::File::User->new(%args);
  my $result = $file->read;

  ## Add upload to session
  if ($result->{'error'}) {
    $params->{'filter_module'} = 'Data';
    $params->{'filter_code'}   = 'no_response';
  } elsif (!$result->{'content'}) {
    $params->{'filter_module'} = 'Data';
    $params->{'filter_code'}   = 'empty';
  } else {
    my $response = $file->write($result->{'content'});
  
    if ($response->{'success'}) {
      my $session = $hub->session;
      my $md5     = $file->md5($result->{'content'});
      my $code    = join '_', $md5, $session->session_id;
      my $format  = $hub->param('format');
      $format     = 'BED' if $format =~ /bedgraph/i;
      my %inputs  = map $_->[1] ? @$_ : (), map [ $_, $hub->param($_) ], qw(filetype ftype style assembly nonpositional assembly);
        
      $inputs{'format'}    = $format if $format;
      $params->{'species'} = $hub->param('species') || $hub->species;
        
      ## Attach data species to session
      ## N.B. Use 'write' locations, since uploads are read from the
      ## system's CGI directory
      my $data = $session->add_data(
                                    type      => 'upload',
                                    file      => $file->write_location,
                                    filesize  => length($result->{'content'}),
                                    code      => $code,
                                    md5       => $md5,
                                    name      => $name,
                                    species   => $params->{'species'},
                                    format    => $format,
                                    no_attach => $no_attach,
                                    timestamp => time,
                                    assembly  => $hub->species_defs->get_config($params->{'species'}, 'ASSEMBLY_VERSION'),
                                    %inputs
                                    );
        
      $session->configure_user_data('upload', $data);
        
      $params->{'code'} = $code;
    } else {
      $params->{'filter_module'} = 'Data';
      $params->{'filter_code'}   = 'no_save';
    }
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
  my %preconfigured = %{$species_defs->ENSEMBL_INTERNAL_DATAHUB_SOURCES||{}};
  while (my($k, $v) = each (%preconfigured)) {
    my $hub_info = $species_defs->get_config($hub->species, $k);
    if ($hub_info->{'url'} eq $url) {
      $already_attached = 'preconfig';
      last;
    }
  }

  ## Check user's own data
  unless ($already_attached) {
    my $attachments = $hub->session->get_data('type' => 'url');
    warn ">>> ATTACHMENTS $attachments";
    #foreach (@attachments) {
    #}
  }

  if ($already_attached) {
    $redirect = 'RemoteFeedback';
    $params = {'format' => 'DATAHUB', 'reattach' => $already_attached};
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
    $redirect .= 'SelectFile';

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
    $redirect            .= $extra_config_page || 'RemoteFeedback';

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
                species         => $hub->param('species'),
                species_flag    => $species_flag,
                assembly_flag   => $assembly_flag,
                code            => $code,
                };
  }

  return ($redirect, $params);
}

1;
