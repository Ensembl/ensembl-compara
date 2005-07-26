# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/bin/perl -w
package GO::Browser::Tree;

use lib '.';
use strict;
use Carp;
use Exporter;
use FreezeThaw qw(thaw freeze);
use GO::MiscUtils qw(dd);
# Get args
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

#$0 =~ /^(.*\/|)([^\/]*)/;
#my ($progdir, $progname) = ($1, $2);

#my $reset;
#while (@ARGV && $ARGV[0] =~ /^-/) {
#    my $opt = shift;
#}

sub new {
  my $class = shift;
  my $dbh = shift;
  my $self = {};
  $self->{dbh} = $dbh;
  $self->{tree} = ();
  bless $self, $class;
  return $self;
}
  
sub _has_element {
  my $self=shift;
  my $value = shift;
  my $array=shift;

  foreach my $element (@{$array}) {
    if ($element->{acc} == $value) {
      return 1;
    }
  }
  return 0;
}


sub build_tree {
  my $self=shift;
  my $args = shift;

  
  my $graph = $self->{dbh}->get_node_graph($args->{acc}, $args->{depth}+1);
  my @nodes = @{$graph->get_all_nodes};
  my @parent_rels;

  my $d = $args->{depth} + 2;
  
  my $i;
  for ($i = 1; $i < $d; $i++) {
    foreach my $node (@nodes) {
      if ($i == 1) {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  if ($rel->{acc1} == $args->{acc}) {
	    push @{$self->{tree}->[0]}, $node;
	  }
	}
      } elsif ($i == 2)  {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  if ($self->_has_element($rel->{acc1}, $self->{tree}->[0] )) {
	    push @{$self->{tree}->[1]->{$rel->{acc1}}} , $node;
	  }
	}
      } else {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  foreach my $key (keys %{$self->{tree}->[$i-2]}) {
	    if ($self->_has_element($rel->{acc1}, 
				    $self->{tree}->[$i-2]->{$key})) {
	      push @{$self->{tree}->[$i-1]->{$rel->{acc1}}} , $node;
	    }
	  }
	}
      }
    }
   }
  return $self->{tree};
}

sub get_tree {
  my $self=shift;
  return $self->{tree};
}




1;
