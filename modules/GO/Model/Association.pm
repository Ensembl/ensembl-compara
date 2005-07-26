# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::Association;

=head1 NAME

  GO::Model::Association;

=head1 SYNOPSIS

  # print all gene products associated with a GO::Model::Term
  my $assoc_l = $term->association_list;
  foreach my $assoc (@$assoc_l) {
    printf "gene product:%s %s %s (evidence: %s)\n",
      $assoc->gene_product->symbol,
      $assoc->is_not ? "IS NOT" : "IS",
      $term->name,
      map {$_->code} @{$assoc->evidence_list};
  }

=head1 DESCRIPTION

Represents an association between a GO term (GO::Model::Term) and a
gene product (GO::Model::GeneProduct)

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use GO::Model::Evidence;
use strict;
use vars qw(@ISA);

use base qw(GO::Model::Root Exporter);


sub _valid_params {
    return qw(id gene_product evidence_list is_not role_group);
}


sub _initialize 
{
    my $self = shift;
    my $paramh = shift;

    # an association is a compound obj of both Association and
    # GeneProduct; both objs created together from same hash

    # sometimes this is from the external world and sometimes from the db
    my $product_h = {};
    my $ev_h = {};
    if (defined ($paramh->{gene_product_id})) {
	$product_h->{speciesdb} = $paramh->{xref_dbname};
	$product_h->{acc} = $paramh->{xref_key};
	$product_h->{id} = $paramh->{gene_product_id};
	$product_h->{symbol} = $paramh->{symbol};
	$product_h->{full_name} = $paramh->{full_name} 
	if defined ($paramh->{full_name});
    
        if (!$self->apph) {
            confess("ASSERTION ERROR");
        }
	my $product = $self->apph->create_gene_product_obj($product_h);
	$product->{species_id} = $paramh->{species_id};

	$self->gene_product($product);

	delete $paramh->{xref_dbname};
	delete $paramh->{xref_key};
	delete $paramh->{gene_product_id};
	delete $paramh->{symbol};
	delete $paramh->{full_name};
	delete $paramh->{species_id};
    
    }

    $self->SUPER::_initialize($paramh);
}



=head2 go_public_acc

  Usage   -
  Returns -
  Args    -

=cut

sub go_public_acc {
    my $self = shift;
    $self->{go_public_acc} = shift if @_;
    return $self->{go_public_acc};
}



=head2 add_evidence

  Usage   - $assoc->add_evidence($my_evid);
  Returns -
  Args    - GO::Model::Evidence

=cut

sub add_evidence {
    my $self = shift;
    if (!$self->{evidence_list}) {
	$self->{evidence_list} = [];
    }
    push(@{$self->{evidence_list}}, (shift));
    return $self->{evidence_list};
}


=head2 evidence_list

  Usage   - my $ev_l = $assoc->evidence_list;
  Returns -
  Args    -

gets/sets arrayref of GO::Model::Evidence

=cut

sub evidence_list {
    my $self = shift;
    $self->{evidence_list} = shift if @_;
    return $self->{evidence_list};
}


=head2 evidence_as_str

  Usage   - print $assoc->evidence_as_str
  Usage   - print $assoc->evidence_as_str(1); #verbose
  Returns -
  Args    - verbose

concatenates evcodes together, for display

=cut

sub evidence_as_str {
    my $self = shift;
    my $v = shift;
    if ($v) {
        return 
          join("; ", 
               map {
                   sprintf("%s %s %s",
                           $_->code,
                           $_->seq_acc ? $_->seq_acc->as_str : "",
                           $_->xref ? $_->xref->as_str : "")
               } @{$self->evidence_list || []});
    }
    else {
        return join("; ", map {$_->code} @{$self->evidence_list || []});
    }
}

=head2 has_evcode

  Usage   - if $assoc->has_evcode("IEA");
  Returns - boolean
  Args    - evcode [string]

=cut

sub has_evcode {
    my $self = shift;
    my $code = shift;
    return grep {$_->code eq $code} @{$self->evidence_list || []};
}

=head2 remove_evcode

  Usage   - $assoc->remove_evcode("IEA");
  Returns - 
  Args    - evcode [string]

removes all evidence of the specified type from the
association; useful for filtering

=cut

sub remove_evcode {
    my $self = shift;
    my $code = shift;
    my @ok_ev =
      grep {$_->code ne $code} @{$self->evidence_list || []};
    $self->evidence_list(\@ok_ev);
}


=head2 evidence_score

  Usage   - my $score = $assoc->evidence_score
  Returns - 0 <= float <= 1
  Args    -

returns a score for the association based on the evidence;

This is an EXPERIMENTAL method; it may be removed in future versions.

The evidence fields can be thought of in a loose hierachy: 

TAS
   IDA
      IMP/IGI/IPI
                 ISS
                    NAS

see http://www.geneontology.org/GO.evidence.html

=cut

sub evidence_score {
    my $self = shift;
    my %probs = qw(IEA 0.1
		   NAS 0.3
		   NR  0.3
		   ISS 0.4
		   IMP 0.6
		   IGI 0.6
		   IPI 0.6
		   IDA 0.8
		   TAS 0.9);
    my $np = 1;
    map {$np *= (1 - $probs{$_}) } @{$self->evcodes||[]};
    return 1 - $np;
}

=head2 gene_product

  Usage   - my $gp = $assoc->gene_product
  Returns -
  Args    -

gets sets GO::Model::GeneProduct

=cut

sub gene_product {
    my $self = shift;
    $self->{gene_product} = shift if @_;
    return $self->{gene_product};
}


=head2 is_not

  Usage   -
  Returns -
  Args    -

gets/sets boolean representing whether this relationship is negated

=cut

sub is_not {
    my $self = shift;
    $self->{is_not} = shift if @_;
    return $self->{is_not};
}

=head2 role_group

  Usage   -
  Returns -
  Args    -

gets/sets integer to indicate which associations go together

=cut

sub role_group {
    my $self = shift;
    $self->{role_group} = shift if @_;
    return $self->{role_group};
}

sub from_idl {
    my $class = shift;
    my $h = shift;
    map {
	$_ = GO::Model::Evidence->from_idl($_);
    } @{$h->{"evidence_list"}};
    $h->{"gene_product"} = 
      GO::Model::GeneProduct->from_idl($h->{"gene_product"});
    return $class->new($h);
}

sub to_idl_struct {
    my $self = shift;
    my $struct;
    eval {
	$struct =
	  {
	   "evidence_list"=>[map {$_->to_idl_struct} @{$self->evidence_list()}],
	   "gene_product"=>$self->gene_product->to_idl_struct,
	   "reference"=>""
	  };
    };
    if ($@) {
	print $self->dump;
	print $@;
	throw POA_GO::ProcessError();
    }
    return $struct;
}

sub to_ptuples {
    my $self = shift;
    my ($term, $th) =
      rearrange([qw(term tuples)], @_);
    my @s = ();
    foreach my $e (@{$self->evidence_list()}) {
        my @xids = ();
        foreach my $x (@{$e->xref_list || []}) {
            push(@s,
                 $x->to_ptuples(-tuples=>$th)
                );
            push(@xids, $x->as_str);
        }
        push(@s,
             ["assoc",
              $term->acc,
              $self->gene_product->xref->as_str,
              $e->code,
              "[".join(", ", @xids)."]",
             ],
             $self->gene_product->to_ptuples(-tuples=>$th),
            );
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
    my ($term, $subg, $opts) =
      rearrange([qw(term graph opts)], @_);

    $opts = {} unless $opts;
    $subg = $self->apph->create_graph_obj unless $subg;

    my $acc = sprintf("%s", $self);
    my $t =
      $self->apph->create_term_obj({name=>$acc,
                                    acc=>$acc});
    $subg->add_node($t);
    $subg->add_arc($t, $term, "hasAssociation") if $term;

    foreach my $ev (@{$self->evidence_list || []}) {
        $ev->apph($self->apph);
        $ev->graphify($t, $subg);
    }
    my $gp = $self->gene_product;
    $gp->graphify($t, $subg);

    $subg;
}

1;
