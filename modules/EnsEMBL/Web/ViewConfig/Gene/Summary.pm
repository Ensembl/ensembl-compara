package EnsEMBL::Web::ScriptConfig::geneview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    image_width             800
    panel_gene              on
    panel_das               on
    panel_transcript        on
    status_gene_stable_id   on
    status_gene_transcripts on
    status_das_sources      on
    status_gene_alignments  on
    status_gene_orthologues on
    status_gene_paralogues  on
    status_similarity_matches  on
    status_literature          on
    status_oligo_arrays        on
    status_alternative_transcripts on
    context                 0
    das_sources),           []
  );
  $script_config->add_image_configs({qw(
    altsplice nodas
  )});
  $script_config->storable = 1;
}
1;
