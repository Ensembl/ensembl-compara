package EnsEMBL::Web::ImageConfig::fake;
use strict;
no strict 'refs';
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

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
