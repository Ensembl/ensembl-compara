package EnsEMBL::Web::ViewConfig::ldview;

use strict;
no strict 'refs';

use EnsEMBL::Web::ViewConfig;
our @ISA = qw(EnsEMBL::Web::ViewConfig);

sub init {
  my ($view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_options    on
    panel_image      on
    image_width      800
    context          10000

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

  ));
  $view_config->add_image_configs({qw(
    ldview        nodas
    LD_population nodas
  )});
  $view_config->storable = 1;

}
1;
