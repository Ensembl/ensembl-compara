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

package EnsEMBL::Web::Command::UserData;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Command);

sub ajax_redirect {
  ## Provide default value for redirectType and modalTab
  my ($self, $url, $param, $anchor, $redirect_type, $modal_tab) = @_;
  $self->SUPER::ajax_redirect($url, $param, $anchor, $redirect_type || 'modal', $modal_tab || 'modal_user_data');
}

sub upload {
## Separate out the upload, to make code reuse easier
  my ($self, $method, $type) = @_;
  my $hub       = $self->hub;
  my $params    = {};
  my @orig_path = split '/', $hub->param($method);
  my $filename  = $orig_path[-1];
  my $name      = $hub->param('name');
  my $f_param   = $hub->param('format');
  my ($error, $format, $full_ext, %args);
  
  ## Need the filename (for handling zipped files)
  if ($method eq 'text') {
    $name = 'Data' unless $name;
  } else {
    my @orig_path = split('/', $hub->param($method));
    $args{'filename'} = $orig_path[-1];
    $name ||= $args{'filename'};
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

  ## Set up parameters for file-writing
  if ($method eq 'url') {
    my $url = $hub->param('url');
    $url    =~ s/^\s+//;
    $url    =~ s/\s+$//;

    ## Needs full URL to work, including protocol
    unless ($url =~ /^http/ || $url =~ /^ftp:/) {
      $url = ($url =~ /^ftp/) ? "ftp://$url" : "http://$url";
    }
    my $response = get_url_content($url);
    
    $error           = $response->{'error'};
    $args{'content'} = $response->{'content'};
  } elsif ($method eq 'text') {
    my $text = $hub->param('text');
    if ($type eq 'coords') {
      $text =~ s/\s/\n/g;
    }
    $args{'content'} = $text;
  } else {
    $args{'tmp_filename'} = $hub->input->tmpFileName($hub->param($method));
  }

  ## Add upload to session
  if ($error) {
    $params->{'filter_module'} = 'Data';
    $params->{'filter_code'}   = 'no_response';
  } else {
    my $file = EnsEMBL::Web::TmpFile::Text->new(prefix => 'user_upload', %args);
  
    if ($file->content) {
      if ($file->save) {
        my $session = $hub->session;
        my $code    = join '_', $file->md5, $session->session_id;
        my $format  = $hub->param('format');
           $format  = 'BED' if $format =~ /bedgraph/i;
        my %inputs  = map $_->[1] ? @$_ : (), map [ $_, $hub->param($_) ], qw(filetype ftype style assembly nonpositional assembly);
        
        $inputs{'format'}    = $format if $format;
        $params->{'species'} = $hub->param('species') || $hub->species;
        
        ## Attach data species to session
        my $data = $session->add_data(
          type      => 'upload',
          filename  => $file->filename,
          filesize  => length($file->content),
          code      => $code,
          md5       => $file->md5,
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
    } else {
      $params->{'filter_module'} = 'Data';
      $params->{'filter_code'}   = 'empty';
    }
  }
  
  return $params;
}

1;
