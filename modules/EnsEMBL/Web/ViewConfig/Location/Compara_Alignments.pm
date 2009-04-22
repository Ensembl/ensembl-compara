package EnsEMBL::Web::ViewConfig::Location::Compara_Alignments;

use strict;

use EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

sub init { 
  my $view_config = shift;
  
  EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::init($view_config);
  
  $view_config->{'no_flanking'} = 1;
  $view_config->_set_defaults(qw(
    flank5_display  0 
    flank3_display  0
  )); 
}
sub form { EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::form(@_); }

1;

