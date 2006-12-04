=head1 NAME

EnsEMBL::Web::Component::DAS

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=head1 AUTHOR

Eugene Kulesha, ek3@sanger.ac.uk

=cut

package EnsEMBL::Web::Component::DAS;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;

sub features {
  my( $panel, $object ) = @_;
  my @segments = $object->Locations;
  foreach my $segment (@segments) {
    warn(join ('*', "SEGMENT:", $segment->seq_region_name, $segment->seq_region_start, $segment->seq_region_end));
  }
}

sub types {
  my( $panel, $object ) = @_;

  my $features = $object->Types();

  my $template = qq{<TYPE id="%s"%s%s>%s</TYPE>\n};
  (my $url = lc($ENV{SERVER_PROTOCOL})) =~ s/\/.+//;
  $url .= "://$ENV{SERVER_NAME}";
#    $url .= "\:$ENV{SERVER_PORT}" unless $ENV{SERVER_PORT} == 80;
  $url .="$ENV{REQUEST_URI}";

  $panel->print(sprintf("<GFF href=\"%s\" version=\"1.0\">\n", $url));

  foreach my $e (@{$features || []}) {
    my ($id, $method, $category, $text) = @$e;
    $method = qq{ method="$method"} if  ($method);
    $category = qq{ category="$category"} if ($category);
    $panel->print(sprintf($template, $id, $method, $category, $text));
  }
  $panel->print(qq{</GFF>\n});
}

1;
