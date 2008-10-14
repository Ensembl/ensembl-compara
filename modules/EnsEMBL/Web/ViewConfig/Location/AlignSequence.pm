package EnsEMBL::Web::ViewConfig::Location::AlignSequence;

use strict;
use warnings;
no warnings 'uninitialized';
use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  $view_config->title = 'Resequencing Alignments';
  $view_config->_set_defaults(qw(
    display_width           120
    exon_ori                all
    snp_display             off
    line_numbering          off
    codons_display          off
    title_display           off
  ));
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  #shared with compara_markup and marked-up sequence
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  #shared with compara_markup
  my %other_markup_options = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;

  $view_config->add_form_element($other_markup_options{'display_width'});
  push @{$general_markup_options{'exon_ori'}{'values'}}, { 'value' =>'off' , 'name' => 'None' };
  $general_markup_options{'exon_ori'}{'label'} = 'Exons to highlight';
  $view_config->add_form_element($general_markup_options{'exon_ori'});

  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    $view_config->add_form_element($general_markup_options{'snp_display'} );
  }
  $view_config->add_form_element($general_markup_options{'line_numbering'} );
  $view_config->add_form_element($other_markup_options{'codons_display'});
  $view_config->add_form_element($other_markup_options{'title_display'});

}

1;
