# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself


package GO::Model::Term;

=head1 NAME

  GO::Model::Term;

=head1 SYNOPSIS

  my apph = GO::AppHandle->connect(-dbname=>$dbname);
  my $term = $apph->get_term({acc=>00003677});
  printf "Term:%s (%s)\nDefinition:%s\nSynonyms:%s\n",
    $term->name,
    $term->public_acc,
    $term->definition,
    join(", ", @{$term->synonym_list});

=head1 DESCRIPTION

Represents an Ontology term; the same class is used for process,
compartment and function

currently, a Term is not aware of its Relationships; to find out how a
term is related to other terms, use either the GO::AppHandle object or
a GO::Model::Graph object, which will give you the
GO::Model::Relationship objects

=head1 NOTES

Like all the GO::Model::* classes, this uses accessor methods to get
or set the attributes. by using the accessor method without any
arguments gets the value of the attribute. if you pass in an argument,
then the attribuet will be set according to that argument.

for instance

  # this sets the value of the attribute
  $my_object->attribute_name("my value");

  # this gets the value of the attribute
  $my_value = $my_object->attribute_name();

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use GO::Model::Association;
use GO::Model::GeneProduct;
use strict;
use vars qw(@ISA);

use base qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(id type term_type name description is_obsolete public_acc acc definition synonym_list association_list selected_association_list association_hash n_associations dbxref_list property_list stag);
}

sub _valid_types {
    return ('root', 'function', 'process', 'component', 'anatomy');
}

=head2 type

  Usage   - print $term->type();     # getting the type
  Usage   - $term->type("function"); # setting the type
  Returns - string representing type
  Args    - string represnting type [optional]

=cut

sub type {
    my $self = shift;
    my $type = $self->{term_type};
    $self->{term_type} = shift if @_;
#    if (!grep {$self->{type} eq $_} _valid_types) {
#	my $msg;
#	if ($self->{type}) {
#	    $msg = "Type \"$self->{type}\" not valid";
#	}
#	else {
#	    $msg = "Undefined type passed to \"$self->{name}\", $self->{type}";
#	}
#	$self->{type} = $type;
#	warn($msg);
#    }
    return $self->{term_type};
}

# synonyms
sub term_type { shift->type(@_) }
sub category { shift->type(@_) }


=head2 definition

  Usage   - print $term->definition;
  Returns -
  Args    -

accessor: gets/sets "definition" attribute

=cut

sub definition {
    my $self = shift;
    $self->{definition} = shift if @_;
    return $self->{definition};
}

=head2 primary_xref

 Title   : primary_xref
 Usage   :
 Function:
 Example :
 Returns : GO::Model::Xref
 Args    :


=cut

sub primary_xref{
   my ($self,@args) = @_;

   my ($dbname, $acc) = split(/\:/, $self->acc);
   return GO::Model::Xref->new({xref_key=>$acc,
				xref_dbname=>$dbname});
}


=head2 comment

 Title   : comment
 Usage   : $obj->comment($newval)
 Function: 
 Example : 
 Returns : value of comment (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub comment{
    my $self = shift;

    return $self->{'comment'} = shift if @_;
    return $self->{'comment'};
}

=head2 definition_dbxref_list

 Title   : definition_dbxref_list
 Usage   : $obj->definition_dbxref(\@xrefs)
 Function: 
 Example : 
 Returns : definition_dbxref_list hashlist (of GO::Model::Xref)
 Args    : on set, new values (GO::Model::Xref hashlist)


=cut

sub definition_dbxref_list{
    my $self = shift;

    return $self->{'definition_dbxref_list'} = shift if @_;
    return $self->{'definition_dbxref_list'};
}


=head2 add_definition_dbxref

  - Usage : $term->add_definition_dbxref($xref);
  - Args  : GO::Term::Xref
  

=cut

sub add_definition_dbxref {
    my $self = shift;

    foreach my $dbxref (@_) {
        if (!ref($dbxref)) {
            my ($db, @rest) = split(/:/, $dbxref);
            confess "$dbxref not a dbxref" unless @rest;
            my $acc = join(":", @rest);
            $dbxref = $self->apph->create_xref_obj({xref_key=>$acc,
                                                    xref_dbname=>$db});
        }
        UNIVERSAL::isa($dbxref, "GO::Model::Xref") or confess($dbxref." not a xref");
        $self->definition_dbxref_list([]) unless $self->definition_dbxref_list;
        push(@{$self->definition_dbxref_list}, $dbxref);

    }
    $self->definition_dbxref_list;
}



=head2 name

  Usage   - print $term->name;
  Returns -
  Args    -

accessor: gets/sets "name" attribute

=cut

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    my $name = $self->{name};
    if ($name) {
# preserver underscores
#	$name =~ s/_/ /g;
    }
    return $name;
}


=head2 description

this is just a synonym for name

=cut

sub description {
    my $self = shift;
    $self->name(@_);
}




=head2 acc

  Usage   - print $term->acc()
  Returns -
  Args    -

accessor: gets/sets GO ID/accession [as an integer]

throws: exception if you try to pass in a non-integer

if you want to use IDs in the format GO:0000nnn, then use the method
public_acc()

=cut

sub acc {
    my $self = shift;
    if (@_) {
	my $acc = shift;
	$self->{acc} = $acc;
    }
    return $self->{acc};
}

*public_acc = \&acc;

sub lisp_acc {
    my $self = shift;
    return 
      sprintf "Go%07d", $self->acc;
}



=head2 has_synonym

  Usage   - if ($term->has_synonym("autotrophy") {...}
  Returns - bool
  Args    - string

=cut

sub has_synonym {
    my $self = shift;
    my $str = shift;
    my @syns = @{$self->synonym_list || []};
    if (grep {$_ eq $str} @syns) {
        return 1;
    }
    return 0;
}

*add_secondaryid = \&add_synonym;

=head2 add_synonym

  Usage   - $term->add_synonym("calcineurin");
  Returns -
  Args    -

=cut

sub add_synonym {
    my $self = shift;
    my $syns = $self->synonym_list || [];
    if (@_) {
	my $syn = shift;
        if ($syn) {
            if ( ! grep {$syn eq $_} @{$self->{synonym_list}} ) {
                push (@{$self->{synonym_list}}, $syn);
            }
        }
    }
    return $self->{synonym_list};
}




=head2 synonym_list

  Usage   - my $syn_l = $term->synonym_list;
  Usage   - $term->synonym_list([$syn1, $syn2]);
  Returns - arrayref
  Args    - arrayref [optional]

accessor: gets/set list of synonyms [array reference]

=cut

sub synonym_list {
    my $self = shift;
    $self->{synonym_list} = shift if @_;
    return $self->{synonym_list};
}

=head2 add_obsolete

=cut

sub add_obsolete {
    my $self = shift;
    if (@_) {
	my $obs = shift;
	$self->{obsolete_h}->{$obs->acc} = $obs;
    }
    return $self->obsolete_list;
}


=head2 obsolete_list

accessor: gets/set list of obsolete terms [array reference]

=cut

sub obsolete_list {
    my $self = shift;
    while (shift @_) {
	$self->add_obsolete ($_);
    }
    my @obs = values %{$self->{obsolete_h}};
    return \@obs;
}

*add_xref = \&add_dbxref;

=head2 add_dbxref

  - Usage : $term->add_dbxref($xref);
  - Args  : GO::Term::Xref
  

=cut

sub add_dbxref {
    my $self = shift;

    foreach my $dbxref (@_) {
        if (!ref($dbxref)) {
            my ($db, @rest) = split(/:/, $dbxref);
            confess "$dbxref not a dbxref" unless @rest;
            my $acc = join(":", @rest);
            $dbxref = $self->apph->create_xref_obj({xref_key=>$acc,
                                                    xref_dbname=>$db});
        }
        UNIVERSAL::isa($dbxref, "GO::Model::Xref") or confess($dbxref." not a xref");
        $self->dbxref_list([]) unless $self->dbxref_list;
        push(@{$self->dbxref_list}, $dbxref);

    }
    $self->dbxref_list;
}


=head2 dbxref_list

  - Usage : $term->dbxref_list($xref);
  - Args  : optional listref of GO::Term::Xref
  - Returns  : listref of GO::Term::Xref
  

accessor: gets/sets list of dbxref [array reference]

=cut

# autodefined

=head2 is_obsolete

accessor: gets/set obsolete flag [boolean

=cut

sub is_obsolete {
    my $self = shift;
    $self->{is_obsolete} = shift if @_;
    return $self->{is_obsolete} ? 1:0;
}

=head2 is_root

accessor: gets/set is_root flag [boolean]

=cut

sub is_root {
    my $self = shift;
    $self->{is_root} = shift if @_;
    return $self->{is_root} ? 1:0;
}


=head2 association_list

  Usage   - $assoc_l = $term->association_list
  Returns - arrayref of GO::Model::Association
  Args    - arrayref of GO::Model::Association [optional]

accessor: gets/set list of associations [array reference]

if this is undefined, the datasource will be queried
for the associations

=cut

sub association_list {
    my $self = shift;
    my ($al, $sort_by) = 
      rearrange([qw(associations sort_by)], @_);
    if ($al) {
	if (!ref($al) eq "ARRAY") {
	    confess("$al is not an array ref");
	}
	$self->{"association_list"} = $al;
	foreach my $assoc (@{$self->{"association_list"} || []}) {
	    my $gene = $assoc->gene_product;
	    $self->{association_hash}->{$gene->acc} = $assoc;
	}
    }
    if (!defined($self->{"association_list"})) {
	if (!defined($self->apph)) {
#	    print $self->dump;
	}
	else {
	    $self->{"association_list"} =
	      $self->apph->get_direct_associations($self);
	    foreach my $assoc (@{$self->{"association_list"} || []}) {
		my $gene = $assoc->gene_product;
                if (!$self->{association_hash}->{$gene->acc}) {
                    $self->{association_hash}->{$gene->acc} = [];  
                }
		push(@{$self->{association_hash}->{$gene->acc}}, $assoc);
	    }
	}
    }
    if ($sort_by &&
        (!$self->{"association_list_sort_by"} ||
         $self->{"association_list_sort_by"} ne $sort_by)) {
        my @sortlist = ref($sort_by) ? @$sort_by : ($sort_by);
        my @al = 
          sort {
              my $as1 = $a;
              my $as2 = $b;
              my $i=0;
              my $cmp;
              while (!defined($cmp) && 
                     $i < @sortlist) {
                  my $sortk = $sortlist[$i];
                  $i++;
                  if ($sortk eq "gene_product") {
                      $cmp = 
                        $as1->gene_product->symbol cmp
                        $as2->gene_product->symbol;
                  }
                  elsif ($sortk eq "ev_code") {
                      confess("cant sort on evcode yet");
                  }
                  else {
                      confess("dont know $sortk");
                  }
              }
              $cmp;
          } @{$self->{association_list} || []};
        $self->{"association_list"} = \@al;
        $self->{"association_list_sort_by"} = $sort_by;
    }
    return $self->{"association_list"};
}



=head2 selected_association_list

  Usage   - $assoc_l = $term->selected_association_list
  Returns - arrayref of GO::Model::Association
  Args    - arrayref of GO::Model::Association [optional]

accessor: gets list of SELECTED associations [array reference]

this in not the total list of all associations associated with a term;
if the term was created via a query on products, this will include
those associations

=cut

# done by AUTOLOAD

=head2 add_association

  Usage   - $term->add_association($assoc);
  Returns - 
  Args    - GO::Model::Association

=cut

sub add_association {
    my $self = shift;
    if (!$self->{"association_list"}) {
	$self->{"association_list"} = [];
    }
    my $assoc = shift;
    if (ref($assoc) ne "GO::Model::Association") {
	# it's a hashref - create obj from hashref
	my $assoc2 = $self->apph->create_association_obj($assoc);
	$assoc = $assoc2;
    }
    push(@{$self->{"association_list"}}, ($assoc));
    my $gene = $assoc->gene_product;
    if (!$self->{association_hash}->{$gene->acc}) {
        $self->{association_hash}->{$gene->acc} = [];  
    }
    push(@{$self->{association_hash}->{$gene->acc}}, $assoc);
    return $self->{"association_list"};
}


=head2 add_selected_association

  Usage   -
  Returns -
  Args    -

=cut

sub add_selected_association {
    my $self = shift;
    my $assoc = shift;
    $assoc->isa("GO::Model::Association") || confess;
    if (!$self->{"selected_association_list"}) {
	$self->{"selected_association_list"} = [];
    }
    push(@{$self->{"selected_association_list"}}, $assoc);
}

=head2 association_hash

returns associations as listref of unique GeneProduct objects

=cut

sub association_hash {
    my $self = shift;
    if (!defined($self->{"association_list"})) {
        $self->association_list;
    }
    $self->{"association_hash"} = shift if @_;
    return $self->{"association_hash"};
}

=head2 n_associations

  Usage   - my $al = $term->get_all_associations
  Returns - GO::Model::Association list
  Args    -

returns all associations for the term and the terms beneath it in the GO DAG

same as $apph->get_all_associations($term)

=cut

sub get_all_associations {
    my $self = shift;
    $self->apph->get_all_associations($self);
}

=head2 n_associations

  Usage   - my $n = $term->n_associations
  Returns -
  Args    -

=cut

sub n_associations {
    my $self = shift;
    if (!@{$self->{"association_list"} || []}) {

	# association count can be get/set even if the actual
	# list is not present
	$self->{n_associations} = shift if @_;
    }
    if (!defined($self->{n_associations}) &&
        $self->{association_list}) {

        # we have already loaded the
        # association list
	$self->{n_associations} =
	  scalar(@{$self->association_list || []});
    }
    if (!defined($self->{n_associations})) {
	$self->{n_associations} =
          $self->apph->get_association_count($self);
    }
    return $self->{n_associations};
}


=head2 product_list

  Usage   -
  Returns - GO::Model::GeneProduct listref
  Args    -

Returns a reference to an array of gene products that are attached
directly to this term.

(if the products have not been fetched, this method will call
$term->association_list, cache the results, and use the associations
to build the product list. succeeding calls of product_list to this
term will hence be faster)

=cut

sub product_list {
    my $self = shift;
    my $assocs = $self->association_list;
    my @prods = ();
    my %ph = ();
    foreach my $assoc (@$assocs) {
        my $gp = $assoc->gene_product;
        if (!$ph{$gp->id}) {
            push(@prods, $gp);
            $ph{$gp->id} = 1;
        }
    }
    return [@prods];
}


=head2 deep_product_list

  Usage   -
  Returns - GO::Model::GeneProduct listref
  Args    -

finds all products attached to this term and all terms below in the
graph

=cut

sub deep_product_list {
    my $self = shift;
    my $prods = 
      $self->apph->get_products({deep=>1, term=>$self});
    return $prods;
}


=head2 n_deep_products

  Usage   - my $count = $term->n_deep_products;
  Returns - int
  Args    - filter (hashref) - or string "recount"

gets the count for the *dsitinct* number of GO::Model::GeneProduct
entries annotated at OR BELOW this level. if you have set the filters
in GO::AppHandle then these filters will be used in determining the
count.

Remember, if you did not explicitly set the filters, then the
default filter will be used, which is [!IEA] (i.e. curated
associations only, see www.geneontology.org for a discussion of
evidence codes).

Note: currently only the speciesdb filter is respected. It turns out
to be very expensive to do the set arithmetic for distinct recursive
gene counts with different evidence combinations. Because each product
belongs to one speciesdb only, the speciesdb counts are mutually
exclusive, which makes this easier.

  # get the number of gene products that have been annotated
  # as transcription factors in worm and fly discounting
  # uncurated automatic annotations
  $apph->filters({evcodes=>["!IEA"], speciesdbs=>["SGD", "FB"]});
  $term = $apph->get_term({name=>"transcription factor"});
  print $term->n_deep_products;

The count will be cached, so if you alter the filter parameters be sure
to get a recount like this:

  my $count = $term->n_deep_products("recount");

TODO: make the recount automatic if the filter is changed

PERFORMANCE NOTE 1: When you ask the AppHandle to give you a list of
GO::Model::Term objects, it may decide to populate this attribute when
building the terms in a fast and efficient way. Therefore you should
avoid setting the filters *after* you have created the objects
otherwise it will have to refetch all these values slowing things
down.

PERFORMANCE NOTE 2: If you are using the SQL GO::AppHandle
implementation, then this call will probably involve a query to the
*gene_produc_count* table. If you populated the database you are using
yourself, make sure this table is filled otherwise this will be an
expensive query.


=cut

sub n_deep_products {
    my $self = shift;
    $self->{n_deep_products} = shift if @_;
    if (!defined($self->{n_deep_products}) ||
        $self->{n_deep_products} eq "recount") {
        $self->{n_deep_products} = 
          $self->apph->get_deep_product_count({term=>$self});
    }
    else {
    }
    return $self->{n_deep_products};
}


=head2 n_products

  Usage   - as n_deep_products
  Returns -
  Args    -

see docs for n_deep_products

gets a count of products AT THIS LEVEL ONLY

=cut

sub n_products {
    my $self = shift;
    $self->{n_products} = shift if @_;
    if (!defined($self->{n_products}) ||
        $self->{n_products} eq "recount") {
        $self->{n_products} = 
          $self->apph->get_product_count({term=>$self});
    }
    return $self->{n_products};
}

sub n_unique_associations {
    my $self = shift;
    return scalar(keys %{$self->association_hash || {}});
}

sub get_child_terms {
    my $self = shift;
    return $self->apph->get_child_terms($self, @_);
}

sub get_parent_terms {
    my $self = shift;
    return $self->apph->get_parent_terms($self, @_);
}

=head2 loadtime

 Title   : loadtime
 Usage   :
 Function:
 Example :
 Returns : time term was loaded into datasource
 Args    : none


=cut

sub loadtime{
    my ($self) = @_;
    return $self->apph->get_term_loadtime($self->acc);
}


sub show {
    my $self = shift;
    print $self->as_str;
}

sub as_str {
    my $self = shift;
    sprintf("%s (%s)", $self->name, $self->public_acc);
}

sub to_idl_struct {
    my $self = shift;
    my $template = shift;
    my $struct =
      {
       "description"=>$self->description,
       "public_acc"=>$self->public_acc,
       "association_list"=>[],
       "definition"=>$self->definition,
       "synonym_list"=>$self->synonym_list || [],
       "n_associations"=>$self->n_associations,
      };
    if (!$template || @{$template->{"association_list"} || []}) {
	$struct->{"association_list"} =
	  [map {$_->to_idl_struct} @{$self->association_list || []}],
    }
    if ($ENV{GO_DEBUG} && $ENV{GO_DEBUG} > 5) {
	print $self->dump($struct);
	print "TEMPLATE=$template\n";
    }
    return $struct;
}

sub from_idl {
    my $class = shift;
    my $h = shift;
    my $apph = shift;
    my @assocs =
      map {
	  GO::Model::Association->from_idl($_);
      } @{$h->{"association_list"}};
    delete $h->{"association_list"};
    my $term = $class->new($h);
    map {
	$term->add_association($_);
    } @assocs;
    if ($ENV{GO_DEBUG} > 5) {
	print $term->dump;
    }
    $term->apph($apph);
    return $term;
}

# --- EXPERIMENTAL METHOD ---
# not yet public
sub namerule {
    my $self = shift;
    $self->{_namerule} = shift if @_;
    return $self->{_namerule};
}

sub defrule {
    my $self = shift;
    $self->{_defrule} = shift if @_;
    return $self->{_defrule};
}

# --- EXPERIMENTAL METHOD ---
# not yet public
sub stag {
    my $self = shift;
    $self->{_stag} = shift if @_;
    if (!$self->{_stag}) {
        require "Data/Stag.pm";
        $self->{_stag} = Data::Stag->new(stag=>[]);
    }
    return $self->{_stag};
}



# pseudo-private method
# available to query classes;
# a template is a specification from a client to a query server
# showing how much data should be transferred across.
# the template is an instance of the object that is being returned;
# there are a few premade templates available; eg shallow
sub get_template {
    my $class = shift;
    my $template = shift || {};
    if ($template eq "shallow") {
	# shallow template, just get term attributes, no other
	# structs
	$template = GO::Model::Term->new({"name"=>"",
					  "acc"=>-1,
					  "definition"=>"",
					  "n_associations"=>0,
					  "synonym_list"=>[],
					  "dbxref_list"=>undef});
    }
    if ($template =~ /no.*assoc/) {
        # everything bar associations
	$template = GO::Model::Term->new({"name"=>"",
					  "acc"=>-1,
					  "definition"=>1,
					  "n_associations"=>0,
					  "synonym_list"=>[]});
        $template->{dbxref_h} = 1;
    }
    if ($template eq "all") {
        # everything
	$template = GO::Model::Term->new({"name"=>"",
					  "acc"=>-1,
					  "definition"=>1,
					  "association_list"=>[],
					  "synonym_list"=>[]});
        $template->{dbxref_h} = 1;
    }
    return $template;
}

sub to_text {
    my $self = shift;
    my ($prefix, $escape, $obs_l, $suppress) =
      rearrange([qw(prefix escape obs suppress)], @_);
    my @syns = @{$self->synonym_list || [] };
    my @xrefs = @{$self->dbxref_list || [] };
    if ($suppress) {
	if (!ref($suppress)) {
	    $suppress = {$suppress => 1};
	}
	@xrefs =
	  grep {!$suppress->{$_->xref_dbname}} @xrefs;
    }
    else {
	@xrefs =
	  grep {$_->xref_dbname eq 'EC'} @xrefs;
    }
    my $sub = 
      sub { @_ };
    if ($escape) {
        $sub =
          sub {map{s/\,/\\\,/g;$_}@_};
    }
    my $text = 
      sprintf("%s%s ; %s%s%s%s",
              &$sub($prefix || ""),
              &$sub($self->name),
              $self->public_acc,
              (($obs_l && @$obs_l) ?
               join ("", map {", ".$_->public_acc } @$obs_l ) : ""
              ),
              ((@xrefs) ?
               join("", map {&$sub(" ; ".$_->as_str)} @xrefs ):""
              ),
              ((@syns) ?
               join("", map {&$sub(" ; synonym:$_")} @syns ):""
              ),
             );
    return $text;
}

sub to_ptuples {
    my $self = shift;
    my ($th, $include, $sort) =
      rearrange([qw(tuples include sort)], @_);
    my @s = ();
    push(@s,
         ["term",
          $self->acc,
          $self->name,
          ]);
    foreach my $x (@{$self->dbxref_list || []}) {
        push(@s, $x->to_ptuples(-tuples=>$th));
        push(@s, ["term_dbxref",
                  $self->acc,
                  $x->as_str]);
    }
    @s;
}

# **** EXPERIMENTAL CODE ****
# the idea is to be homogeneous and use graphs for
# everything; eg gene products are nodes in a graph,
# associations are arcs
# cf rdf, daml+oil etc

# args - optional graph to add to
sub graphify {
    my $self = shift;
    my ($subg, $opts) =
      rearrange([qw(graph opts)], @_);

    $opts = {} unless $opts;
    $subg = $self->apph->create_graph_obj unless $subg;
    $subg->add_node($self) unless $opts->{noself};

    foreach my $syn (@{$self->synonym_list || []}) {
        my $t =
          $self->apph->create_term_obj({name=>$syn,
                                        acc=>$syn});
        $subg->add_node($t);
        $subg->add_arc($t, $self, "hasSynonym");
    }
    foreach my $xref (@{$self->dbxref_list || []}) {
        my $t =
          $self->apph->create_term_obj({name=>$xref->as_str,
                                        acc=>$xref->as_str});
        $subg->add_node($t);
        $subg->add_arc($t, $self, "hasXref");
    }
    foreach my $assoc (@{$self->association_list || []}) {
        $assoc->graphify($self, $subg);
    }
    $subg;
}

1;
