# $Id$
#
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::LogicEngine     - 

=head1 SYNOPSIS

  use GO::LogicEngine;
  my $engine = new GO::LogicEngine;
  $engine->ontology($ont);
  $engine->generate_cross_products;

=cut

=head1 DESCRIPTION

implements logical rules necessary for generation of cross-products, etc

=head2 INSTANCES AND PROPERTIES

a simple class definition

  (C ?class)

classes can have subclasses

  (SC ?class ?superclass)

subclasses is recursive

  (=> (and (SC ?x ?z (SC ?z ?y)))
      (SC ?x ?y))

instances belong to classes

  (I ?inst ?class)

an instance of a class is also an instance of all superclasses

  (=> (and (I ?inst ?class) (SC ?class ?superclass))
      (I ?inst ?superclass))

classes can have properties; the class is the domain (D) of the property

 (P ?class ?property)

properties are inherited

  (=> (and (P ?class ?property) (SC ?subclass ?class))
      (P ?subclass ?property))

properties can have ranges (the set of values that instances can take on)

 (PR ?property ?class)

these are inherited

  (=> (and (PR ?property ?class) (SC ?subclass ?class))
      (PR ?property ?subclass))

instances can take on property-values

 (PV ?inst ?property ?value)

instance values are constrained by PR and P definitions

  (=> (PV ?inst ?property ?value)
      (and (I ?inst ?class)
           (P ?class ?property)
           (PR ?property ?value)))

=head2 CROSS PRODUCTS

A cross product is a combination of (orthogonal) concepts. Here we
define this as being a pairwise combination (if it is desirable to
combine >2 concepts, this can be done recursively). A cross product is
composed of a stem class, and a restriction on a property value to a
specific range-class

  (XP ?xp ?class ?property ?range-class)

This is equivalent to the logical intersection of the stem class and
an anonymous existential restriction

  (=>
      (XP ?xp ?class ?property ?range-class)
      (== ?xp
          (INTERSECTION ?class (RESTRICTION ?property ?range-class))))

From this it follows that an instance of an XP is equivalent to an
instance of the stem class with a value that comes from the
range-class

 (<=> (and (I ?inst ?xp)
           (XP ?xp ?class ?property ?range-class))
      (and (I ?inst ?class)
           (PV ?inst ?property ?value)
           (I ?value ?range-class)))

=head2 GENERATING CROSS-PRODUCTS

cross-products can be automatically generated from properties

  (=> (and
          (P ?class ?property)
          (PR ?property ?range-class)
      )
      (exists
          (XP ?xp ?class ?property ?range-class)))

=head2 EXPANDING CROSS PRODUCTS

a cross-product implicitly encodes extra logic for creating a full lattice

  (=> (and (XP ?xp ?class ?property ?range-class)
           (XP ?xpp ?superclass ?property ?range-class)
           (SC ?class ?superclass))
      (SC ?xp ?xpp))

  (=> (and (XP ?xp ?class ?property ?range-class)
           (XP ?xpp ?class ?property ?range-superclass)
           (SC ?range-class ?range-superclass))
      (SC ?xp ?xpp))

TODO: extend this for other property types




=cut

package GO::LogicEngine;

use Exporter;

use Carp;
use GO::Model::Ontology;
use FileHandle;
use Text::Balanced qw(extract_bracketed);
use strict;
use base qw(GO::Model::Root);

# ontology is a kind of graph
sub ontology {
    my $self = shift;
    $self->{_ontology} = shift if @_;
    return $self->{_ontology};
}

# terms are either natural (non-cross-product) or derived (cross-product);
# this index is by ACC
sub derived_term_index {
    my $self = shift;
    $self->{_derived_term_index} = shift if @_;
    $self->{_derived_term_index} = {} unless $self->{_derived_term_index};
    return $self->{_derived_term_index};
}

# we keep track of which terms have been expanded
# see expand_cross_product_term() for a definition of 'expanded'
# this index is by ACC
sub expanded_term_index {
    my $self = shift;
    $self->{_expanded_term_index} = shift if @_;
    $self->{_expanded_term_index} = {} unless $self->{_expanded_term_index};
    return $self->{_expanded_term_index};
}


# for derived (cross-product) terms, we keep track of the derived term-type
# this index is by ACC
sub derived_term_type {
    my $self = shift;
    $self->{_derived_term_type} = shift if @_;
    return $self->{_derived_term_type};
}


# generates cross products for ALL terms in ontology
sub generate_cross_products {
    my $self = shift;
    my $terms = $self->ontology->get_all_terms;

    # iterate through all terms;
    foreach (@$terms) {
        printf "XP FOR:%s\n", $_->name;
        $self->get_derived_terms($_);
    }
}

# generates cross products for one term only
# ARG: term obj
sub get_derived_terms {
    my $self = shift;
    my $term = shift;

    # check if we have already derived XPs for this term
    my $derived = $self->derived_term_index->{$term->acc};
    return $derived if $derived;

    # we have not yet derived XPs from this term

    # get the ontology/DAG
    my $ontology = $self->ontology;

    # get ALL parent terms (recursive, all reltypes)
    my $superterms = $ontology->get_recursive_parent_terms($term->acc);

    # reflexive (include the term itself)
    my @reflsuperterms = ($term, @$superterms);

    # properties are inherited (through ALL reltypes - FIX???);
    # get properties for the current term
    my @properties =
      map { @{$_->property_list || []} } @reflsuperterms;

    # for every property, we want to generate a cross product
    # eg if DOG has property 'size', we want to make an XP
    # for BIG GOD, SMALL DOG, etc, for all subclasses of 'size'
    my @derived_terms = ();
    foreach my $property (@properties) {
	# make XP for $term X $property
	my $dterms_for_prop =
	  $self->get_derived_terms_for_property($term, $property) || [];
	printf "   %s \"%s\" prop:%s => %d\n", $term->acc, $term->name, $property->name, scalar(@$dterms_for_prop);
	push(@derived_terms, @$dterms_for_prop);
    }

    # make sure we don't derived twice
    $self->derived_term_index->{$term->acc} = \@derived_terms;


    # OFF
    if (0) {
	my $childterms = $ontology->get_child_terms($term->acc);
	foreach my $childterm (@$childterms) {
	    $self->get_derived_terms($childterm);
	}
    }

    return \@derived_terms;
}

# generates cross products for one term and one prop only
# ARG: $term
# ARG: $property
sub get_derived_terms_for_property {
    my $self = shift;
    my $term = shift;
    my $property = shift;

    # ontology/DAG
    my $ontology = $self->ontology;

    # TODO - follow XPs up inheritance graph
    my $superterms = $ontology->get_recursive_parent_terms($term->acc);
    my @reflsuperterms = ($term, @$superterms);
    if (!grep {$_->name eq $property->name}
	map { @{$_->property_list || []} } @reflsuperterms) {
	return;
    }

    # naming rules can be inherited
    my @namerules =
      grep {$_} map {$_->namerule} 
        @{$ontology->get_recursive_parent_terms_by_type($term->acc, 'is_a', 1) || []};
    my $namerule = shift @namerules;

    # definition rules may not
    my $defrule = $term->defrule;

    my $dtype = 'DERIVED:'.$term->type;
    $self->derived_term_type($dtype);

    printf "FINDING PROP VALS FOR %s prop:%s\n", $term->acc, $property->name;

    my $range_acc = $property->range_acc;
    my $range_terms =
      $ontology->get_recursive_child_terms_by_type($range_acc, 'is_a', 1);

    # this is all the values the property can take on;
    # eg for "metal-binding BINDS-TO metal", all_range_terms
    # would be all metals.
    # we would need to make sure that these terms themselves have
    # been fully derived.
    my @all_range_terms =
      grep {$_->acc ne $range_acc}
	map { $_, @{$self->get_derived_terms($_) || [] } } @$range_terms;

    my @derived_terms = ();
    foreach my $range_term (@all_range_terms) {

        use Data::Dumper;

        my $name =
	  sprintf("%s X %s",
		  $term->name, $range_term->name);
        my $def =
          sprintf('This term was automatically generated from '.
                  'the stem term %s ("%s") combined with the '.
                  'property value "%s" set to "%s" ("%s")',
                  $term->acc,
                  $term->name,
		  $property->name,
		  $range_term->acc,
		  $range_term->name);

	my %nv =
	  ($property->name => $range_term->name);
        if ($namerule) {
            $name = $self->generate_text_from_rule($namerule, $term, \%nv);
        }
        if ($defrule) {
            $def = $self->generate_text_from_rule($defrule, $term, \%nv);
        }

        my $acc = $self->get_new_acc();
        my $xpt = 
          $ontology->apph->create_term_obj({name=>$name,
                                            definition=>$def,
                                            type=>$dtype,
                                            acc=>$acc});
	my $restriction =
	  $ontology->apph->create_restriction_obj({property_name=>$property->name,
						   value => $range_term->acc});
        my $xp =
          $ontology->apph->create_cross_product_obj({xp_acc=>$acc,
                                                     parent_acc=>$term->acc,
                                                     restriction_list=>[$restriction]});
        my $existing_xpt = 
          $ontology->get_term_by_cross_product($xp);
        if ($existing_xpt) {
            my $inconsistency =
              $existing_xpt->name ne $xpt->name;
            printf "REUSING %s %s instead of %s %s\n",
              $existing_xpt->acc,
                $existing_xpt->name,
                  $acc,
                    $xpt->name;
            $xpt = $existing_xpt;
            if ($inconsistency) {
                print "  INCONSISTENCY!!\n";
            }
        }
        else {
            $ontology->add_term($xpt);
            $ontology->add_cross_product($xp);
#	    $ontology->add_relationship($term, $xpt, 'is_a');  # HACK!!!
        }
        push(@derived_terms, $xpt);
    }
    
    return \@derived_terms;

}

sub convert_cross_products_to_relationships {
    my $self = shift;
    my $ont = $self->ontology;
    my $xpi = $ont->cross_product_index;
    foreach my $xp (values %$xpi) {
	my $prels = $xp->all_parent_relationships;
	$ont->add_relationship($_) foreach @$prels;
    }
    return;
}

sub expand_all_cross_products {
    my $self = shift;
    my $terms = $self->ontology->get_all_terms;
    foreach (@$terms) {
        $self->expand_cross_product_term($_);
    }
    
}


=head2 expand_cross_product_term

  Usage   - $eng->expand_cross_product_term($term)
  Returns -
  Args    - GO::Model::Term

example:

the cross-product term 'regulation of biosynthesis X pyrimidine'
*implicitly* inherits from the cross-product terms "biosynthesis X
pyrimidine" and "regulation of biosynthesis X nucleic acid". The
inheritance is implicit from the logic of cross products, there are no
actual is_a links in the ontology. We may want to turn these implicit
relationships into real, actual relationships.

=cut

sub expand_cross_product_term {
    my $self = shift;
    my $term = shift;

    my $expanded = $self->expanded_term_index->{$term->acc};
    return $expanded if $expanded;
    $self->expanded_term_index->{$term->acc} = 1;

    my $ontology = $self->ontology;

    printf "EXPANDING [%s] \"%s\"\n", $term->acc, $term->name;
    my $xp = $ontology->cross_product_index->{$term->acc};
    return unless $xp;

    # properties of the parent term of the xp
#    my $props = $ontology->get_term_properties($xp->parent_acc);
    my $superterms = $ontology->get_recursive_parent_terms($xp->parent_acc);
    my @reflsuperterms = ($term, @$superterms);
    my $props =
      [map { @{$_->property_list || []} } @reflsuperterms];

    my @prop_range_accs = map {$_->range_acc} @$props;

    my @orthog_accs = ($xp->parent_acc, map { $_->value } @{$xp->restriction_list||[]});
    $self->expand_cross_product_term($ontology->get_term($_))
      foreach @orthog_accs;

    printf "  %s %s has ORTHOG_ACCS=@orthog_accs\n",
      $term->acc, $term->name;
    for (my $i = 0; $i < @orthog_accs; $i++) {
#        my $orthog_parent_accs =
#          $ontology->get_parent_accs_by_type($orthog_accs[$i], 'is_a') || [];
        my $orthog_parent_rels =
          $ontology->get_parent_relationships($orthog_accs[$i]) || [];
        
#        print "    ORTHOG_PARENT_ACCS [$i] = @$orthog_parent_accs\n";

        # actualize link to implicit parent
#        foreach my $acc (@$orthog_parent_accs) {

        foreach my $rel (@$orthog_parent_rels) {
            my $acc = $rel->parent_acc;
            my $rel_type = $rel->type;

            print "    FINDING FOR $acc\n";

            my $superterm;
            # left side of matrix; eg
            # 'cat' x 'size' - no such xproduct; instead subclass off of
            # the class 'cat'
            if (0 && grep {$_ eq $acc} @prop_range_accs) {
                $superterm = 
                  $ontology->get_term($xp->parent_acc);
                if (!$superterm) {
                    $self->throw("Assertion error");
                }
            }
            else {

		my $parent_xp = 
                  $ontology->apph->create_cross_product_obj;
                $parent_xp->parent_acc($xp->parent_acc);
                my $restrs = $xp->restriction_list;
                foreach (@$restrs) {
                    $parent_xp->add_restriction($_->property_name,
                                                $_->value);
                }

                if ($i==0) {
                    $parent_xp->parent_acc($acc);
                }
                else {
                    $parent_xp->restriction_list->[$i-1]->value($acc);
                }
                $superterm =
                  $ontology->get_term_by_cross_product($parent_xp);
                if (!$superterm) {
                    # no superterms

                    printf "    COULD NOT FIND:\n%s\n", $parent_xp->to_obo;

                    $superterm =
                      $ontology->get_term($orthog_accs[$i]);
                    if ($i==0) {
                        $rel_type = 'is_a';
                    }
                    else {
                        $rel_type = $xp->restriction_list->[$i-1]->property_name;
                    }
#                    print "acc=$acc rt=$rel_type; i=$i\n";
#                    print Dumper $parent_xp;
#                    print $ontology->to_obo;
#                    die;
                }
            }
            printf "    ADDING REL:%s $rel_type %s\n", $term->name, $superterm->name;
            $ontology->add_relationship($superterm,
                                        $term,
                                        $rel_type)
              if $superterm;
        }
    }
    $term;
}

sub generate_text_from_rule {
    my $self = shift;
    my $rule = shift;
    my $term = shift;
    my %nv = %{shift || {}};

    my $name;
    if ($rule) {
        my $rule = $rule;
        my $basename = $term->name;
        $name = '';
        my $more = 1;
        while ($more) {
                
            my $prefix = '';
            my $from = index($rule, '[');
            if ($from > -1) {
                $prefix = substr($rule, 0, $from, '');
            }
            my ($extr, $rem, $skip) = extract_bracketed($rule, '[]');
            if ($extr) {
#                print "$prefix //  $extr // $rem // $skip\n";
                $extr =~ s/\[(.*)\$(\w+)(.*)\]/$1$nv{$2}$3/g;
                $name .= "$prefix $skip $extr ";
                $rule = $rem;
            }
            else {
                $more = 0;
                $name .= $rule;
            }
        }
        $name =~ s/\$NAME/$basename/;
        $name =~ s/^ *//;
        $name =~ s/ *$//;
        $name =~ s/\W+/ /g;
    }
    return $name;
}

sub lastacc {
    my $self = shift;
    $self->{_lastacc} = shift if @_;
    return $self->{_lastacc} || 0;
}



sub get_new_acc {
    my $self = shift;
    my $acc = $self->lastacc +1;
    $self->lastacc($acc);
    "XP:$acc";
}

sub term_key {
    my $self = shift;
    $self->{_term_key} = shift if @_;
    return $self->{_term_key};
}

sub fh {
    my $self = shift;
    $self->{_fh} = shift if @_;
    return $self->{_fh} || \*STDOUT;
}

sub to_prolog {
    my $self = shift;
    my $fh = shift;

    $self->fh($fh) if $fh;

    my $props = $self->ontology->get_all_properties;
    foreach my $prop (@$props) {
	$self->prop_to_prolog($prop);
    }    

    my $terms = $self->ontology->get_all_terms;

    # iterate through all terms;
    foreach my $term (@$terms) {
        next if $term->is_obsolete;
	$self->term_to_prolog($term);
    }    
}

sub term_to_prolog {
    my $self = shift;
    my $term = shift;

    my $fh = $self->fh;

    my $ont = $self->ontology;
    my $k = $self->term_key;
    my $name = $term->name;
    my $kv = $term->acc;
    if ($k) {
	$kv = $term->$k();
    }

    print $fh "% -- $name --\n";

    $self->assert('class',
		  [$kv,
		   $term->name]);
    $self->assert('belongs', [$kv, $term->type]);
    my @syns = @{$term->synonym_list || [] };
    $self->assert('synonym',
		  [$kv, $_]) foreach @syns;
    
    my $prels = $ont->get_parent_relationships($term->acc);
    my $has_isa;
    foreach my $prel (@$prels) {
        my $type = $prel->type;
	my $pterm = $ont->get_term($prel->obj_acc);
	my $ptermname;
	if ($pterm) {
	    $ptermname = $pterm->name;
	}
	else {
	    $ptermname = '?';
	}
        if (lc($type) eq "is_a") {
	    $has_isa = 1;
	    $self->assert('subclass',
			  [$kv,
			   $prel->obj_acc],
			  $ptermname
			 );
        }
        else {
	    $self->assert('restriction',
			  [$kv,
			   $prel->type,
			   $prel->obj_acc],
			 $ptermname);
        }
    }

    my $xp = $ont->get_cross_product($term->acc);
    if ($xp) {
        my $restrs = $xp->restriction_list || [];
        $self->assert(xp=>
		      [
		       pquote($xp->parent_acc),
		       join(', ',
                                (map {sprintf("restriction(%s, %s)", 
					      pquote($_->property_name), 
					      pquote($_->value))} @$restrs))
		      ],
		      join(' ',
			   (map { $ont->get_term($_->value)->name} @$restrs)),
		      1,
		     );
    }
    
    my $props = $term->property_list;
    foreach my $prop (@$props) {
	$self->assert('class-prop',
		      [$kv,
		       $prop->name,
		      ]);
    }

#    if (!$has_isa) {
#	my $categ = $g->category_term($t->acc);
#	if ($categ) {
#	    my $cn;
#	    if (!$categ) {
#		$cn = "Top";
#	    }
#	    else {
#		$cn = $categ->name;
#	    }
#	    $self->write_sc($cn);
#	}
#    }

    print $fh "\n";
}

sub prop_to_prolog {
    my $self = shift;
    my $prop = shift;

    my $fh = $self->fh;

    my $ont = $self->ontology;
    my $name = $prop->name;

    print $fh "% -- $name --\n";

    $self->assert('property',
		  [$name]);

    my $range_acc = $prop->range_acc;
    my $range = $ont->get_term($range_acc);

    $self->assert('property-range',
		  [$name,
		   $range_acc],
		  $range ? $range->name : '');
		    

    print $fh "\n";
}

sub assert {
    my $self = shift;
    my $pred = shift;
    my $args = shift || [];
    my $cmt = shift;
    my $nq = shift;
    my $fh = $self->fh;
    my $str = $self->pclause($pred, $args, $nq);
    print $fh $str;
    if ($cmt) {
	if (length($str) < 40) {
	    print ' ' x (40 - length($str));
	}
	print "% $cmt";
    }
    print $fh "\n";
    return;
}

sub pclause {
    my $self = shift;
    my $pred = shift;
    my $args = shift || [];
    my $nq = shift;
    my $str =
      sprintf("%s(%s).",
	      $pred,
	      join(', ', map {$nq ? $_ : pquote($_)} @$args));
    return $str;
}

sub pquote {
    my $w = shift;
    $w = '' unless defined $w;
    $w =~ s/\'/\'\'/g;
    "'$w'";
}

1;









