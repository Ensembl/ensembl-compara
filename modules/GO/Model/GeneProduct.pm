# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::Model::GeneProduct;

=head1 NAME

  GO::Model::GeneProduct;

=head1 DESCRIPTION

represents a gene product in a particular species (this will
effectively always be refered to implicitly by the gene symbol even
though a gene may have >1 product)

=cut


use Carp;
use Exporter;
use GO::Utils qw(rearrange);
use GO::Model::Root;
use strict;
use vars qw(@ISA);

@ISA = qw(GO::Model::Root Exporter);

sub _valid_params {
    return qw(id acc symbol full_name xref speciesdb synonym_list seq_list species);
}

sub _initialize 
{
    my $self = shift;
    my $paramh = shift;

    my $db;
    if ($paramh->{speciesdb}) {
	($db = $paramh->{speciesdb}) =~ tr/A-Z/a-z/;
    }
    else {
	$db = $paramh->{xref_dbname};
    }

    my $xref = 
      GO::Model::Xref->new({xref_key=>$paramh->{acc},
			    xref_keytype=>"acc",
                            xref_dbname=>$db});

    $self->xref($xref);
    delete $paramh->{acc};
    delete $paramh->{speciesdb};

    $self->SUPER::_initialize($paramh);
}

=head2 acc

  Usage   -
  Returns -
  Args    -

=cut

sub acc {
    my $self = shift;
    my $acc = shift;
    if ($acc) {
	$self->xref->xref_key($acc);
    }
    return $self->xref->xref_key;
}


=head2 symbol

  Usage   -
  Returns -
  Args    -

=cut

sub symbol {
    my $self = shift;
    $self->{symbol} = shift if @_;
    return $self->{symbol};
}


=head2 full_name

  Usage   -
  Returns -
  Args    -

=cut

sub full_name {
    my $self = shift;
    $self->{full_name} = shift if @_;
    return $self->{full_name};
}


=head2 as_str

  Usage   -
  Returns -
  Args    -

=cut

sub as_str {
    my $self = shift;
    return "GP-".$self->xref->as_str;
}

=head2 add_synonym

=cut

sub add_synonym {
    my $self = shift;
    if (!$self->{synonym_list}) {
	$self->{synonym_list} = [];
    }
    push(@{$self->{synonym_list}}, (shift));
    return $self->{synonym_list};
}


=head2 synonym_list

accessor: gets/set list of synonyms [array reference]

=cut

sub synonym_list {
    my $self = shift;
    $self->{synonym_list} = shift if @_;
    return $self->{synonym_list};
}

=head2 speciesdb

  Usage   -
  Returns -
  Args    -

=cut

sub speciesdb {
    my $self = shift;
    my $db = shift;
    if ($db) {
	$self->xref->xref_dbname ($db);
    }
    return $self->xref->xref_dbname;
}


=head2 add_seq

  Usage   -
  Returns -
  Args    - GO::Model::Seq

=cut

sub add_seq {
    my $self = shift;
    my $seq = shift;
    
    if ($seq->isa("Bio::SeqI")) {
        my $bpseq = $seq;
        $seq = GO::Model::Seq->new;
        $seq->pseq($bpseq);
    }
    $seq->isa("GO::Model::Seq") or confess ("Not a seq object");
    $self->{seq_list} = [] unless $self->{seq_list};

    push(@{$self->{seq_list}}, $seq);
    $self->{seq_list};
}

=head2 seq_list

  Usage   -
  Returns - GO::Model::Seq listref
  Args    -

=cut

sub seq_list {
    my $self = shift;
    if (@_) {
        $self->{seq_list} = shift;
    }
    else {
        if (!defined($self->{seq_list})) {
            $self->{seq_list} =
              $self->apph->get_seqs({product=>$self});
        }
    }
    return $self->{seq_list};
}


=head2 seq

  Usage   -
  Returns - GO::Model::Seq
  Args    -

returns representative sequence object for this product

=cut

sub seq {
    my $self = shift;
    my $seqs = $self->seq_list;
    my $str = "";
    # longest by default
    my $longest;
    
    foreach my $seq (@$seqs) {
        if (!defined($longest) || $seq->length > $longest->length) {
            $longest = $seq;
        }
    }
    return $longest;
}

=head2 properties

  Usage   -
  Returns - hashref
  Args    - hashref

=cut

sub properties {
    my $self = shift;
    $self->{_properties} = shift if @_;
    return $self->{_properties};
}


=head2 set_property

  Usage   - $sf->set_property("wibble", "on");
  Returns -
  Args    - property key, property scalar

note: the property is assumed to be multivalued, therefore
  $sf->set_property($k, $scalar) will add to the array, and
  $sf->set_property($k, $arrayref) will set the array

=cut

sub set_property {
    my $self = shift;
    my $p = shift;
    my $v = shift;
    if (!$self->properties) {
        $self->properties({});
    }
    if (ref($v)) {
        confess("@$v is not all scalar") if grep {ref($_)} @$v;
        $self->properties->{$p} = $v;
    }
    else {
        push(@{$self->properties->{$p}}, $v);
    }
    $v;
}

=head2 get_property

  Usage   -
  Returns - first element of the property
  Args    - property key

=cut

sub get_property {
    my $self = shift;
    my $p = shift;
    if (!$self->properties) {
        $self->properties({});
    }
    my $val = $self->properties->{$p};
    if ($val) {
        $val = $val->[0];
    }
    return $val;
}

=head2 get_property_list

  Usage   -
  Returns - the property arrayref
  Args    - property key

=cut

sub get_property_list {
    my $self = shift;
    my $p = shift;
    if (!$self->properties) {
        $self->properties({});
    }
    self->properties->{$p};
}


=head2 to_fasta

  Usage   -
  Returns -
  Args    -

returns the longest seq by default

=cut

sub to_fasta {
    my $self = shift;
    my ($fullhdr, $hdrinfo, $gethdr) = 
      rearrange([qw(fullheader headerinfo getheader)], @_);
    $hdrinfo = " " . ($hdrinfo || "");
    my $seqs = $self->seq_list;
    my $str = "";
    # longest by default
    my $longest;
    
    return "" unless @$seqs;

    foreach my $seq (@$seqs) {
        if (!defined($longest) || $seq->length > $longest->length) {
            $longest = $seq;
        } 
    }
    $seqs = [$longest];
    if ($gethdr) {
      my $apph = $self->get_apph;
      my $terms = $apph->get_terms({product=>$self});
      my @h_elts = ();
      foreach my $term (@$terms) {
	my $al = $term->selected_association_list;
	my %codes = ();
	map { $codes{$_->code} = 1 } map { @{$_->evidence_list} } @$al;
	push(@h_elts,
	     sprintf("%s evidence=%s",
		     $term->public_acc,
		     join(";", keys %codes),
		    )
	    );
      }
      $hdrinfo = join(", ", @h_elts);
    }
    foreach my $seq (@$seqs) {
        my $desc;
        if ($fullhdr) {
            $desc = $fullhdr;
        }
        else {
            $desc =
              sprintf("%s|%s symbol:%s%s %s",
                      uc($self->xref->xref_dbname),
                      $self->xref->xref_key,
                      $self->symbol,
                      $hdrinfo,
                      join(" ",
                           map {$_->as_str} @{$seq->xref_list})
                     );
        }
        $seq->description($desc);
        $str.= $seq->to_fasta;
    }
    return $str;
}

sub to_idl_struct {
    my $self = shift;
    return 
      {
	  "symbol"=>$self->symbol,
	  "full_name"=>$self->full_name,
	  "acc"=>$self->xref->xref_key,
	  "speciesdb"=>$self->xref->xref_dbname,
      };
}

sub to_ptuples {
    my $self = shift;
    my ($th) =
      rearrange([qw(tuples)], @_);
    my @s = ();
    push(@s,
         ["product",
          $self->xref->as_str,
          $self->symbol,
          $self->full_name,
          ]);
    push(@s, $self->xref->to_ptuples(-tuples=>$th));
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
    my ($ref, $subg, $opts) =
      rearrange([qw(ref graph opts)], @_);

    $opts = {} unless $opts;
    $subg = $self->apph->create_graph_obj unless $subg;

    my $t =
      $self->apph->create_term_obj({name=>$self->as_str,
                                    acc=>$self->as_str});
    $subg->add_node($t);
    $subg->add_arc($t, $ref, "hasProduct");
    return $subg;
}

1;
