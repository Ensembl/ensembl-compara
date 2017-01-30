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

package EnsEMBL::Web::Command::Info::CheckGallery;

### Check the parameters being passed to the gallery components
### and do the redirect 

use strict;

use EnsEMBL::Root;

use parent qw(EnsEMBL::Web::Command);

sub process {
  my $self               = shift;
  my $hub                = $self->hub;
  my $species            = $hub->param('species');

  my $data_type = ucfirst($hub->param('data_type'));

  my $core_params = {
                    'Gene'      => 'g',
                    'Location'  => 'r',
                    'Variation' => 'v',
                    };

  my $url_params = {
                    'species'   => $species,
                    'type'      => 'Info',
                    'data_type' => $data_type,
                    'action'    => $data_type.'Gallery',
                  };

  ## Check validity of identifier
  my $id = $hub->param('identifier');

  ## Use default for this species if user didn't supply one
  unless ($id) {
    $url_params->{'default'} = 'yes';
    my $sample_data = { %{$hub->species_defs->get_config($species, 'SAMPLE_DATA') || {}} };
    $id = $sample_data->{uc($data_type).'_PARAM'};
  }

  $hub->param($core_params->{$data_type}, $id); ## Set this so it can be used by factory
  $url_params->{$core_params->{$data_type}} =  $id; 

  my $error;
  my $common_name = $hub->species_defs->get_config($species, 'SPECIES_COMMON_NAME');

  my $builder   = $hub->{'_builder'};
  ## Don't use the create_factory method, as its error-handling 
  ## is not ideal for this situation!

  my $data = {
    _hub       => $hub,
    _input     => $hub->input,
    _databases => $hub->databases,
    _referer   => $hub->referer
  };

  my $factory = $self->new_factory($data_type, $data);
  $factory->createObjects;

  if ($hub->get_problem_type('fatal')) {
    my @fatal_errors = @{$hub->{'_problem'}{'fatal'}||[]};
    $error = $fatal_errors[0]->description; 
  }
  else {
    my $object = $factory->object;
    unless ($object) {
      $error = sprintf('%s "%s" could not be found in species %s. Please try again.', $data_type, $id, $common_name);
    }
  }

  if ($error) {
    $hub->session->set_record_data({
                            'type'      => 'message',
                            'code'      => 'gallery',
                            'function'  => '_warning',
                            'message'   => $error,
                            });  
    $self->ajax_redirect("/gallery.html?species=$species");
  }
  else { 
    $self->ajax_redirect($hub->url($url_params));
  }
}

1;

