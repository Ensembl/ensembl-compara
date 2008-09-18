package EnsEMBL::Web::ViewConfig::transview;

use strict;

sub init {
  my ($view_config) = @_;

  $view_config->_set_defaults(qw(
    show                    plain
    number                  off   
    status_similarity_matches  on
    status_literature          on
    status_oligo_arrays        on
    status_alternative_transcripts on
    das_sources             
  ));
  $view_config->storable = 1;
}
1;
