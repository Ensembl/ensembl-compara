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

package EnsEMBL::Web::Command::UserData::AttachRemote;

use strict;

use EnsEMBL::Web::File::AttachedFormat;

use base qw(EnsEMBL::Web::Command::UserData);

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
  my $params        = {};

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
    ## Is this file already attached?
    my ($redirect_action, $new_params) = $self->check_attachment($url);

    if ($redirect_action) {
      $redirect .= $redirect_action; 
      $params = $new_params;
    }
    else {
      my $format_package = 'EnsEMBL::Web::File::AttachedFormat::' . uc $format_name;
      my %args = ('hub' => $self->hub, 'format' => $format_name, 'url' => $url, 'track_line' => $self->hub->param('trackline'));
      my $format;
    
      if ($self->dynamic_use($format_package)) {
        $format = $format_package->new(%args);
      } else {
      $format = EnsEMBL::Web::File::AttachedFormat->new(%args);
      }
 
      ($redirect, $params) = $self->attach($format, $filename);
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
  
  $self->ajax_redirect($redirect, $params);  
}

1;
