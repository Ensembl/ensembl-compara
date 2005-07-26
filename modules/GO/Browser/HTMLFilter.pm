# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/bin/perl -w
package GO::Browser::HTMLFilter;

use lib '.';
use strict;
use Carp;
use Exporter;
use FreezeThaw qw(thaw freeze);
use GO::DatabaseLoader;
use GO::Parser;
use GO::AppHandle;
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
  my $urlpost = shift;
  my $session = {person=>'auto'};
  my $self = {};
  $self->{urlpost} = $urlpost;
  bless $self, $class;
  return $self;
}
  
sub draw_selected_term {
  my $self = shift;
  my $term = shift;
  my $HTMLPlugin = shift;
  my $table_name=shift;

  $HTMLPlugin->start_table({name=>$table_name || "Term"});
  $HTMLPlugin->add_term({term=>$term});
  $HTMLPlugin->end_table();
  return $HTMLPlugin->{HTMLString};
}

  
  

sub draw_term {
  my $self=shift;
  my $dbh = shift;
  my $acc=shift;
  my $HTMLString;

  my $termm=$dbh->get_term( { acc => $acc });

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
  $HTMLString .= "<form action='tree?accession=$acc" . "&" . $self->{urlpost} .  "' target=tree><input type=hidden name=accession value=$termm->{acc} >";
  $HTMLString .= "<input type=submit value='Refocus on me!'> ";
  $HTMLString .= "</form></table>";

  return $HTMLString;

}

### Here is a basic skeleton code fort looping thru the
### tree returned by get_children and printing the acc's.
  
#sub draw_tree {
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



sub draw_tree {
  my $self = shift;
  my $tree = shift;
  my $dep = shift;
  my $HTMLPlugin = shift;
  my $table_name = shift;
  my $filter = shift;
 
  my $horizontal = 0;
  my @stack;
  my $vertical = {};
  
  $HTMLPlugin->start_table({name=>$table_name || "descendents"});
  foreach my $child (@{$tree->[0]}) {
    if ($dep==1 and $tree->[1]->{$child->{acc}}) {
      if ($child->{acc} != $filter) {
	$HTMLPlugin->add_term({term=>$child, namepost=> " (+)"});
	$HTMLPlugin->grow_html({string=>"<br>"});
      }
    } else {
      if ($child->{acc} != $filter) {
	$HTMLPlugin->add_term({term=>$child});
	$HTMLPlugin->grow_html({string=>"<br>"});
      }
    }
    push @stack, $child->{acc};
    $vertical->{$child->{acc}} = 0;
    $horizontal++;
    while ($horizontal > 0 and $dep > 1) {
      if (($horizontal == $dep-1) or ($horizontal == scalar(@{$tree})-1)) {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	    my $spacer;
	    while ($spacer < $horizontal) {
	      $HTMLPlugin->grow_html({string=>"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"});
	      $spacer++;
	    }
	    if ($tree->[$horizontal+1]->{$tree->[$horizontal]->{$stack[-1]}
					 ->[$vertical->{$stack[-1]}]->{acc}}) {
	      $HTMLPlugin->add_term({term=>$tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}], 
				     namepost=>"(+)"});
	      $HTMLPlugin->grow_html({string=>"<br>"});
	  } else {
	      $HTMLPlugin->add_term({term=>$tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]});
	      $HTMLPlugin->grow_html({string=>"<br>"});
	    }
	    $vertical->{$stack[-1]}++;
	} else {
	  pop @stack;
	  $horizontal--;
	}
      } elsif ($horizontal < scalar(@{$tree})-1 and $horizontal < $dep-1)  {
	if ($tree->[$horizontal]->{$stack[-1]}->[$vertical->{$stack[-1]}]->{acc}) {
	    my $spacer;
	    while ($spacer < $horizontal) {
	      $HTMLPlugin->grow_html({string=>"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"});
	      $spacer++;
	    }
	    $HTMLPlugin->add_term({term=>$tree->[$horizontal]->{$stack[-1]}
				   ->[$vertical->{$stack[-1]}]});
	    $HTMLPlugin->grow_html({string=>"<br>"});
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
  $HTMLPlugin->end_table();
  return $HTMLPlugin->{HTMLString};
}

sub draw_parents {
  my $self=shift;
  my $tree = shift;
  my $HTMLPlugin = shift;

  $HTMLPlugin->start_table({name=>"Parents"});
  
  foreach my $parent_a (@{$tree}) {
    if (defined  @{$parent_a}[-1] ) {
      for (my $i=0; $i < scalar(@{$parent_a})-1; ++$i) {
	$HTMLPlugin->add_term_image({term=>@{$parent_a}[$i], image=>'http://www.fruitfly.org/~bradmars/cgi-bin/arrow2.jpg'});
      }
      $HTMLPlugin->add_term({term=>@{$parent_a}[-1]});
      $HTMLPlugin->grow_html({string=>"<br>"});
    } else {
      $HTMLPlugin->grow_string({string=>" none "});
    }
  }
  $HTMLPlugin->end_table();
  return $HTMLPlugin->{HTMLString};
}

#sub draw_tree {
#  my $self=shift;
#  my $acc=shift;
#  my $depth=shift;
#  my @parents;
#  my $graphs_h;
#  my $count;
#  my $parents;
#  my $HTMLString;

#  $HTMLString .= "<table border=1 cellpadding=5>";
#  $HTMLString .= "<th>Parents:</th><th>Term:</th><th>Descendants:</th>";
#  $HTMLString .= "<tr><td valign=top>";

#  if (not defined($self->{parents})) {
#    $self->_get_parents($acc, 'parents');
#  }

#  $HTMLString .= $self->draw_parents($self->{parents}) ."</td><td valign=top>";


#  $HTMLString .= $self->draw_selected_term($acc) . "</td><td valign=top>";

#  $self->_get_children($acc, 'children', $depth);

#  $HTMLString  .= $self->draw_tree($self->{children}, $depth);

#  $HTMLString .= "</td></tr></table><br>";
  
#  return $HTMLString;
 

#}

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
  $HTMLString .= "<table border=0 cellpadding=5>";
  if (defined $self->{parents}[0]->[-1]) {
    $self->_get_children($self->{parents}[0]->[-1]->{acc}, 'siblings', $depth);
    $HTMLString .= "<td>" . $self->draw_tree($self->{siblings}, $depth);
  } else {
    $HTMLString .= "<td>";
  }
  $HTMLString .= "</td></tr></table><br>";
  
  return $HTMLString;
  

}

sub search {
  my $self=shift;
  my $dbh = shift;
  my $search_term = shift;
  my $HTMLString;
  
  my $query = $dbh->get_terms({search => $search_term});
  if (!$query->[0]->{name}) {confess ("no hits");}
  foreach my $q (@{$query}) {
    $HTMLString .= "<a href=main?accession=$q->{acc}&$self->{urlpost}>$q->{name}</a>";
    $HTMLString .= "<p>";
  }
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
