# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

package GO::CGI::Blast;

=head1 NAME

  GO::CGI::Blast     - Gene Ontology Blast Reports

=head1 SYNOPSIS



=cut



=head1 DESCRIPTION

parses a blast report (must be a a blast that was performed on a seqdb
that can with headers that can be mapped to go terms via the go
database)

takes the blast hits, and finds the corresponding GO terms (currently
it requires the fasta to have "symbol:" in header but we should make
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

sub getTermListByGPs {
    my $self = shift;
    my ($raw, $apph) = @_;

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
                if ($p >= 0.1) {
                    next;
                }
                my $hit = join(" ", @rest);
                if ($hit =~ /symbol:(\S+)/) {
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

=head2 getgraph

  usage GO::CGI::Blast->getgraph($raw_blast_text,
				 $apph);
  returns GO::Model::Graph, @symbol_list;

=cut



sub getgraph {
  my $self = shift;
  my ($raw, $apph) = @_;
  
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
	my $hit = join(" ", @rest);
                if ($hit =~ /symbol:(\S+)/) {
		  my $s = $1;
		  push(@symbols, $s);
		  $symbol_h->{$s} = {score=>$score};
                }
      }
    }
  }
  $apph->filters({});
  my $terms;
  eval {
    $terms = 
      $apph->get_terms({products=>[@symbols]});
  };
  if (!$terms) {
    return undef, [];
  }
  my $graph = $apph->get_graph_by_terms($terms, 0);
  
  return $graph, \@symbols;
}

=head1 FEEDBACK

Email bradmars@fruitfly.berkeley.edu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself

=cut


1;


