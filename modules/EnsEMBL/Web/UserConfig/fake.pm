package EnsEMBL::Web::UserConfig::fake;
use strict;
no strict 'refs';
use EnsEMBL::Web::UserConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::UserConfig);

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
