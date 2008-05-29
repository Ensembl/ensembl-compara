package EnsEMBL::Web::Component::Transcript::FamilySummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return undef;
}


sub content {
  my $self = shift;
  my $object = $self->object;

  my $families = $object->get_families;
  return unless keys %$families;

  my $html = qq(<table class="ss tint">
<tr><th>Family ID</th><th>Concensus annotation</th><th>Other genes with peptides in this family</th></tr>
);
  foreach my $family_id (keys %$families) {
    $html .= sprintf(qq(<tr><td>%s</td><td>%s</td>), $family_id, $families->{$family_id}{'description'});

    my $genes = $families->{$family_id}{'genes'};

    if (ref($genes) eq 'ARRAY' && scalar(@$genes) > 1) {
      $html .= sprintf(qq(
    <td>%s genes [<a href="/%s/Transcript/Families?%s;family=%s">Display all</a>]</td></tr>
    ), scalar(@$genes), $object->species, join(';', @{$object->core_params}), $family_id);
    }
    else {
      $html .= qq(<td>none</td></tr>);
    }
  }  
  $html .= '</table>'; 

  $html .= qq(<h3>Prediction method</h3>
    <p>Protein families were generated using the MCL (Markov CLustering)
    package available at <a href="http://micans.org/mcl/">http://micans.org/mcl/</a>.
    The application of MCL to biological graphs was initially proposed by Enright A.J.,
    Van Dongen S. and Ouzounis C.A. (2002) "An efficient algorithm for large-scale
    detection of protein families." Nucl. Acids. Res. 30, 1575-1584.</p>
  );

  return $html;
}

1;

