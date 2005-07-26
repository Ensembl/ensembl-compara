# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/bin/perl -w
package GO::Browser::HTMLBuilder2;

use lib '.';
use strict;
use Carp;
use Exporter;
use FreezeThaw qw(thaw freeze);
use GO::DatabaseLoader;
use GO::Parser;
use GO::Tools;
use Data::Dumper;
use GO::MiscUtils qw(dd);
use CGI qw/:standard/;
# Get args
use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

$0 =~ /^(.*\/|)([^\/]*)/;
my ($progdir, $progname) = ($1, $2);

my $reset;
while (@ARGV && $ARGV[0] =~ /^-/) {
    my $opt = shift;
}

sub new {
  my $class = shift;
  my $db = shift;
  my $urlpost = shift;
  my $session = {person=>'auto'};
  my $dbh = GO::Tools::get_handle($db);
  my $self = {};
  $self->{dbh} = $dbh;
  $self->{session} = $session;
  $self->{topelement} = 3673;
  $self->{urlpost} = $urlpost;
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
    if (! defined @$parent_a[0]) {
      return 0;
    } elsif ( %{@$parent_a[0]}->{acc} != $self->{topelement} ) {
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
	  GO::Tools::get_relationships($self->{dbh}, 
				       {acc2 => %{@$parent_a[0]}->{acc} });
	my $counter = 0;
	foreach my $parent (@$parentparents) {
	  if ($counter == 0) {
	    unshift @$parent_a,  GO::Tools::get_term($self->{dbh}, 
						     { acc => $parent->{acc1}});
	    ++$counter ;
	  } else {
	    unshift @{$self->{$parents_name}}, thaw freeze $parent_a;
	    unshift @{$self->{$parents_name}->[0]}, 
	      GO::Tools::get_term($self->{dbh}, { acc => $parent->{acc1}});
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
	    if ($self->_has_element($rel->{acc1}, 
				    $self->{$graph_name}->[$i-2]->{$key})) {
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
  my $rooturl="<a  href=term2.cgi?accession=";
  my $termm=GO::Tools::get_term($self->{dbh}, { acc => $acc });

  $HTMLString .= $rooturl . $termm->{acc} . $self->{urlpost};
  $HTMLString .= " target=TERM>";
  $HTMLString .= $termm->{acc} . "  :  " . $termm->{name};
  $HTMLString .= "</a><br>";
  
  $HTMLString .= $self->draw_sibs($acc,1);

  return $HTMLString;
}

  
  

sub draw_term {
  my $self=shift;
  my $acc=shift;
  my $HTMLString;

  my $rooturl="<a  href=http://www.fruitfly.org/~bradmars/cgi-bin/term2.cgi?accession=";
  my $termm=GO::Tools::get_term($self->{dbh}, { acc => $acc });

  $HTMLString .= "<table border=0 width=250>";
  $HTMLString .= "<tr><th valign=top>Term:</th><td valign=top>";
  $HTMLString .= $termm->name;
  $HTMLString .= "</td></tr><tr><th valign=top>Synonyms:</th><td valign=top>";
  if (! $termm->synonym_list ) {
     $HTMLString .= "none";
   } else {
     foreach my $syn (@{$termm->synonym_list}) {
       $HTMLString .= "$syn <br>";
     }
   }
  $HTMLString .= "</td></tr><tr><th valign=top>Accession:</th><td valign=top>";
  $HTMLString .= $termm->acc;
  $HTMLString .= "</td></tr><tr><th valign=top>Type:</th><td valign=top>";
  $HTMLString .= $termm->type;
  $HTMLString .= "</td></tr><tr><th valign=top>Definition:</th><td valign=top>";
  $HTMLString .= $termm->definition || "none";
  $HTMLString .= "</td><tr><td colspan=2 align=center>";
  $HTMLString .= "<form action=tree target=tree><input type=hidden name=accession value=$termm->{acc} ><input type=submit value='Refocus on me!'> ";
  $HTMLString .= "</form></table>";

  return $HTMLString;
}

### Here is a basic skeleton code fort looping thru the
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
#	  print "Leaf: " . $tree->[$horizontal]->{$stack[-1]}
#->[$vertical->{$stack[-1]}]->{acc} . "\n";
#	  $vertical->{$stack[-1]}++;
#	} else {
#	  pop @stack;
#	  $horizontal--;
#	}
#      } elsif (($horizontal < (scalar(@{$tree})-1)) and ($horizontal < $dep-1))  {
#	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]) {
#	  print "Stem " . $tree->[$horizontal]->{$stack[-1]}
#->[$vertical->{$stack[-1]}]->{acc} . "\n";#
#	  push @stack, $tree->[$horizontal]->{$stack[-1]}
#->[$vertical->{$stack[-1]}]->{acc};
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
  my $termurl = "<a href=term2.cgi?accession=";
  my $treeurl = "<a href=term2.cgi?accession=";
  my $HTMLString ;

  foreach my $child (@{$tree->[0]}) {
    $HTMLString .= $termurl . $child->{acc} . $self->{urlpost} . " target=TERM>" ;
    $HTMLString .= $child->{acc}. "  :  ";
    $HTMLString .= $child->{name} ;
    if ($dep==1 and $tree->[1]->{$child->{acc}}) {
      $HTMLString .= "  (+)";
    }
    $HTMLString .= "</a>\n<br><spacer type=vertical size=4>";
    $HTMLString .= "";
    push @stack, $child->{acc};
    $vertical->{$child->{acc}} = 0;
    $horizontal++;
    while ($horizontal > 0 and $dep > 1) {
      if (($horizontal == $dep-1) or ($horizontal == scalar(@{$tree})-1)) {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	    my $spacer;
	      while ($spacer < $horizontal) {
		  $HTMLString .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
		  $spacer++;
	      }
	  $HTMLString .= $termurl .$tree->[$horizontal]->{$stack[-1]}
	    ->[$vertical->{$stack[-1]}]->{acc} . $self->{urlpost} . " target=TERM>" ;
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]
	      ->{acc}. "  :  ";
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]
	      ->{name} ;
	  if ($tree->[$horizontal+1]->{$tree->[$horizontal]->{$stack[-1]}
				       ->[$vertical->{$stack[-1]}]->{acc}}) {
	    $HTMLString .= "  (+)";
	  }
	  $HTMLString .= "</a>\n<br><spacer type=vertical size=4>";
	  $HTMLString .= "";
	  
	  $vertical->{$stack[-1]}++;
	} else {
	  pop @stack;
	  $horizontal--;
	}
      } elsif ($horizontal < scalar(@{$tree})-1 and $horizontal < $dep-1)  {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	    my $spacer;
	      while ($spacer < $horizontal) {
		  $HTMLString .= "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
		  $spacer++;
	      }
	  $HTMLString .= $termurl .$tree->[$horizontal]->{$stack[-1]}
	    ->[$vertical->{$stack[-1]}]->{acc} . $self->{urlpost} . " target=TERM>" ;
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}
	    ->[$vertical->{$stack[-1]}]->{acc}. "  :  ";
	  $HTMLString .= $tree->[$horizontal]->{$stack[-1]}
	    ->[$vertical->{$stack[-1]}]->{name};
	  $HTMLString .= "</a>\n<br><spacer type=vertical size=4>";
	  push @stack, $tree->[$horizontal]->{$stack[-1]}
	    ->[$vertical->{$stack[-1]}]->{acc};
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
  my $HTMLString='';;
  my $rooturl="<a  href=term2.cgi?accession=";

  foreach my $parent_a (@{$tree}) {
    if (defined  @{$parent_a}[-1] ) {
      for (my $i=0; $i < scalar(@{$parent_a})-1; ++$i) {
	$HTMLString .= $rooturl . @{$parent_a}[$i]->{acc} . $self->{urlpost} . " target=TERM>";
	$HTMLString .= '<img src="arrow2.jpg" border=0 hspace=1></a>';
      }
      $HTMLString .= "<spacer type=vertical length=4>";
      $HTMLString .= $rooturl . @{$parent_a}[-1]->{acc}. $self->{urlpost} . " target=TERM>";
      $HTMLString .= @{$parent_a}[-1]->{acc} . "  :  ";
      $HTMLString .= @{$parent_a}[-1]->{name};
      $HTMLString .= "</a><br>";
    } else {
      $HTMLString .= "<spacer type=vertical length=4> none ";
    }
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

  if (not defined($self->{parents})) {
    $self->_get_parents($acc, 'parents');
  }

  $HTMLString .= $self->draw_parents($self->{parents}) ."</td><td valign=top>";


  $HTMLString .= $self->draw_selected_term($acc) . "</td><td valign=top>";

  $self->_get_children($acc, 'children', $depth);

  $HTMLString  .= $self->_draw_tree($self->{children}, $depth);

  $HTMLString .= "</td></tr></table><br>";
  
  return $HTMLString;
 

}

sub draw_sibs {
  my $self=shift;
  my $acc=shift;
  my $depth=shift;
  my @parents;
  my $graphs_h;
  my $count;
  my $parents;
  my $HTMLString;

  unless ($self->{parents}) {
    $self->_get_parents($acc, 'parents');
  }
  $HTMLString .= "<table border=0 cellpadding=5><tr><th> Siblings: </th></tr>";
  if (defined $self->{parents}[0]->[-1]) {
    $self->_get_children($self->{parents}[0]->[-1]->{acc}, 'siblings', $depth);
    $HTMLString .= "<td>" . $self->_draw_tree($self->{siblings}, $depth);
  } else {
    $HTMLString .= "<td>";
  }
  $HTMLString .= "</td></tr></table><br>";
  
  return $HTMLString;
  

}

sub search {
  my $self=shift;
  my $search_term = shift;
  my $HTMLString;
  
  my $query = GO::Tools::get_terms($self->{dbh}, { search => $search_term });
  if (!$query->[0]->{name}) {confess ("no hits");}
  foreach my $q (@{$query}) {
    $HTMLString .= "<a href=main?accession=$q->{acc}>$q->{name}</a>";
    $HTMLString .= "<p>";
  }
  return $HTMLString; 
    
}
  
sub term_table {
  my $self = shift;
  my $acc = shift;
  my $HTMLString;

  $HTMLString .= "<table width=100% border=1><tr><td>";
  $HTMLString .= "<table border=1><th>Control Panel:</th><th>Term-info:</th>
    <th>Term-siblings</th><tr><td bgcolor='sky blue' valign=top>";
  $HTMLString .= "<a href=go.cgi?accession=3673$self->{urlpost}>Top of tree.</a>";
  my $form = $self->short_form;
  $HTMLString .= $form;
  $HTMLString .= "</td><td valign=top>";
  my $term = $self->draw_term($acc);
  $HTMLString .= $term;
  $HTMLString .= "</td>";
  if (param('siblings')) {
    $HTMLString .= "<td>";
    my $sibs = $self->draw_sibs($acc, 1);
    $HTMLString .= $sibs;
    $HTMLString .= "</td></tr></table>";
  } else {
    $HTMLString .= "</tr></table>";
  }
  $HTMLString .= "<tr><td>";
    my $table = $self->draw_tree($acc, param('depth') || 2);
  $HTMLString .= $table;
  $HTMLString .= "</td></tr><tr><td>";
  $HTMLString .= "</table>";
  return $HTMLString;
}

sub short_form {
  return '<FORM METHOD="GET" ACTION="go.cgi" 
ENCTYPE="application/x-www-form-urlencoded">
Enter a go term: 
<P>
<INPUT TYPE="text" NAME="search">
<P>
Enter a go accession: 
<P>
<INPUT TYPE="text" NAME="accession">
<P>
Choose tree depth:
<P>
<INPUT TYPE="radio" NAME="depth" VALUE="1"> 1
<INPUT TYPE="radio" NAME="depth" VALUE="2" CHECKED> 2
<INPUT TYPE="radio" NAME="depth" VALUE="3"> 3
<P>
Check for siblings: 
<P>
<INPUT TYPE="checkbox" NAME="siblings" VALUE="on" CHECKED>
siblings
<P>
<INPUT TYPE="submit" NAME=".submit">
<P>
</FORM>';
  

}

1;
