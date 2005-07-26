# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Model::GraphNodeInstance;

=head1 NAME

  GO::Model::GraphNodeInstance;

=head1 SYNOPSIS

  $it = $graph->create_iterator;
  # returns a GO::Model::GraphIterator object

  while (my $ni = $it->next_node_instance) {
    $depth = $ni->depth;
    $term = $ni->term;
    $reltype = $ni->parent_rel->type;
    printf 
      "%s %8s Term = %s (%s)  // n_assocs=%s // depth=%d\n",
          "----" x $depth,
          $reltype,
	  $term->name,
	  $term->public_acc,
	  $term->n_associations || 0,
          $depth;
  }


=head1 DESCRIPTION

see GO::Model::Graph

=cut



use Carp;
use strict;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Term;
use FileHandle;
use Exporter;
use Data::Dumper;
use vars qw(@EXPORT_OK %EXPORT_TAGS);

use base qw(GO::Model::Root Exporter);

sub _valid_params {
    return qw(term path depth parent_rel blocked);
}

=head2 term

  Usage   - 
  Returns - GO::Model::Term 
  Args    - 

=cut

=head2 depth

  Usage   - 
  Returns - int
  Args    - 

=cut

=head2 parent_rel

  Usage   - 
  Returns - GO::Model::Relationship
  Args    - 

=cut


#=head2 block

#  Usage   -
#  Returns -
#  Args    -

#blocking a node instance will stop the graph iterator going below this one

#=cut

#sub block {
#    my $self = shift;
#    $self->blocked(1);
#}

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
}


1;
