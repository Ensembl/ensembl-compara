# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Verifier;

=head1 NAME

 GO::Verifier - delegation class for GO::Parser

=head1 SYNOPSIS

  my $builder = GO::Verifier->new;
  my $parser = GO::Parser->new($builder);

=head1 DESCRIPTION

This inherits from GO::Builder

It provides a way of verifying flatfiles of ontologies; it mostly a
silent, non-functional GO::Builder, it lets GO::Parser do the actual
checking

=head1 FEEDBACK

  Email: cjm@fruitfly.org

=head1 INHERITED METHODS

=cut

use strict;
use GO::Utils qw(rearrange);
use GO::Builder;
use FileHandle;
use Carp;
use Exporter;
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
use GO::SqlWrapper qw(:all);

use base qw(GO::Builder Exporter);

sub _initialize 
{

    my $self = shift;
    $self->SUPER::_initialize(@_);
    my $paramh = shift;
    my @valid_params = $self->_valid_params;
    map {
	if (defined($paramh->{$_})) {
	    $self->{$_} = $paramh->{$_};
	}
    } @valid_params;
}

sub _valid_params {
    ();
}


sub add_term {
    my ($self, $termh) = @_;
    if (!ref($termh)) {
	confess("$termh - argument must be hashref or obj");
    }
}

=head2 add_dbxref

=cut

sub add_dbxref {
    my ($self, $id, $xrefkey, $xrefdbname) = @_;
}

sub set_category {
    my ($self, $id, $category) = @_;
}

sub add_obsolete_pointer {
    my ($self, $id, $obsolete_id) = @_;
}

sub add_relationship {
    my $self = shift || confess;
    my $from_id = shift;
    my $to_id = shift;
    my $type = shift;
}

sub add_synonym {
    my ($self, $id, $synonym) = @_;
}

sub add_association {
    my $self = shift;
    my $assoc = shift;
}

sub add_definition {
    my $self = shift;
    my $def_h = shift;
    my $xref_h = {};
}

sub commit_changes {
    my $self = shift;
}

sub disconnect {
    my $self = shift;
}

1;
