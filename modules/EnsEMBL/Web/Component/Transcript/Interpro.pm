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
  return 'InterPro';
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
    <td>%s - [<a href="/%s/Transcript/Domain?r=%s:%s-%s;g=%s;t=%s;domain=$accession">Display other genes with this domain</a>]</td>
  </tr>), $data->{'link'}, $data->{'desc'}, $object->species, 
        $object->core_objects->location->seq_region_name, 
        $object->core_objects->location->start, $object->core_objects->location->end,
        $object->core_objects->gene->stable_id, $object->core_objects->transcript->stable_id);
  }
  $html .= qq( </table> );

  ## Karyotype showing location of other genes with this domain
  if ($object->param('domain')) {
    $html .= 'Karyotype goes here!';
  }

  return $html;
}

1;

