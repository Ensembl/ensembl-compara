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

package EnsEMBL::Web::ImageConfig::supporting_evidence_transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub cache_key {
  my $self  = shift;
  my $hub   = $self->hub;
  my $sd    = $hub->species_defs;

  return join('::', $self->SUPER::cache_key(@_),
    $hub->get_db eq 'vega' || $sd->ENSEMBL_SITETYPE eq 'Vega' ? 'VEGA' : (),
    $hub->get_db eq 'rnaseq' ? 'RNASEQ' : (),
    scalar(keys %{$sd->databases->{'DATABASE_RNASEQ'}}) ? 'RNASEQDATA' : (),
    $sd->HAVANA_DATAFREEZE_DATE ? 'HAVANA' : ()
  );
}

sub init_cacheable {
  my $self  = shift;
  my $hub   = $self->hub;
  my $sd    = $hub->species_defs;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    label_width      => 115,
    opt_empty_tracks => 0,
  });

  $self->create_menus('TSE_transcript', 'splice_sites', 'evidence');

  $self->load_tracks;

  my $logic_name      = $hub->core_object('transcript') ? $hub->core_object('transcript')->Obj->analysis->logic_name : '';
  my $is_vega_gene    = $hub->get_db eq 'vega' || $sd->ENSEMBL_SITETYPE eq 'Vega';
  my $is_rnaseq_gene  = $hub->get_db eq 'rnaseq';
  my $has_rnaseq_data = scalar keys %{$sd->databases->{'DATABASE_RNASEQ'}} ?  1: 0;

  $self->add_tracks('splice_sites', [ 'non_can_intron', 'Non-canonical splicing', 'non_can_intron', {
    display     => 'normal',
    strand      => 'r',
    colours     => $sd->colour('feature'),
    description => 'Non-canonical splice sites (ie not GT/AG, GC/AG, AT/AC or NN/NN)',
  }]);

  $self->add_tracks('evidence', [ 'TSE_generic_match', 'Transcript supporting evidence', 'TSE_generic_match', {
    display     => 'normal',
    strand      => 'r',
    colours     => $sd->colour('feature'),
    description => $is_vega_gene ? 'Alignments from the Havana pipeline that support the transcript' :  'Alignments used to build this transcript model',
  }]);

  if (!$is_vega_gene) {
    if ($has_rnaseq_data) {

      #configure intron supporting feature display
      $self->add_tracks('evidence', [ 'Supported_introns', 'Intron supporting evidence', 'TSE_intron_sf', {
        display              => 'normal',
        strand               => 'r',
        colours              => $sd->colour('feature'),
        description          => 'RNASeq reads that support the introns',
      }]);
    }

    if (!$is_rnaseq_gene) {
      $self->add_tracks('evidence', [ 'SE_generic_match', 'Exon supporting evidence (Ensembl)', 'SE_generic_match', {
        display              => 'normal',
        strand               => 'r',
        colours              => $sd->colour('feature'),
        description          => 'Alignments from the Ensembl pipeline that support the exons',
        logic_names_excluded => '_havana',
      }]);
    }

    if ($sd->HAVANA_DATAFREEZE_DATE) {
      $self->add_tracks('evidence', [ 'SE_generic_match_havana', 'Exon supporting evidence (Havana)', 'SE_generic_match', {
        display          => 'normal',
        strand           => 'r',
        colours          => $sd->colour('feature'),
        description      => 'Alignments from the Havana pipeline that support the exons',
        logic_names_only => '_havana',
      }]);
    }
  }

  $self->add_tracks('evidence', [ 'TSE_background_exon', '', 'TSE_background_exon', {
    display => 'normal',
    strand  => 'r',
    menu    => 'no',
  }], [ 'TSE_legend', 'Legend', 'TSE_legend', {
    display => 'normal',
    strand  => 'r',
    colours => $sd->colour('feature'),
    menu    => 'no',
  }]);
}

1;
