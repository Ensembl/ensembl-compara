package EnsEMBL::Web::Data::Record::DAS;

use strict;
use warnings;
use EnsEMBL::Web::DASConfig;

use base qw(EnsEMBL::Web::Data::Record);

__PACKAGE__->_type('das');

__PACKAGE__->add_fields(
  url    => 'text',
  name   => 'text',
  config => 'text',
);

# TODO: remove?
=head
sub get_das_config {
  my ($self) = @_;
  my $dasconfig = EnsEMBL::Web::DASConfig->new;
  $dasconfig->create_from_hash_ref($self->config);
  return $dasconfig;
}
=cut

1;