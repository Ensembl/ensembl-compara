# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::AppHandles::AppHandleCWrapper;

=head1 NAME

GO::AppHandles::AppHandleCWrapper

=head1 SYNOPSIS

you should never use this class directly. Use GO::AppHandle
(All the public methods calls are documented there)

=head1 DESCRIPTION

implementation of GO::AppHandle that uses an underlying C library for
speed

=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

=cut


use strict;
use Carp;
use FileHandle;
use Carp;
use DBI;
use GO::Utils qw(rearrange pset2hash dd);
use GO::SqlWrapper qw(:all);
use GO::Model::Xref;
use GO::Model::Term;
use GO::Model::Association;
use GO::Model::GeneProduct;
use GO::Model::Relationship;
use GO::Model::Graph;
use GO::Model::Modification;
use Exporter;
use base qw(GO::AppHandle);
use vars qw($AUTOLOAD);

# should only be instantiated via GO::AppHandle
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $init_h = shift;
    $self->setup($init_h);
    return $self;
}



sub impl {
    my $self = shift;
    $self->{_impl} = shift if @_;
    return $self->{_impl};
}


sub setup {
    my $self = shift;
    my $init_h = shift;
    
    my $impl = Wrapper->new;
    $self->impl($impl);
    my @files = @{$init_h->{files}};
    if (!@files) {
	confess;
    }
    foreach my $f (@files) {
	$impl->parse_file($f);
    }
}

sub write_graph {
    my $self = shift;
    $self->impl->_write_graph();
}

sub commit {
    my $self = shift;
}

sub disconnect {
    my $self = shift;
}


# not ready yet...
sub store_term {
    my $self = shift;
}

sub add_term {
    my $self = shift;
}

sub update_term {
    my $self = shift;
}

sub check_term {
    my $self = shift;
}

sub add_synonym {
    my $self = shift;
}

sub add_dbxref {
    my $self = shift;
}

sub get_term {
    my $self = shift;
    my $terms = $self->get_terms(@_);
    return $terms->[0];   # returns undef if empty
}

sub get_terms {
    my $self = shift;
    my ($inconstr, $template) =
      rearrange([qw(constraints template)], @_);
    my $constr = pset2hash($inconstr);

    my @terms = ();
    if (!ref($constr)) {
	$constr = {"acc"=>$constr};
    }
    if ($constr->{acc}) {
	my $acc = $constr->{acc};
	if ($acc =~ /^GO:/) {
	    $acc =~ s/GO://;
	}
	my $term = $self->impl->get_node_by_acc($acc);
	if ($term) {
	    @terms = $term;
	}
    }
    return [@terms];
}

sub get_term_by_acc {
    my $self = shift;
    my ($acc, $attrs) =
      rearrange([qw(acc attributes)], @_);
    return $self->get_term({acc=>$acc});
}


sub get_terms_by_search {
    my $self = shift;
    my ($search, $attrs) =
      rearrange([qw(search attributes)], @_);
    return $self->get_terms({search=>$search});
}

sub get_associations {
    my $self = shift;
    my ($termh) =
      rearrange([qw(term)], @_);
    my $term = 
      (ref($termh) eq "HASH" || !$termh->id)
	? $self->get_term($termh) : $termh;
}

sub get_relationships {
    my $self = shift;
    my ($constr) =
      rearrange([qw(constraints)], @_);
    my @constr_arr = ();
    if (!ref($constr)) {
	confess("constraints must be hashref!");
#	$constr = {"term.name"=>$constr};
    }
}


sub get_parent_terms {
    my $self = shift;
    my ($node) =
      rearrange([qw(term)], @_);
}


sub get_node_graph {
    my $self = shift;
    my ($acc, $max_depth) =
      rearrange([qw(acc depth)], @_);
    if (!$acc) {
	confess("You must specify a go id");
    }
    my $graph = GO::Model::Graph->new;
}

sub get_graph {
    my $self = shift;
    $self->get_node_graph(@_);
}

sub get_graph_by_acc {
    my $self = shift;
    $self->get_node_graph(@_);
}


sub get_graph_by_search {
    my $self = shift;
    my ($srch, $max_depth) =
      rearrange([qw(search depth)], @_);
    my $graph = GO::Model::Graph->new;
    my $term_l = $self->get_terms({search=>$srch});
    return $graph;
    
}

sub get_product {
    my $self = shift;
    my ($constr, $attrs) =
      rearrange([qw(constraints attributes)], @_);
}


sub get_dbxrefs {
    my $self = shift;
    my ($constr) =
	rearrange([qw(constraints)], @_);
}

sub show {
    my $self = shift;
    my ($constr) =
      rearrange([qw(constraints)], @_);
    my $id_h = {};
    my $term  = $self->get_term($constr);
    
}

sub get_statistics {
    my $self = shift;

}

sub get_paths_to_top {
    my $self = shift;
    my ($termh) =
      rearrange([qw(term)], @_);
    my $term = 
      (ref($termh) eq "HASH" || !$termh->id)
	? $self->get_term($termh) : $termh;
    my $graph = $self->get_graph_to_top($term->acc);
    return $graph->paths_to_top($term->acc);
}

# 
sub get_graph_to_top {
    my $self = shift;
    my $acc=shift;
    
    my $graph = GO::Model::Graph->new;
}



# C Wrapper

package Wrapper;
#use GO::CWrapper::TermC;

use Inline C => Config =>
  INC => "-I$ENV{GO_ROOT}/c-lib/",
  LIBS => "-lm -lglib -L$ENV{GO_ROOT}/c-lib/ -lGO";  

use Inline C => <<'END_C';

#include <glib.h>
#include <golib.h>

SV* new(char *class) {
    SV*      obj_ref = newSViv(0);
    SV*      obj = newSVrv(obj_ref, class);
    GoHandle *handle;

    handle = newGoHandle();
    printf("hello\n");
 
    sv_setiv(obj, (IV)handle);
    SvREADONLY_on(obj);
    return obj_ref;
}

void parse_file(SV* obj, char *f) {
    GoHandle *h = (GoHandle*)SvIV(SvRV(obj));
    parseFile(h, f);
}
void find_paths_to_top(SV* obj, int acc) {
    GoHandle *h = (GoHandle*)SvIV(SvRV(obj));
    fprintf(stderr, "finding paths for %d\n", acc);
    findPathsToTop(h, acc);
}

void _write_graph(SV* obj) {
    GoHandle *h = (GoHandle*)SvIV(SvRV(obj));
    printf("writing graph\n");
    writeGraph(h);
}


SV* newTermObP() {
  TermOb* t = malloc(sizeof(TermOb));
  SV*      obj_ref = newSViv(0);
  SV*      obj = newSVrv(obj_ref, "TermC");
 
  sv_setiv(obj, (IV)t);
  SvREADONLY_on(obj);
  return obj_ref;
}

SV* get_node_by_acc(SV *obj, long acc) {
   GoHandle *handle = (GoHandle*)SvIV(SvRV(obj));
   Node *node;
   TermOb *term_ob;
   SV *sv;

   fprintf(stderr, "getting node %d\n", acc);
   node = handle->nodes[acc];
   sv = newTermObP(); 
   term_ob = (TermOb*)SvIV(SvRV(sv));
   term_ob->handle = handle;
   term_ob->node = node;
   return sv;
}


        
END_C

package TermC;
use base qw(GO::Model::Term);

sub name {
    my $self = shift;
    @_ ? $self->set_name(shift @_) : $self->get_name;
}

sub description {
    my $self = shift;
    @_ ? $self->set_description(shift @_) : $self->get_description;
}

sub acc {
    my $self = shift;
    @_ ? $self->set_acc(shift @_) : $self->get_acc;
}

sub synonym_list {
    my $self = shift;
    @_ ? $self->set_synonym_list(shift @_) : $self->get_synonym_list;
}


use Inline C => Config =>
  INC => "-I$ENV{GO_ROOT}/c-lib/",
  LIBS => "-lm -lglib -L$ENV{GO_ROOT}/c-lib/ -lGO";  

use Inline C => <<'END_C';

#include <glib.h>
#include <golib.h>

char *get_name(SV* sv) {
    TermOb *term_ob = (TermOb*)SvIV(SvRV(sv));
    return term_ob->node->name;
}
 
AV *get_synonym_list(SV* sv) {
    TermOb *term_ob = (TermOb*)SvIV(SvRV(sv));
    GList *syns = term_ob->node->synonyms;
    AV *av = newAV();
    int i;
    for (i=0; i < g_list_length(syns); i++) {
	av_push(av, newSVpv(g_list_nth(syns, i)->data, 0));
    }
    return av;
}
 

END_C

1;

