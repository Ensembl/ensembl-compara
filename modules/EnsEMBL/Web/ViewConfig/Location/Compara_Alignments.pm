package EnsEMBL::Web::ViewConfig::Location::Compara_Alignments;

use strict;

use EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

sub init { EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::init(@_); }
sub form { EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments::form(@_); }

1;

