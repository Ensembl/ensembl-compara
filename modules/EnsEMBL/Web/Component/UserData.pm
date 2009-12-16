package EnsEMBL::Web::Component::UserData;

## Placeholder - no generic methods needed as yet

use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Form;
use base qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub get_assemblies {
### Tries to identify coordinate system from file contents
### If on chromosomal coords and species has multiple assemblies,
### return assembly info
  my ($self, $species) = @_;

  my @assemblies = split(',', $self->object->species_defs->get_config($species, 'CURRENT_ASSEMBLIES'));
  return \@assemblies;
}

sub output_das_text {
  my ( $self, $form, @sources ) = @_;
  map {
    $form->add_element( 'type'    => 'Information',
                        'classes'  => ['no-bold'],
                        'value'   => sprintf '<strong>%s</strong><br />%s<br /><a href="%s">%3$s</a>',
                                           $_->label,
                                           $_->description,
                                           $_->homepage );
  } @sources;
}


1;

