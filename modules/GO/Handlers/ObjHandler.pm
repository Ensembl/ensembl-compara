# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.godatabase.org/dev
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::Handlers::ObjHandler     - parses GO files into GO object model

=head1 SYNOPSIS

  use GO::Handlers::ObjHandler

=cut

=head1 DESCRIPTION

=head1 PUBLIC METHODS

=cut

# makes objects from parser events

package GO::Handlers::ObjHandler;
use Data::Stag qw(:all);
use base qw(GO::Handlers::DefHandler);
use strict;


sub init {
    my $self = shift;
    $self->SUPER::init;

    use GO::ObjCache;
    my $apph = GO::ObjCache->new;
    $self->{apph} = $apph;

    use GO::Model::Graph;
    my $g = $self->apph->create_graph_obj;
    $self->{g} = $g;
    return;
}


=head2 graph

  Usage   -
  Returns - GO::Model::Graph object
  Args    -

as files are parsed, objects are created; depending on what kind of
datatype is being parsed, the classes of the created objects will be
different - eg GO::Model::Term, GO::Model::Association etc

the way to access all of thses is through the top level graph object

eg

  $parser = GO::Parser->new({handler=>'obj'});
  $parser->parse(@files);
  my $graph = $parser->graph;
  

=cut

=head2 g

  Usage   -
  Returns -
  Args    -

synonym for $h->graph

=cut

=head2 ontology

  Usage   -
  Returns -
  Args    -

synonym for $h->graph

=cut

sub g {
    my $self = shift;
    $self->{g} = shift if @_;
    return $self->{g};
}

*graph = \&g;
*ontology = \&g;


sub apph {
    my $self = shift;
    $self->{apph} = shift if @_;
    return $self->{apph};
}

sub e_obo {
    my $self = shift;
    my $g = $self->g;
#    print $g->to_text_output("gotext", 1);
#    die;
    return [];
}

sub e_ontology {
    my $self = shift;
    my $ont = shift;
    $self->{ontology_type} = stag_get($ont, 'name');
#    print $g->to_text_output("gotext", 1);
#    die;
    return [];
}

sub e_term {
    my $self = shift;
    my $tree = shift;
    use GO::Model::Term;
    my $acc = stag_get($tree, "id");
    if (!$acc) {
        print Dumper($tree);
        $self->throw( "NO ACC: $@\n" );
    }
    my $term;
    eval {
        $term = $self->g->get_term($acc);
    };
    if ($@) {
        print $@;
    }
    # no point adding term twice; we
    # assume the details are the same
    return $term if $term && $self->strictorder;

    $term = $self->apph->create_term_obj;
    my %h = ();
    use Data::Dumper;
#    print Dumper "****\n", $tree;
    foreach my $sn (stag_kids($tree)) {
        my $k = $sn->name;
        my $v = $sn->data;

        if ($k eq 'relationship') {
            my %rh = stag_pairs($sn);
            my $obj = $rh{obj} || $rh{object};
            $self->g->add_relationship($obj, $term->acc, $rh{type});
        }
        elsif ($k eq 'property') {
            my %ph = stag_pairs($sn);
            my $prop =
              $self->apph->create_property_obj({name=>$ph{name},
                                                range_acc=>$ph{range},
                                                namerule=>$ph{namerule},
                                                defrule=>$ph{defrule},
                                               });
            $term->add_property($prop);
        }
        elsif ($k eq 'dbxref') {
            my $xref =
	      $self->apph->create_xref_obj(stag_pairs($sn));
            $term->add_dbxref($xref);
        }
        elsif ($k eq 'cross_product') {
            my %ph = stag_pairs($sn);
            my $xp =
              $self->g->add_cross_product($term->acc,
                                          $ph{parent_acc},
                                          []);
            foreach (stag_get($sn, 'restriction')) {
                $xp->add_restriction(stag_get($_, 'property_name'),
                                     stag_get($_, 'value'))
            }

        }
        elsif ($k eq 'id') {
            $term->acc($v);
        }
        elsif ($term->can($k)) {
            $term->$k($v);
        }
        elsif ($term->can("add_$k")) {
            my $m = "add_$k";
            $term->$m($v);
        }
        else {
            $term->stag->add($k, $v);
#            $self->throw("don't know what to do with $k");
#            print "no $k\n";
        }
    }
    $term->type($self->{ontology_type}) unless $term->type;
    if (!$term->name) {
        $term->name($term->acc);
    }
    $self->g->add_term($term);
#    $term;
    return [];
}

# end of definition
sub e_def {
    my $self = shift;
    my $tree = shift;
    my $g = $self->g;
    my $acc = stag_get($tree, "godef-goid");
    my $dbxref = stag_get($tree, "godef-definition_reference");
    my $comment = stag_get($tree, "godef-comment");

    my $t = $g->get_term($acc);
    if (!$t) {
        $self->message("no such term $acc");
        return;
#        print Dumper $tree;
#        return;
#        print Dumper $tree;
#        die $acc;
    }
    $t->definition(stag_sget($tree,"godef-definition"));
    $t->add_definition_dbxref($dbxref) if $dbxref;
    $t->comment($comment) if $comment;

#    printf "setting %s to %s\n", $t->acc, $t->definition;
    return [];
}
sub e_termdbxref {
    my $self = shift;
    my $tree = shift;
    my $g = $self->g;
    my $acc = stag_get($tree, "termacc");
    my $t = $g->get_term($acc);
    if (!$t) {
        if (!$self->strictorder) {
            $t = $self->apph->create_term_obj({acc=>$acc});
            $self->g->add_term($t);
        }
        else {
            $self->message("no such term $acc");
            return;
        }
    }
    $t->add_xref(stag_get($tree,"dbxref"));
#    printf "setting %s to %s\n", $t->acc, $t->dbxref_list->[0]->as_str;
    return [];
}

# transform tree beneath dbxref to a Xref object
#sub e_dbxref {
#    my $self = shift;
#    my $tree = shift;
#    [dbxref => ];
#}


sub e_proddb {
    my $self = shift;
    $self->proddb(shift);
    return [];
}

sub e_prod {
    my $self = shift;
    my $tree = shift;
    my $g = $self->g;
    my $prod =
      $self->apph->create_gene_product_obj({symbol=>stag_sget($tree, "prodsymbol"),
                                            full_name=>stag_sget($tree, "prodname"),
                                            speciesdb=>$self->proddb,
                                      });
    my @syns = stag_get($tree, "prodsyn");
    $prod->xref->xref_key(stag_sget($tree, "prodacc"));
    $prod->synonym_list(\@syns);
    my @assocs = stag_get($tree, "assoc");
    foreach my $assoc (@assocs) {
        my $acc = stag_get($assoc, "termacc");
        if (!$acc) {
            $self->message("no accession given");
            next;
#            print Dumper $tree;
#            exit;
        }
        my $t = $g->get_term($acc);
        if (!$t) {
            if (!$self->strictorder) {
                $t = $self->apph->create_term_obj({acc=>$acc});
                $self->g->add_term($t);
            }
            else {
                $self->message("no such term $acc");
                next;
#                print Dumper $tree;
#                return;
            }
        }
        my @evs = stag_get($assoc, "evidence");
        my $ao =
          $self->apph->create_association_obj({gene_product=>$prod,
                                               is_not=>stag_sget($assoc, "is_not"),
                                              });
        foreach my $ev (@evs) {
            my $eo =
              $self->apph->create_evidence_obj({
                                                code=>stag_sget($ev, "evcode"),
                                               });
            my @seq_xrefs = stag_get($ev, "seq_acc"),
            my @refs = stag_get($ev, "ref");
            map { $eo->add_seq_xref($_) } @seq_xrefs;
            map { $eo->add_pub_xref($_) } @refs;
            $ao->add_evidence($eo);
        }
        $t->add_association($ao);
#        print Dumper $t;
    }
#    return [prod=>$prod];
    return [];
}

1;
