# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::TripleHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::TripleHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

package GO::Handlers::TripleHandler;
use base qw(GO::Handlers::DefHandler);

use strict;

sub _valid_params { qw(acc rstr) }

# flattens tree to a hash;
# only top level, not recursive
sub t2fh {
    my $tree = shift;
    return $tree if !ref($tree) || ref($tree) eq "HASH";
    my $h = {map { @$_ } @$tree};
    return $h;
}

sub t2fa {
    my $tree = shift;
    return map { $_->[1] } @$tree;
}

sub e_ontology {
    my $self = shift;
}

sub e_acc {
    my $self = shift;
    my $acc = shift;
    $self->acc($acc);
    $self->_emit("type", $acc, "term");
}

sub e_name {
    my $self = shift;
    my $v = shift;
    $self->_emit("name", $self->acc, $v);
}

sub e_is_obsolete {
    my $self = shift;
    my $v = shift;
    $self->_emit("has_property", $self->acc, "is_obsolete") if $v;
}

sub e_synonym {
    my $self = shift;
    my $v = shift;
    $self->_emit("has_synonym", $self->acc, $v);
}

sub e_secondaryid {
    my $self = shift;
    my $v = shift;
    $self->_emit("has_synonym", $self->acc, $v);
}

sub e_relationship {
    my $self = shift;
    my $tree = shift;
    my $h = t2fh($tree);
    $self->_emit($h->{type}, $self->acc, $h->{obj});
}

sub e_dbxref {
    my $self = shift;
    my $tree = shift;
    my ($db, $acc) = t2fa($tree);
    my $xr = "$db:$acc";
    $self->_emit("type", $xr, "dbxref");
    $self->_emit("xref_key", $xr, $acc);
    $self->_emit("xref_dbname", $xr, $db);
    $self->_emit("has_dbxref", $self->acc, $xr);
}

sub _emit {
    my $self = shift;
    my @t = @_;
    if (1) {
        my %mapping =
          (isa=>"daml:subClassOf",
          );
        my ($p, $s, $o) = @t;
        my $newp = $mapping{$p};
        if ($newp) {
            $p = $newp;
        }
        elsif (grep {$p eq $_}
               qw(partof developsfrom)) {
            $self->rstr(1) unless $self->rstr;
            my $rstr = $self->rstr;
            $self->rstr($rstr+1);
            $rstr = "_anon$rstr";
            $self->emit("daml:subClassOf", $s, $rstr);
            $self->emit("daml:type", $rstr, "daml:Restriction");
            $self->emit("daml:hasValue", $rstr, $o);
            $self->emit("daml:onProperty", $rstr, "go:partOf");
        }
        elsif ($p eq "type" && $o eq "term") {
            $o = "daml:Class";
        }
        else {
            $p = "go:$p";
        }
    }
    $self->emit(@t);
}

sub emit {
    my $self = shift;
    my ($pred, $subj, $obj) = @_;
    print "@_\n";
}

1;
