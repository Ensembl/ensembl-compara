package EnsEMBL::Web::Component::Blast;

use base qw( EnsEMBL::Web::Component);
use strict;
use warnings;

sub add_alignment_links {
### Compile links to alternative views of alignment data
  my ($self, $current) = @_;
  my $object = $self->object;
  my %lookup = (
    'align' => 'Alignment',
    'query' => 'Query Sequence',
    'genomic' => 'Genomic Sequence',
  );
  my $html;
  foreach my $type (keys %lookup) {
    next if $type eq $current;
    $object->param('display', $type);
    my $url = '/Blast/Alignment?';
    my @new_params;
    foreach my $p ($object->param) {
      push @new_params, $p.'='.$object->param($p);
    }
    $url .= join(';', @new_params);
    $html .= qq(<a href="$url">View ).$lookup{$type}.'</a> ';
  }
  $object->param('display', $current); ## reset CGI parameter
  return $html;
}


1;
