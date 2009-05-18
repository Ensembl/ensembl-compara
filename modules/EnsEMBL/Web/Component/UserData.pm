package EnsEMBL::Web::Component::UserData;

## Placeholder - no generic methods needed as yet

use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Form;
use base qw( EnsEMBL::Web::Component);

use strict;
use warnings;
no warnings "uninitialized";

sub is_configurable {
  my $self = shift;
  ## Can we do upload/DAS on this page?
  my $flag = 0;
  my $referer = $self->object->param('_referer');
  my @path = split(/\//, $referer);
  my $type = $path[2];
  if ($type eq 'Location' || $type eq 'Gene' || $type eq 'Transcript') {
    (my $action = $path[3]) =~ s/\?.*//;
    my $vc = $self->object->session->getViewConfig( $type, $action);
    $flag = 1 if $vc && $vc->can_upload;
  }
  return $flag;
}

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

