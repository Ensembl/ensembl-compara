=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Command::UserData::AttachRemote;

use strict;

use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::ExternalData::AttachedFormat;
use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self          = shift;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $species_defs  = $hub->species_defs;
  my $session       = $hub->session;
  my $redirect      = $hub->species_path($hub->data_species) . '/UserData/';
  my $url           = $hub->param('url') || $hub->param('url_2') || $hub->param('url_3');
     $url           =~ s/(^\s+|\s+$)//g; # Trim leading and trailing whitespace
  my $filename      = [split '/', $url]->[-1];
  my $chosen_format = $hub->param('format');
  my $formats       = $species_defs->multi_val('DATA_FORMAT_INFO');
  my @small_formats = @{$species_defs->multi_val('UPLOAD_FILE_FORMATS')};
  my @big_exts      = map $formats->{$_}{'ext'}, @{$species_defs->multi_val('REMOTE_FILE_FORMATS')};
  my @bits          = split /\./, $filename;
  my $extension     = $bits[-1] eq 'gz' ? $bits[-2] : $bits[-1];
  my $pattern       = "^$extension\$";
  my %params;

  ## We have to do some intelligent checking here, in case the user
  ## tries to attach a large format file with a small format selected in the form
  my $format_name = $chosen_format;
  if (grep(/$chosen_format/i, @small_formats) && grep(/$pattern/i, @big_exts)) {
    my %big_formats = map {$formats->{$_}{'ext'} => $_} @{$species_defs->multi_val('REMOTE_FILE_FORMATS')};
    $format_name = uc($big_formats{$extension});
  }
  elsif ($format_name eq 'VCFI') {
    $format_name = 'VCF';
  }

  if (!$format_name) {
    $redirect .= 'SelectFile';
    
    $session->add_data(
      type     => 'message',
      code     => 'AttachURL',
      message  => 'Unknown format',
      function => '_error'
    );
  }

  if ($url) {
    my $format_package = 'Bio::EnsEMBL::ExternalData::AttachedFormat::' . uc $format_name;
    my $trackline      = $self->hub->param('trackline');
    my $format;
    
    if ($self->dynamic_use($format_package)) {
      $format = $format_package->new($self->hub, $format_name, $url, $trackline);
    } else {
      $format = Bio::EnsEMBL::ExternalData::AttachedFormat->new($self->hub, $format_name, $url, $trackline);
    }
   
    ## For datahubs, pass assembly info so we can check if there's suitable data
    my $assemblies = $species_defs->assembly_lookup;
 
    my ($error, $options) = $format->check_data($assemblies);
    
    if ($error) {
      $redirect .= 'SelectFile';
      
      $session->add_data(
        type     => 'message',
        code     => 'AttachURL',
        message  => $error,
        function => '_error'
      );
    } else {
      ## This next bit is a hack - we need to implement userdata configuration properly! 
      my $extra_config_page = $format->extra_config_page;
      my $name              = $hub->param('name') || $options->{'name'} || $filename;
         $redirect         .= $extra_config_page || 'RemoteFeedback';
      
      delete $options->{'name'};

      $url = chase_redirects($url, {'hub' => $self->hub});
      if (ref($url) eq 'HASH') {
        $redirect .= 'SelectFile';
        $session->add_data(
          type     => 'message',
          code     => 'AttachURL',
          message  => $url->{'error'},
          function => '_error'
        );
      }
      else {
        my $assemblies = $options->{'assemblies'}
                        || [$hub->species_defs->get_config($hub->data_species, 'ASSEMBLY_VERSION')];
        my ($code, @ok_assemblies);
        my %ensembl_assemblies = %{$hub->species_defs->assembly_lookup};

        foreach (@$assemblies) {

          my ($data_species, $assembly) = @{$ensembl_assemblies{$_}||[]};         
          if ($assembly) {
            push @ok_assemblies, $assembly;

            my $data = $session->add_data(
              type        => 'url',
              code        => join('_', md5_hex($name . $data_species . $assembly . $url), $session->session_id),
              url         => $url,
              name        => $name,
              format      => $format->name,
              style       => $format->trackline,
              species     => $data_species,
              assembly    => $assembly, 
              timestamp   => time,
              %$options,
            );
            if ($data_species eq $hub->species) {
              $code = $data->{'code'};
            }
      
            $session->configure_user_data('url', $data);
      
            $object->move_to_user(type => 'url', code => $data->{'code'}) if $hub->param('save');
          }
        }       
        my $assembly_string = join(', ', @ok_assemblies);
        %params = (
          format    => $format->name,
          type      => 'url',
          name      => $name,
          assembly  => $assembly_string,
          code      => $code,
        );
      }
    }
  } else {
    $redirect .= 'SelectFile';
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
