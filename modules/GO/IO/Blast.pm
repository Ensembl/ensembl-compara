# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::IO::Blast;

=head1 NAME

  GO::IO::Blast     - Gene Ontology Blast Reports

=head1 SYNOPSIS



=cut



=head1 DESCRIPTION

parses a blast report (must be a a blast that was performed on a seqdb
that can with headers that can be mapped to go terms via the go
database)

takes the blast hits, and finds the corresponding GO terms (currently
it requires the fasta to have "genename:" in header but we should make
it configurable)

using the GO terms, a GO::Model::Graph is built, with the blast hits
attached according to product<->term links.

Any blast hit H that corresponds to a term T implicitly corresponds to
all the terms above T in the DAG; eg a hit to a G-protein coupled
receptor is implicitly a hit to a transmembrane receptor.

At every node, all the scores (including implicit scores from hits
further down) are combined. Currently we
are playing with this as the scording scheme: 

log2( 2 ** score1 + 2 ** score2 +.... 2** scoreN)

Hits are only counted once at each node.

  TODO - use bioperl to parse full report if required 
           (currently parses summary)

  TODO - configurable ways to go from fasta header to GO terms

  TODO - different scoring schemes

  TODO - result object

=head1 CREDITS

Thanks to Ian Holmes <ihh@fruitfly.org> for help with the Hard Sums
which I half-understand and have probably implemented wrongly...

=head1 PUBLIC METHODS - Blast


=cut


use strict;
use Carp;
use base qw(GO::Model::Root);
use GO::Utils qw(rearrange);
sub _valid_params { qw(apph output file raw) };

sub load_file {
    my $self = shift;
    my $file = shift || $self->file;
    my $fh = FileHandle->new($file);
    my $raw = join("", <$fh>);
    $self->raw($raw);
    $raw;
}

sub showgraph {
    my $self = shift;
    $self->getgraph(@_);
    print $self->output;
}


sub getTermListByGPs {
    my $self = shift;
    my ($raw, $apph) = @_;

    if (!$raw) {
        $raw = $self->load_file;
    }

    my @lines = split(/\n/, $raw);
    my $in_summary = 0;

    my @symbols = ();
    my $symbol_h = {};
    foreach (@lines) {
        chomp;
        if (!$_) {
            next;
        }
        if (/^\>/) {
            $in_summary = 0;
        }
        if (/^\>/) {
            $in_summary = 0;
        }
        if (/Sequences producing/) {
            $in_summary = 1;
            next;
        }
        else {
            if ($in_summary) {
                my @w = split;
                my ($n, $p, $score, @rest) = reverse @w;
#                if ($p >= 0.1) {
#                    next;
#                }
                my $hit = join(" ", @rest);
                if ($hit =~ /genename:(\S+)/) {
                    my $s = $1;
                    push(@symbols, $s);
                    $symbol_h->{$s} = {score=>$score};
                }
            }
        }
    }

#    my $terms = 
#      $apph->get_terms({products=>[@symbols], type=>"function"});
    my $terms = 
      $apph->get_terms({products=>[@symbols]});
    #my $graph = $apph->get_graph_by_terms($terms, 0);


    return $terms;
}


sub getgraph {
    my $self = shift;
    my ($raw, $apph) = @_;

#    print '<pre>';
#    print $raw;
#    print '</pre>';
    if (!$raw) {
        $raw = $self->load_file;
    }

    my @lines = split(/\n/, $raw);
    my $in_summary = 0;

    my @symbols = ();
    my $symbol_h = {};
    foreach (@lines) {
        chomp;
        if (!$_) {
            next;
        }
        if (/^\>/) {
            $in_summary = 0;
        }
        if (/^\>/) {
            $in_summary = 0;
        }
        if (/Sequences producing/) {
            $in_summary = 1;
            next;
        }
        else {
            if ($in_summary) {
                my @w = split;
                my ($n, $p, $score, @rest) = reverse @w;
#                if ($p >= 0.1) {
#                    next;
#                }
                my $hit = join(" ", @rest);
                if ($hit =~ /symbol:(\S+)/) {
#                if ($hit =~ /genename:(\S+)/) {
                    my $s = $1;
                    push(@symbols, $s);
#                    if (!$symbol_h->{$s}) {
#                        $symbol_h->{$s} = [];
#                    }
#                    push(@{$symbol_h->{$s}}, {score=>$score});
                    $symbol_h->{$s} = {score=>$score};
                }
            }
        }
    }
#    printf "<h2>SYMBOLS meeting threshold:%s\n</h2>", join(" ", @symbols);
#    my $apph = $self->apph;

#    my $terms = 
#      $apph->get_terms({products=>[@symbols], type=>"function"});
    $apph->filters({});
    my $terms = 
      $apph->get_terms({products=>[@symbols]});
#    print $terms;
#    foreach my $term (@$terms) {
#        $self->out(" ".$term->public_acc);
#    }
    my $graph = $apph->get_graph_by_terms($terms, 0);

    return $graph, \@symbols;

#    return $symbol_h;;

###################################################

    # ----------------

    # associate every product in graph with
    # all the nodes at or above the current position,
    # counting each product only once at each node

    # look up a hash of products (explicit and implict) by term
    my @term_lookup = ();

    # recurse down graph to get implicit products
    # from node beneath
    sub myrecurse {
        my $terms = shift;

        foreach my $term (@$terms) {

            # get the list of nodes below this one
            my $children = $graph->get_child_terms($term);

            if (@$children) {
                # not a leaf node

                # recurse further
                myrecurse($children);
                foreach my $child (@$children) {
                    my $ph = $term_lookup[$child->acc];
                    foreach (keys %{$ph || {}}) {
                        $term_lookup[$term->acc]->{$_} = $ph->{$_};
                    }
                }
            }

            if (!$term_lookup[$term->acc]) {
                $term_lookup[$term->acc] = {};
            }
            # count all the products at this point in the DAG
            foreach (@{$term->selected_association_list || []}) {
                $term_lookup[$term->acc]->{$_->gene_product->id} = 
                  $_->gene_product;
            }
        }
    }
    myrecurse($graph->get_top_nodes);

    
    sub shownode {
        my $ni = shift;
        my $depth = $ni->depth;
        my $term = $ni->term;
        my $reltype = $ni->parent_rel ? $ni->parent_rel->type : "";
        my $tab = $graph->is_focus_node($term) ? "->->" : "    ";
        my $ph = $term_lookup[$term->acc];
        # all the products by symbol at this node or below
        my @allsymbols = map {$_->symbol} values %$ph;
#        my $logsum = 0;
#        map { $logsum += 2 ** $symbol_h->{$_}->{score} } @allsymbols;
#        my $score = log($logsum)/log(2);

        my $logsum = 0;
	my $score = 0;
	if (@allsymbols) {
	    map { $logsum += 2 ** $symbol_h->{$_}->{score} } @allsymbols;
	    $score = log($logsum)/log(2);
	}
	# fudgefactor: (assumes 90% of prod2term assoc being correct)
	# prod2terms aren't independent but we treat them like
	# they are
	$score *= 1 - (0.1 ** scalar(@allsymbols));


#	my $score = 0;
#	map { $score += $symbol_h->{$_}->{score} } @allsymbols;
        my $out =
          sprintf 
            "%s %2s Term = %s (%s); SCORE=%.2f\n",
            "  . " x $depth,
            $reltype eq "isa" ? "%" : "<",
            $term->name,
            $term->public_acc,
            $score,
            ;
        foreach (@{$term->selected_association_list || []}) {
            my $sym = $_->gene_product->symbol;
            $out.= $tab x $depth . "    :: " . $sym;
            $out.= " ".$_->gene_product->xref->as_str;
            $out.= " ".$_->evidence_as_str(1)." ";
            $out.= " ".$symbol_h->{$sym}->{score}.";";
            $out.= "\n";
            
        }
        $self->out("$out");
    }

#    my $it = $graph->create_iterator;
    # returns a GO::Model::GraphIterator object

    #$graph->iterate(\&shownode);
    return $graph;

    
}

sub out {
    my $self = shift;
    my $str = shift;
    $self->output($self->output().$str);
}


sub parse {

}


=head1 FEEDBACK

Email cjm@fruitfly.berkeley.edu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself

=cut


1;


