# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Modification;

=head1 NAME

  GO::Model::Modification;

=head1 DESCRIPTION

represents a cross reference to an external database

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(id type person mod_time rank);
}


=head2 mod_time

  Usage   -
  Returns -
  Args    -

time in seconds > 1970

=cut

=head2 person

  Usage   -
  Returns -
  Args    -

=cut

=head2 type

  Usage   -
  Returns -
  Args    -

=cut

=head2 time_gmtstr

  Usage   -
  Returns -
  Args    -

=cut

sub time_gmtstr {
    my $self=shift;
    my $t = gmtime($self->mod_time);
    return $t;
}


=head2 pre_term_list

  Usage   -
  Returns -
  Args    -

=cut

sub pre_term_list {
    my $self = shift;
    $self->{pre_term_list} = shift if @_;
    return $self->{pre_term_list};
}

=head2 post_term_list

  Usage   -
  Returns -
  Args    -

=cut

sub post_term_list {
    my $self = shift;
    $self->{post_term_list} = shift if @_;
    return $self->{post_term_list};
}


=head2 add_pre_term

  Usage   -
  Returns -
  Args    -

=cut

sub add_pre_term {
    my $self = shift;
    if (!$self->pre_term_list) {
	$self->pre_term_list([]);
    }
    push(@{$self->pre_term_list}, shift);
    $self->pre_term_list;
}


=head2 add_post_term

  Usage   -
  Returns -
  Args    -

=cut

sub add_post_term {
    my $self = shift;
    if (!$self->post_term_list) {
	$self->post_term_list([]);
    }
    push(@{$self->post_term_list}, shift);
    $self->post_term_list;
}

1;
