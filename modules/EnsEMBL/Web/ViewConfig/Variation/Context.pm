package EnsEMBL::Web::ViewConfig::Variation::Context;

use strict;
no strict 'refs';

sub init {
  my ($view_config ) = @_;

  $view_config->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      900
    context          30000   

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
  $view_config->add_image_configs({qw(
    snpview nodas
  )});

  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;

### Add context selection
  $view_config->add_fieldset('Context');
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'context',
    'label'    => 'Context',
    'values'   => [
      { 'value' => '1000',   'name' => '1kb' },
      { 'value' => '5000',   'name' => '5kb' },
      { 'value' => '10000',  'name' => '10kb' },
      { 'value' => '20000',  'name' => '20kb' },
      { 'value' => '30000',  'name' => '30kb' },
    ]
  });
}
1;
