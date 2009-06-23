package EnsEMBL::Web::ImageConfig::fake;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self ) = @_;
  $self->{'general'}->{'fake'} = {
    '_artefacts' => [],
    '_options'  => [],
    '_names'   => [],
    '_settings' => {
      'width'         => 800,
    }
  };
}
1;
