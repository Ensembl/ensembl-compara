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
  return undef;
}


sub content {
  my $self = shift;
  my $object = $self->object;
  my $trans = $object->transcript;
  my $pepdata  = $object->translation_object;
  return unless $pepdata;

  my $interpro_hash = $pepdata->get_interpro_links( $trans );
  return unless (%$interpro_hash);
  my $label = 'InterPro';
# add table call here
  my $html = qq(<table cellpadding="4">);
  for my $accession (keys %$interpro_hash){
    my $interpro_link = $object->get_ExtURL_link( $accession, 'INTERPRO',$accession);
    my $desc = $interpro_hash->{$accession};
    $html .= qq(
  <tr>
    <td>$interpro_link</td>
    <td>$desc - [<a href="/@{[$object->species]}/domainview?domainentry=$accession">View other genes with this domain</a>]</td>
  </tr>);
  }
  $html .= qq( </table> );

 return $html;
}

1;

