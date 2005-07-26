package EnsEMBL::Web::UserConfig::EnsEMBL::contigviewtop;

use strict;
use EnsEMBL::Web::UserConfig::contigviewtop;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig::contigviewtop);

sub init {
  my $self = shift;
  $self->SUPER::init() if( $self->SUPER::can('init') );
 # $self->remove_artefacts( 'marker' );
 # $self->add_artefacts( 'rat_synteny', 'mouse_synteny', 'celegans_synteny', 'cbriggsae_synteny', 'human_synteny' );
}

1;
