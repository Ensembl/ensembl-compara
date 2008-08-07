package EnsEMBL::Web::Component::Transcript::Interpro;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return 'Domains';
}


sub content {
  my $self = shift;
  my $object = $self->object;

  ## Table of Interpro domains
  my $interpro = $object->get_interpro;
  return unless keys %$interpro;
  my $html = qq(<table cellpadding="4">);
  while ( my ($accession, $data) = each (%$interpro)){
    $html .= sprintf(qq(
  <tr>
    <td>%s</td>
    <td>%s - [<a href="/%s/Transcript/Domain?%s;domain=%s">Display other genes with this domain</a>]</td>
  </tr>), 
    $data->{'link'}, $data->{'desc'}, $object->species, join(';', @{$object->core_params}), $accession );
  }
  $html .= qq( </table> );

  return $html;
}

1;

