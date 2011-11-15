# $Id$

package EnsEMBL::Web::Command::UserData::CheckConvert;

### Upload some data and add relevant parameters to the wizard workflow

use strict;

use HTML::Entities qw(encode_entities);

use Bio::EnsEMBL::Variation::Utils::VEP qw(@VEP_WEB_CONFIG);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self               = shift;
  my $hub                = $self->hub;
  my $id_mapper          = $hub->param('id_mapper');
  my $consequence_mapper = $hub->param('consequence_mapper');
  my $url_params         = { __clear => 1 };
  my ($method)           = grep $hub->param($_), qw(text file url);
  my @files_to_convert;

  if ($id_mapper) {
    $url_params->{'action'}    = 'SelectOutput';
    $url_params->{'id_mapper'} = $id_mapper;
  } elsif ($consequence_mapper) {
    $url_params->{'action'}             = 'SNPConsequence';
    $url_params->{'consequence_mapper'} = $consequence_mapper;
    $url_params->{$_}                   = $hub->param($_) for 'format', @VEP_WEB_CONFIG;
  } else {
    $url_params->{'action'} = 'ConvertFeatures';
  }
  
  if ($method) {
    my $response = $self->upload($method);
    my $code     = delete $response->{'code'};
    
    $url_params->{$_} = $response->{$_} for keys %$response;
    push @files_to_convert, "upload_$code:$response->{'name'}";
  }
  
  push @files_to_convert, $hub->param('convert_file');
  
  $url_params->{'convert_file'} = \@files_to_convert;
  $url_params->{'conversion'}   = $hub->param('conversion') unless $id_mapper || $consequence_mapper;
  $url_params->{$_}             = $hub->param($_) for qw(id_limit variation_limit);
  
  ## This will need changing if we add more tools
  ## FIXME - this wizard structure is getting a bit crazy!
  my $next_node = $consequence_mapper ? 'command' : 'component';
  
  ## Go from a modal form (with file upload) directly to another web page
  if ($next_node eq 'component' && $hub->param('uploadto') eq 'iframe') {
    $self->file_uploaded($url_params);
  } else {
    $self->ajax_redirect($hub->url($url_params));
  }
}

1;

