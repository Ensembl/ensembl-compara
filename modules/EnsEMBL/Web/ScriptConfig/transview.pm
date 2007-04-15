package EnsEMBL::Web::ScriptConfig::transview;

use strict;

sub init {
  my ($script_config) = @_;

  $script_config->_set_defaults(qw(
    show                    plain
    number                  off   
    status_similarity_matches  on
    status_literature          on
    status_oligo_arrays        on
    status_alternative_transcripts on
    das_sources             
  ));
  $script_config->storable = 1;
}
1;
