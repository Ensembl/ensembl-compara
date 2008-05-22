package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my %family_data = %{$object->get_all_families};

  my $html;
  foreach my $family_id (sort keys %family_data) {
    my $family = $family_data{$family_id};
    my $plural = $family->{'info'}{'count'} > 1 ? 's' : '';
    $html .= sprintf(q(<h3>%s</h3><p>%s. This cluster contains %s Ensembl gene member%s 
in this species.<p><strong>Transcripts with peptides in this family</strong>:</p>
<ul>),
            $family_id, $family->{'info'}{'description'}, $family->{'info'}{'count'}, $plural);

    my @transcripts;
    foreach my $transcript (@{$family->{'transcripts'}}) {
      my $label = $transcript->display_xref;
      $html .= sprintf(q(<li><a href="/%s/Transcript/Families?g=%s;t=%s">%s</a> (%s)</li>),
                        $object->species, $object->Obj->stable_id, 
                        $transcript->stable_id, $label, $transcript->stable_id);
    }
    $html .= '</ul>';
  }

  return $html;
}

1;
