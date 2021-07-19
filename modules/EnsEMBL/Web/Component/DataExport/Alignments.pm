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

package EnsEMBL::Web::Component::DataExport::Alignments;

use strict;
use warnings;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Component::Compara_AlignSliceSelector;

use base qw(EnsEMBL::Web::Component::DataExport);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### N.B. There currently are no additional options for alignment export
  my $self  = shift;
  my $hub   = $self->hub;

  ## Get user's current settings
  my $view_config  = $self->view_config;
  my $settings = $view_config->form_fields({'no_snp_link' => 1});

  $settings->{'Hidden'} = ['align'];

  ## Options per format
  my $fields_by_format = {};
  ## Add formats output by BioPerl
  foreach ($self->alignment_formats) {
    $fields_by_format->{$_} = [];
  }

  ## Create settings form (comes with some default fields - see parent)
  my $form = $self->create_form($settings, $fields_by_format, 1);

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $hub = $self->hub;
  my $species_defs = $hub->species_defs;
  my $name;

  my $db_hash      = $species_defs->multi_hash;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $alignments   = $db_hash->{'DATABASE_COMPARA' . ($cdb =~ /pan_ensembl/ ? '_PAN_ENSEMBL' : '')}{'ALIGNMENTS'} || {}; # Get the compara database hash

  my $user_settings = $self->{'viewconfig'}{$hub->param('data_type')}->{_user_settings};
  my $align_param   = $hub->param('align') || $user_settings->{'align'};

  if ($align_param =~ /--/) {
    ($name = $align_param) =~ s/^(\d+)--/alignment_/;
    $name =~ s/--/_/g;
  }
  else {

    my $align = $alignments->{$align_param};

    if ($align) {
      my $align_name;
      if ($align->{'class'} =~ /pairwise/) {
        $name = $species_defs->SPECIES_DISPLAY_NAME;
        my ($other_species) = grep { $_ ne $self->hub->species } keys %{$align->{'species'}};
        $name .= '_'.$species_defs->get_config($other_species, 'SPECIES_DISPLAY_NAME');
        my $type = lc($align->{'type'});
        $type =~ s/_net//;
        $name .= '_'.$type;
      }
      else {
        $name = $align->{'name'};
      }
      $name =~ s/ /_/g;  
    }
  }
  return $name;
}

sub alignment_formats {
### Configure this list to match what's available
### in the installed version of BioPerl
  my $self = shift;
  return qw(CLUSTALW FASTA Mega MSF Nexus Pfam Phylip PSI Stockholm);
}

1;
