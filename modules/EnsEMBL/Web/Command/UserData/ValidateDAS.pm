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

package EnsEMBL::Web::Command::UserData::ValidateDAS;

use strict;
use warnings;

use EnsEMBL::Web::Filter::DAS;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->species_path($object->data_species) . '/UserData/';
  my ($next, $param);

  my $server = $object->param('das_server');

  if ($server) {
    my $filter = EnsEMBL::Web::Filter::DAS->new({'object'=>$object});
    my $sources = $filter->catch($server, $object->param('logic_name'));
    $next = 'AttachDAS';

    if ($filter->error_code) {
      $next = 'DasSources';
      $param->{'das_server'} = $server;
      $param->{'filter_module'} = 'DAS';
      $param->{'filter_code'} = $filter->error_code;
    }
    else {
      my $no_species = 0;
      my $no_coords  = 0;
      $param->{'das_server'} = $object->param('das_server');
      $param->{'species'} = $object->param('species');

      my @logic_names = ();
      for my $source (@{ $sources }) {
        # If one or more source has missing details, need to fill them in and resubmit
        unless (@{ $source->coord_systems } || $object->param($source->logic_name.'_coords')) {
          $next = 'DasCoords' unless $next eq 'DasSpecies'; ## We have to go to species form first
          if (!$object->param('species')) {
            $next = 'DasSpecies';
          }
        }
        push @logic_names, $source->logic_name;
      }
      $param->{'logic_name'} = \@logic_names;

    }

    ## Pass any coordinate parameters
    if ($next eq 'AttachDAS') {
      my @params = $object->param;
      foreach my $p (@params) {
        next unless $p =~ /coords$/;
        $param->{$p} = $object->param($p);
      }
    }
  }
  else {
    $next = 'DasSources';
    $param->{'filter_module'} = 'DAS';
    $param->{'filter_code'} = 'no_server';
  }

  $self->ajax_redirect($url.$next, $param); 
}

1;
