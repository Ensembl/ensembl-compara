package EnsEMBL::Web::ViewConfig::Gene::Sequence;

use strict;
use warnings;
no warnings 'uninitialized';
use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;

  $view_config->title = 'Marked up gene sequence';
  $view_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600
    display_width           60
    exon_display            core
    exon_ori                all
    snp_display             off
    line_numbering          off
  ));
  $view_config->storable = 1;

}

sub form {
  my( $view_config, $object ) = @_;
  my %gene_markup_options    =  EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  my %other_markup_options = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;

  #options shared with marked-up sequence
  $view_config->add_form_element($gene_markup_options{'flank5_display'});
  $view_config->add_form_element($gene_markup_options{'flank3_display'});
  $view_config->add_form_element($other_markup_options{'display_width'});

  if ($object->species_defs->databases->{'DATABASE_VEGA'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}}, { 'value' => 'vega', 'name' => 'Vega exons' };
  }
  if ($object->species_defs->databases->{'DATABASE_OTHERFEATURES'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}},  { 'value' => 'otherfeatures', 'name' => 'EST gene exons' };
  }
  $view_config->add_form_element($gene_markup_options{'exon_display'});

  #options shared with resequencing and marked-up sequence
  $view_config->add_form_element($general_markup_options{'exon_ori'});
  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    $view_config->add_form_element( $general_markup_options{'snp_display'} );
  }
  $view_config->add_form_element( $general_markup_options{'line_numbering'} );

}
1;

