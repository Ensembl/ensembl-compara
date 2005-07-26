# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::OilOutHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::OilOutHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

# makes objects from parser events

package GO::Handlers::OilOutHandler;
use base qw(GO::Handlers::ObjHandler);
use strict;

sub e_subgraph {
    my $self = shift;
    my $g = $self->g;
    $self->write_hdr;
    foreach my $t (@{$g->get_all_nodes}) {
        $self->write_classdef($t);
    }
    $self->write_end;
}

sub write_hdr {
    my $self = shift;
    my $hdr = <<EOM;
begin-ontology
ontology-container
title "Blah"
creator "autocreated"
description "blah"
description.release "1.0"
type ontology
identifier "id"
language "OIL"


ontology-definitions


EOM
  $self->print($hdr);
}

sub write_end {
    my $self = shift;
    $self->print("end-ontology\n");
}

sub write_classdef {
    my $self = shift;
    my $t = shift;
    my $g = $self->g;
    $self->printf("class-def defined %s\ndocumentation %s\n",
                  safe($t->name),
                  quote($t->definition || $t->name));
    my $prels = $g->get_parent_relationships($t->acc);
    my @subclassof =
      map { $g->get_term($_->acc1) }
        grep {lc($_->type) eq "isa"} @$prels;
    my @restrs =
      grep {lc($_->type) ne "isa"} @$prels;
    if (@subclassof) {
        $self->printf("subclass-of\n%s",
                      join("",
                           map {
                               "  ".safe($_->name)."\n"
                           } @subclassof));
    }
    if (@restrs) {
        map {
            $self->printf("  slot-constraint %s has-value %s\n",
                          $_->type,
                          safe($g->get_term($_->acc1)->name));
        } @restrs;
    }
    $self->print("\n");
}

sub safe {
    my $word = shift;
    $word =~ s/ /_/g;
    $word =~ s/\-/_/g;
    $word =~ s/\'/prime/g;
    $word =~ tr/a-zA-Z0-9_//cd;
    $word =~ s/^([0-9])/_$1/;
    $word;
}

sub quote {
    my $word = shift;
    $word =~ s/\'//g;
    $word =~ s/\"/\\\"/g;
    $word =~ tr/a-zA-Z0-9_//cd;
    "\"$word\"";
}

1;
