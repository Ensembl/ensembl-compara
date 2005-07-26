# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Browser::HTMLPlugin1;

use strict;

sub new {
  my $class=shift;
  my $args=shift;
  my $self={};
  $self->{urlpost} = $args->{urlpost};
  $self->{rooturl} = $args->{rooturl};
  $self->{HTMLString} = '';
  bless $self, $class;
}

sub start_table {
  my $self = shift;
  my $name = shift;

  $self->{HTMLString} .= "<table><tr><th> $name->{name} : </th></tr><tr><td nowrap>";
}

sub end_table {
  my $self=shift;
  
  $self->{HTMLString} .= "</td></tr></table>";
}
  

sub grow_html {
  my $self=shift;
  my $addon=shift;
  
  $self->{HTMLString} .= $addon->{string};
}

sub add_term {
  my $self=shift;
  my $term=shift;

  $self->{HTMLString} .= $self->{rooturl} . "?accession=$term->{term}->{acc}";
  $self->{HTMLString} .= "&" . $self->{urlpost} . ">";
  $self->{HTMLString} .= $term->{term}->{acc}. "  :  ";
  $self->{HTMLString} .= $term->{term}->{name} . $term->{namepost} ;
  $self->{HTMLString} .= "</a>";

}

sub add_term_image {
  my $self=shift;
  my $term=shift;
  
  $self->{HTMLString} .= $self->{rooturl} . "?accession=$term->{term}->{acc}&";
  $self->{HTMLString} .= $self->{urlpost}. ">";
  $self->{HTMLString} .= "<img src=" . "\"" . $term->{image} . "\"" . " alt='$term->{term}->{acc}" . "  :  " . $term->{term}->{name} . "'";
  $self->{HTMLString} .= "border=0 hspace=1>";
  $self->{HTMLString} .= "</a>";
  
}

sub get_html {
  my $self = shift;
  return $self->{HTMLString};
}

1;

