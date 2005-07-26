# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::DefHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::DefHandler

=cut

=head1 DESCRIPTION

Default Handler, other handlers inherit from this class

this class catches events (start, end and body) and allows the
subclassing module to intercept these. unintercepted events get pushed
into a tree

See GO::Parser for details

=head1 PUBLIC METHODS - 

=cut

package GO::Handlers::DefHandler;

use strict;
use Exporter;
use Carp;
use GO::Model::Root;
use vars qw(@ISA @EXPORT_OK @EXPORT);
use base qw(Data::Stag::BaseHandler Exporter);

@EXPORT_OK = qw(lookup);

sub strictorder {
    my $self = shift;
    $self->{_strictorder} = shift if @_;
    return $self->{_strictorder};
}

sub proddb {
    my $self = shift;
    $self->{_proddb} = shift if @_;
    return $self->{_proddb};
}


sub ontology_type {
    my $self = shift;
    $self->{_ontology_type} = shift if @_;
    return $self->{_ontology_type};
}


sub messages {
    my $self = shift;
    $self->{_messages} = shift if @_;
    return $self->{_messages};
}

*error_list = \&messages;

sub message {
    my $self = shift;
    push(@{$self->messages},
         shift);
}


sub lookup {
    my $tree = shift;
    my $k = shift;
#    use Data::Dumper;
#    print Dumper $tree;
#    confess;
    if (!ref($tree)) {
        confess($tree);
    }
    my @v = map {$_->[1]} grep {$_->[0] eq $k} @$tree;
    if (wantarray) {
        return @v;
    }
    $v[0];
}


sub print {
    my $self = shift;
    print "@_";
}

sub printf {
    my $self = shift;
    printf @_;
}

sub throw {
    my $self = shift;
    my @msg = @_;
    confess("@msg");
}
sub warn {
    my $self = shift;
    my @msg = @_;
    warn("@msg");
}

1;
