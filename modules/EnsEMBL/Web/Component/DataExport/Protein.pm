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

package EnsEMBL::Web::Component::DataExport::Protein;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### Options for protein sequence output
  my $self  = shift;
  my $hub   = $self->hub;

  my $checklist = [];
  foreach (EnsEMBL::Web::Constants::FASTA_OPTIONS) {
    next unless $_->{'value'} eq 'peptide' || $_->{'value'} eq 'exon';
    $_->{'checked'} = 'on' if $_->{'value'} eq 'peptide';
    push @$checklist, $_;
  }

  ## Get user's current settings
  my $viewconfig  = $hub->get_viewconfig($hub->param('component'), $hub->param('data_type'));

  my $settings = {
        'extra' => {
          'type'      => 'Checklist',
          'label'     => 'Sequences to export',
          'values'    => $checklist,
          'selectall' => 'off',
        },
        'snp_display' => {
            'label'   => 'Include sequence variants',
            'type'    => 'Checkbox',
            'value'   => 'on',
            'checked' => $viewconfig->get('snp_display') eq 'off' ? 0 : 1,
        },
  };

  ## Options per format
  my $fields_by_format = {
    'RTF' => [
                ['snp_display'],
              ],  
    'FASTA' => [
                ['extra'],
               ], 
  };

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species;
  my $data_object = $self->hub->param('g') ? $self->hub->core_object('gene') : undef;
  if ($data_object) {
    $name .= '_';
    my $stable_id = $data_object->stable_id;
    my ($disp_id) = $data_object->display_xref;
    $name .= $disp_id || $stable_id;
  }
  $name .= '_sequence';
  return $name;
}

1;
