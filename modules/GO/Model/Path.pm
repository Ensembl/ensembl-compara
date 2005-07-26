# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Model::Path;

=head1 NAME

  GO::Model::Path;

=head1 SYNOPSIS

=head1 DESCRIPTION

represents a path between two nodes in a graph

  TODO: have the path be built of relationships rather than terms, so
  we can get the edgetypes in here

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(term_list);
}


=head2 term_list

  Usage   -
  Returns - arrayref of GO::Model::Term
  Args    -

gets/sets an ordered list of terms in the path

=cut

sub add_term {
    my $self = shift;
    if (!$self->{term_list}) {
	$self->{term_list} = [];
    }
    push(@{$self->{term_list}}, shift) if @_;
    $self->{term_list};
}


=head2 length

  Usage   - print $path->length
  Returns - int
  Args    -

=cut

sub length {
    my $self = shift;
    return scalar(@{$self->{term_list} || []});
}


=head2 to_text

  Usage   -
  Returns -
  Args    -

=cut

sub to_text {
    my $self = shift;
    return
      join(' -> ',
           map {$_->name} @{$self->term_list||[]})."\n";
}

=head2 duplicate

  Usage   -
  Returns -
  Args    -

=cut

sub duplicate {
    my $self = shift;
    my $dup = $self->new;
    $dup->term_list([@{$self->term_list || []}]);
    $dup;
}


1;
