package EnsEMBL::Web::ScriptConfig::snpview;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      800

    opt_non_synonymous_coding  on
    opt_frameshift_coding      on
    opt_synonymous_coding      on
    opt_5prime_utr             on
    opt_3prime_utr             on
    opt_intronic               on
    opt_downstream             on
    opt_upstream               on
    opt_intergenic             on
    opt_essential_splice_site  on
    opt_splice_site            on
    opt_regulatory_region      on
    opt_stop_gained            on
    opt_stop_lost              on


    opt_freq        on
    opt_cluster     on
    opt_doublehit   on
    opt_submitter   on
    opt_hapmap      on 
    opt_noinfo      on
      
    opt_in-del    on
    opt_snp       on
    opt_mixed     on
    opt_microsat  on
    opt_named     on
    opt_mnp       on
    opt_het       on
    opt_          on
  ));
  $script_config->add_image_configs({qw(
    snpview nodas
  )});

  $script_config->storable = 1;
}
1;
