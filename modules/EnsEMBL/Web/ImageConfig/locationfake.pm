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

package EnsEMBL::Web::ImageConfig::locationfake;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use URI::Escape qw(uri_unescape);
use HTML::Entities qw(encode_entities);

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    can_trackhubs     => 0,      # allow track hubs
    opt_lines         => 1,      # draw registry lines
  });

  # First add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    trans_associated
    transcript
    longreads
    prediction
    lrg
    dna_align_cdna
    dna_align_est
    dna_align_rna
    dna_align_other
    protein_align
    protein_feature
    rnaseq
    ditag
    simple
    genome_attribs
    misc_feature
    variation
    recombination
    somatic
    functional
    multiple_align
    conservation
    pairwise_blastz
    pairwise_tblat
    pairwise_other
    dna_align_compara
    oligo
    repeat
    external_data
    decorations
    information
  ));

  my %desc = (
    contig    => 'Track showing underlying assembly contigs.',
    seq       => 'Track showing sequence in both directions. Only displayed at 1Kb and below.',
    codon_seq => 'Track showing 6-frame translation of sequence. Only displayed at 500bp and below.',
    codons    => 'Track indicating locations of start and stop codons in region. Only displayed at 50Kb and below.'
  );

  # Note these tracks get added before the "auto-loaded tracks" get added
  $self->add_tracks('sequence',
    [ 'contig',    'Contigs',             'contig',   { display => 'normal', strand => 'r', description => $desc{'contig'}                                                                }],
    [ 'seq',       'Sequence',            'sequence', { display => 'normal', strand => 'b', description => $desc{'seq'},       colourset => 'seq',      threshold => 1,   depth => 1      }],
    [ 'codon_seq', 'Translated sequence', 'codonseq', { display => 'off',    strand => 'b', description => $desc{'codon_seq'}, colourset => 'codonseq', threshold => 0.5, bump_width => 0 }],
    [ 'codons',    'Start/stop codons',   'codons',   { display => 'off',    strand => 'b', description => $desc{'codons'},    colourset => 'codons',   threshold => 50                   }],
  );

  $self->add_track('decorations', 'gc_plot', '%GC', 'gcplot', { display => 'normal',  strand => 'r', description => 'Shows percentage of Gs & Cs in region', sortable => 1 });

  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_bigwig;
  $self->load_configured_bigbed;
#  $self->load_configured_bam;

  ## LRG track
  if ($self->species_defs->HAS_LRG) {
    $self->add_tracks('lrg',
      [ 'lrg_transcript', 'LRG', '_transcript', {
        display     => 'off', # Switched off by default
        strand      => 'b',
        name        => 'LRG',
        description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
        logic_names => [ 'LRG_import' ],
        logic_name  => 'LRG_import',
        colours     => $self->species_defs->colour('gene'),
        label_key   => '[display_label]',
        colour_key  => '[logic_name]',
        zmenu       => 'LRG',
      }]
    );
  }

  ## Switch on multiple alignments defined in MULTI.ini
  my $compara_db      = $self->hub->database('compara');
  if ($compara_db) {
    my $defaults = $self->hub->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'COMPARA_DEFAULT_ALIGNMENT_IDS'};

    foreach my $default (@$defaults) {
      my ($mlss_id,$species,$method) = @$default;
      $self->modify_configs(
        [ 'alignment_compara_'.$mlss_id.'_constrained' ],
        { display => 'compact' }
      );
    }
  }

  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS');

  foreach my $f_set (@feature_sets) {
    $self->modify_configs(
      [ "regulatory_regions_funcgen_$f_set" ],
      { depth => 25, height => 6 }
    );
  }

}

1;
