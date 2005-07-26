# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::OboOutHandler     - 

=head1 SYNOPSIS

  use GO::Handlers::OboOutHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS - 

=cut

# makes objects from parser events

package GO::Handlers::OboOutHandler;
use base qw(GO::Handlers::ObjHandler);
use strict;

sub out {
    my $self = shift;
    my $g = $self->g;
    $self->write_hdr;
    foreach my $t (@{$g->get_all_nodes}) {
        $self->write_term($t);
    }
    $self->write_end;
}

sub e_ontology {
    my $self = shift;
    $self->out;
}

sub write_hdr {
    my $self = shift;
    my $hdr = <<EOM;
[ontology]
name: blah

EOM
  $self->print($hdr);
}

sub write_end {
    my $self = shift;
    return;

#    $self->print("end-ontology\n");
}

sub write_term {
    my $self = shift;
    my $t = shift;
    my $g = $self->g;
    $self->print("[term]\n");
    $self->tag(acc => $t->acc);
    $self->tag(name => $t->name);
    $self->tag(definition => $t->definition);
    $self->tag(type => $t->type);

    my $prels = $g->get_parent_relationships($t->acc) || [];
    $self->tag(relationship => sprintf("%s %s  !! %s",
                                       $_->type,
                                       $_->object_acc,
				       $g->get_term($_->object_acc)->name))
      foreach @$prels;
    my $props = $t->property_list || [];
    $self->tag(property => sprintf("%s %s %s",
                                   $_->name,
                                   $_->range_acc,
                                   $_->textrule || ''))
      foreach @$props;
    my $xp = $g->get_cross_product($t->acc);
    if ($xp) {
        my $restrs = $xp->restriction_list || [];
	my @rterms = map { $g->get_term($_->value)} @$restrs;
        $self->tag(cross_product =>
                   sprintf("%s %s !! %s",
                           $xp->parent_acc,
                           join(' ',
                                (map {sprintf("(%s %s)", 
					      $_->property_name, $_->value)} @$restrs)),
			   join(' ',
				(map {$_ ? $_->name : '?'} @rterms)),
			       ));
    }
    my $syns = $t->synonym_list;
    $self->tag(definition => $_) foreach @$syns;

    $self->print("\n");

}

sub tag {
    my $self = shift;
    my ($t, $v) = @_;
    return unless $v;
    $self->printf("$t: $v\n");
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
