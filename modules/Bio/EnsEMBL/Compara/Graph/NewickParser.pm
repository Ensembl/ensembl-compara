=head1 NAME

NewickParser - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

Module which implements a newick string parser as a finite state machine which enables it
to parse the full Newick specification.  Module does not need to be instantiated, the method
can be called directly.

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Graph::NewickParser;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);


###########################
# NEWICK PARSING
###########################

=head2 parse_newick_into_tree

  Arg [1]    : <string> newick formated string
  Example    : $link = new Bio::EnsEMBL::Compara::Graph::Link($node1, $node2);
  Description: parses newick string into a 
  Returntype : Bio::EnsEMBL::Compara::NestedSet object which is the root of the tree
  Exceptions : none

=cut


sub parse_newick_into_tree
{
  my $newick = shift;

  my $count=1;
  my $debug = 0;
  print("$newick\n") if($debug);
  my $token = next_token(\$newick, "(;");
  my $lastset = undef;
  my $node = undef;
  my $root = undef;
  my $state=1;
  my $bracket_level = 0;

  while($token) {
    if($debug) { printf("state %d : '%s'\n", $state, $token); };
    
    switch ($state) {
      case 1 { #new node
        $node = new Bio::EnsEMBL::Compara::NestedSet;
        $node->node_id($count++);
        $lastset->add_child($node) if($lastset);
        $root=$node unless($root);
        if($token eq '(') { #create new set
          printf("    create set\n")  if($debug);
          $token = next_token(\$newick, "[(:,)");
          $state = 1;
          $bracket_level++;
          $lastset = $node;
        } else {
          $state = 2;
        }
      }
      case 2 { #naming a node
        if(!($token =~ /[:,);]/)) { 
          $node->name($token);
          if($debug) { print("    naming leaf"); $node->print_node; }
          $token = next_token(\$newick, "[:,);");
        }
        $state = 3;
      }
      case 3 { # optional : and distance
        if($token eq ':') {
          $token = next_token(\$newick, "[,);");
          $node->distance_to_parent($token);
          if($debug) { print("set distance: $token"); $node->print_node; }
          $token = next_token(\$newick, ",);"); #move to , or )
        } elsif ($token eq '[') { # NHX tag without previous blength
          $token .= next_token(\$newick, ",);");
        }
        $state = 4;
      }
      case 4 { # optional NHX tags
        if($token =~ /\[\&\&NHX\:(\S+)\]/) {
            # careful: this regexp gets rid of all NHX wrapping in one step
            $token =~ s|\[\&\&NHX\:(\S+)\]|$1|;
            my @attributes = split ':', $token;
            foreach my $attribute (@attributes) {
                my($key,$value) = split '=', $attribute;
                # we assume only one value per key
                $node->add_tag("$key","$value");
            }
          # $token = next_token(\$newick, ",);");
          #$node->distance_to_parent($token);
            if($debug) { print("NHX tags: $token"); $node->print_node; }
            $token = next_token(\$newick, ",);"); #move to , or )
        }
        $state = 5;
      }
      case 5 { # end node
        if($token eq ')') {
          if($debug) { print("end set : "); $lastset->print_node; }
          $node = $lastset;        
          $lastset = $lastset->parent;
          $token = next_token(\$newick, ":,);");
          $state=2;
          $bracket_level--;
        } elsif($token eq ',') {
          $token = next_token(\$newick, "(:,)");
          $state=1;
        } elsif($token eq ';') {
          #done with tree
          throw("parse error: unbalanced ()\n") if($bracket_level ne 0);
          $state=13;
          $token = next_token(\$newick, "(");
        } else {
          throw("parse error: expected ; or ) or ,\n");
        }
      }

      case 13 {
        throw("parse error: nothing expected after ;");
      }
    }
  }
  return $root;
}


sub next_token {
  my $string = shift;
  my $delim = shift;
  
  $$string =~ s/^(\s)+//;

  return undef unless(length($$string));
  
  #print("input =>$$string\n");
  #print("delim =>$delim\n");
  my $index=undef;

  my @delims = split(/ */, $delim);
  foreach my $dl (@delims) {
    my $pos = index($$string, $dl);
    if($pos>=0) {
      $index = $pos unless(defined($index));
      $index = $pos if($pos<$index);
    }
  }
  unless(defined($index)) {
    throw("couldn't find delimiter $delim\n");
  }

  my $token ='';

  if($index==0) {
    $token = substr($$string,0,1);
    $$string = substr($$string, 1);
  } else {
    $token = substr($$string, 0, $index);
    $$string = substr($$string, $index);
  }

  #print("  token     =>$token\n");
  #print("  outstring =>$$string\n\n");
  
  return $token;
}


1;
