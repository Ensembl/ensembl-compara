# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/bin/perl -w
package GO::Browser::HTMLBuilder4;

use lib '.';
use strict;
use Carp;
use Exporter;
use GO::DatabaseLoader;
use GO::Parser;
use GO::Tools;
use Data::Dumper;
use GO::MiscUtils qw(dd);
use CGI qw/:standard/;
# Get args
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(GO::Model::Root GO::Builder Exporter);

$0 =~ /^(.*\/|)([^\/]*)/;
my ($progdir, $progname) = ($1, $2);

my $reset;
while (@ARGV && $ARGV[0] =~ /^-/) {
    my $opt = shift;
}

sub new {
  my $class = shift;
  my $db = shift;
  my $session = {person=>'auto'};
  my $dbh = GO::Tools::get_handle($db);
  my $self = {};
  $self->{dbh} = $dbh;
  $self->{session} = $session;
  $self->{topelement} = 3673;
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

sub _not_at_top {
  my $self = shift;
  my $parents_a = shift;
  my $parent_a;

  foreach $parent_a (@$parents_a) {
    if ( %{@$parent_a[0]}->{acc} != $self->{topelement} ) {
      return 1;
    }
  }
  return 0;
}


sub _get_parents {
  my $self = shift;
  my $acc = shift;
  my $parents_name = shift;
  my $parent_a;

  my $parent_accs =
    GO::Tools::get_relationships($self->{dbh}, {acc2 => $acc});

  foreach my $par (@{$parent_accs}) {
    push my @my_array, GO::Tools::get_term($self->{dbh}, { acc => $par->{acc1} });
    unshift @{$self->{$parents_name}}, \@my_array;
  }

  while ($self->_not_at_top($self->{$parents_name})) {
    foreach $parent_a (@{$self->{$parents_name}}) {
      if (%{@$parent_a[0]}->{acc} != $self->{topelement}) {
	my $parentparents = 
	  GO::Tools::get_relationships($self->{dbh}, {acc2 => %{@$parent_a[0]}->{acc} });
	my $counter = 0;
	foreach my $parent (@$parentparents) {
	  if ($counter == 0) {
	    unshift @$parent_a,  GO::Tools::get_term($self->{dbh}, { acc => $parent->{acc1}});
	    ++$counter ;
	  } else {
	    unshift @{$self->{$parents_name}}, thaw freeze $parent_a;
	    unshift @{$self->{$parents_name}->[0]}, GO::Tools::get_term($self->{dbh}, { acc => $parent->{acc1}});
	  }
	}
      }
    }
  }
}

sub _get_children {
  my $self=shift;
  my $acc = shift;
  my $graph_name = shift;
  my $depth=shift;

  my $graph = GO::Tools::get_node_graph($self->{dbh}, $acc, $depth+1);
  my @nodes = @{$graph->get_all_nodes};
  my @parent_rels;

  my $d = $depth + 2;
  my $i;
  for ($i = 1; $i < $d; $i++) {
    foreach my $node (@nodes) {
      if ($i == 1) {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  if ($rel->{acc1} == $acc) {
	    push @{$self->{$graph_name}->[0]}, $node;
	  }
	}
      } elsif ($i == 2)  {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  if ($self->_has_element($rel->{acc1}, $self->{$graph_name}->[0] )) {
	    push @{$self->{$graph_name}->[1]->{$rel->{acc1}}} , $node;
	  }
	}
      } else {
	@parent_rels = @{$graph->get_parent_relationships($node->{acc})};
	foreach my $rel (@parent_rels) {
	  foreach my $key (keys %{$self->{$graph_name}->[$i-2]}) {
	    if ($self->_has_element($rel->{acc1}, $self->{$graph_name}->[$i-2]->{$key})) {
	      push @{$self->{$graph_name}->[$i-1]->{$rel->{acc1}}} , $node;
	    }
	  }
	}
      }
    }
  }
}

sub draw_selected_term {
  my $self = shift;
  my $acc = shift;

  my $HTMLString;
  my $rooturl="<a target=term href=term.cgi?accession=";
  my $termm=GO::Tools::get_term($self->{dbh}, { acc => $acc });

  $HTMLString .= $rooturl . $termm->{acc} . ">";
  $HTMLString .= $termm->{acc} . "  :  " . $termm->{name};
  $HTMLString .= "</a><br>";

  return $HTMLString;
}

  
  

sub draw_term {
  my $self=shift;
  my $acc=shift;
  my $HTMLString;

  my $rooturl="<a target=term href=http://www.fruitfly.org/~bradmars/cgi-bin/go.cgi?accession=";
  my $termm=GO::Tools::get_term($self->{dbh}, { acc => $acc });
  my @syns = $termm->synonym_list;

  $HTMLString .= "<table border=0 width=100%>";
  $HTMLString .= "<tr><th>Term:</th><td width=80%>";
  $HTMLString .= $termm->name;
  $HTMLString .= "</td></tr><tr><th>Synonyms:</th><td>";
  foreach my $syn (@syns) {
    $HTMLString .= $syn;
  }
  $HTMLString .= "</td></tr><tr><th>Accession:</th><td>";
  $HTMLString .= $termm->acc;
  $HTMLString .= "</td></tr><tr><th>Definition:</th><td>";
  $HTMLString .= $termm->definition;
  $HTMLString .= "</td></tr><tr><th>Type:</th><td>";
  $HTMLString .= $termm->type;
  $HTMLString .= "</td></table>";

  return $HTMLString;
}

### Here is absic skeleton code fort looping thru the
### tree returned by get_children and printing the acc's.
  
#sub _draw_tree {
#  my $self = shift;
#  my $tree = shift;
#  my $dep = shift;
 
#  print "Tree: " .scalar(@{$tree}) . "\n";
  
#  my $horizontal = 0;
#  my @stack;
#  my $vertical = {};

#  print "Depth: $dep \n";
  
#  foreach my $child (@{$tree->[0]}) {
#    print "Child: $child->{acc} \n";
#    push @stack, $child->{acc};
#    $vertical->{$child->{acc}} = 0;
#    $horizontal++;
#    while ($horizontal > 0 and $dep > 1) {
#      if ($horizontal == $dep-1 or $horizontal == scalar(@{$tree})-1) {
#	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
#	  print "Leaf: " . $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc} . "\n";
#	  $vertical->{$stack[-1]}++;
#	} else {
#	  pop @stack;
#	  $horizontal--;
#	}
#      } elsif (($horizontal < (scalar(@{$tree})-1)) and ($horizontal < $dep-1))  {
#	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]) {
#	  print "Stem " . $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc} . "\n";#
#	  push @stack, $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc};
#	  $vertical->{$stack[-2]}++;
#	  $vertical->{$stack[-1]} = 0;
#	  $horizontal++;
#	} else {
#	  pop @stack;
#	  $horizontal--;
#	}
#      } else {
#	$horizontal--;
#      }
#    }    
#  }
#}



sub _draw_tree {
  my $self = shift;
  my $tree = shift;
  my $dep = shift;
 
  my $horizontal = 0;
  my @stack;
  my $vertical = {};
  my $termurl = "<a target=term href=term.cgi?accession=";
  my $treeurl = "<a href=term.cgi?accession=";
  my $HTMLString ;

  foreach my $child (@{$tree->[0]}) {
    $HTMLString .= $termurl . $child->{acc} . ">" ;
    $HTMLString .= $child->{acc}. "  :  ";
    $HTMLString .= $child->{name} ;
    if ($dep==1 and $tree->[1]->{$child->{acc}}) {
      $HTMLString .= "  (+)";
    }
    $HTMLString .= "</a><br><spacer type=vertical size=4>";
    $HTMLString .= "";
    push @stack, $child->{acc};
    $vertical->{$child->{acc}} = 0;
    $horizontal++;
    while ($horizontal > 0 and $dep > 1) {
      if (($horizontal == $dep-1) or ($horizontal == scalar(@{$tree})-1)) {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	  $HTMLString .= "<spacer type=horizontal size=" . $horizontal * 125 . ">";
	  $HTMLString .= $termurl .$tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc} . ">" ;
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}. "  :  ";
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{name} ;
	  if ($tree->[$horizontal+1]->{$tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}}) {
	    $HTMLString .= "  (+)";
	  }
	  $HTMLString .= "</a><br><spacer type=vertical size=4>";
	  $HTMLString .= "";
	  
	  $vertical->{$stack[-1]}++;
	} else {
	  pop @stack;
	  $horizontal--;
	}
      } elsif ($horizontal < scalar(@{$tree})-1 and $horizontal < $dep-1)  {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	  $HTMLString .= "<spacer type=horizontal size=" . $horizontal * 125 . ">";
	  $HTMLString .= $termurl .$tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc} . ">" ;
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}. "  :  ";
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{name};
	  $HTMLString .= "</a><br><spacer type=vertical size=4>";
	  push @stack, $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc};
	  $vertical->{$stack[-2]}++;
	  $vertical->{$stack[-1]} = 0;
	  $horizontal++;
	} else {
	  pop @stack;
	  $horizontal--;
	}
      } else {
	$horizontal--;
      }
    }    
  }
  return $HTMLString;
}

sub draw_parents {
  my $self=shift;
  my $tree = shift;
  
  my $HTMLString;
  my $rooturl="<a target=term href=term.cgi?accession=";

  foreach my $parent_a (@{$tree}) {
    $HTMLString .= "<spacer type=vertical length=4>";
    $HTMLString .= $rooturl . @{$parent_a}[-1]->{acc}. ">";
    $HTMLString .= @{$parent_a}[-1]->{acc} . "  :  ";
    $HTMLString .= @{$parent_a}[-1]->{name};
    $HTMLString .= "</a><br>";
  }
  return $HTMLString;
}

sub draw_tree {
  my $self=shift;
  my $acc=shift;
  my $depth=shift;
  my @parents;
  my $graphs_h;
  my $count;
  my $parents;
  my $HTMLString;

  $HTMLString .= "<table border=1 cellpadding=5>";
  $HTMLString .= "<th>Parents:</th><th>Term:</th><th>Descendants:</th>";
  $HTMLString .= "<tr><td valign=top>";

  $self->_get_parents($acc, 'parents');

  $HTMLString .= $self->draw_parents($self->{parents}) ."</td><td valign=top>";


  $HTMLString .= $self->draw_selected_term($acc) . "</td><td valign=top>";

  $self->_get_children($acc, 'children', $depth);

  $HTMLString  .= $self->_draw_tree($self->{children}, $depth);

  $HTMLString .= "</td></tr></table><br>";
  
  $HTMLString .= "<table border=1 cellpadding=5>";
  $HTMLString .= "<th>Parent: </th><th> Siblings: </th><tr><td>";
  $HTMLString .= $self->draw_selected_term($self->{parents}->[0]->[-1]->{acc});
  $HTMLString .= "</td><td>";
  $self->_get_children($self->{parents}[0]->[-1]->{acc}, 'siblings', 1);
  $HTMLString .= $self->_draw_tree($self->{siblings}, 1);
  $HTMLString .= "</td></tr></table>";

  print $HTMLString;
 

}

1;
