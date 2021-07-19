=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::Family;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Alignments);

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  ## Get user's current settings
  my $view_config  = $self->view_config;

  my $settings = {'Hidden' => ['align','fm']};

  if ($hub->param('members') && $hub->param('members') >= 500) {
    $settings->{'Disabled'} = {'clustalw' => 'Too many members in this family.'};
  }

  ## Options per format
  my $fields_by_format;
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = sprintf('Alignment_for_family_%s', $self->hub->param('fm'));
  return $name;
}

1;
