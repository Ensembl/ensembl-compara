# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#

package GO::Model::TreeIterator;

=head1 NAME

  GO::Model::GraphIterator;

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a hack.  It wraps GO::Model::GraphIterator and provides
a tree like iteration, rather than a graph-like iteration.

This is done by giving TreeIterator a template array.

The array looks like this :

[
[3674, 'isa', 3673],
[9277, 'isa', 5618]
]

3674 is selected iff its the child 
of 3674.  9277 is selected iff it  return \@list;
s
the child of 5618.

=cut


use Carp;
use strict;
use Exporter;
use FreezeThaw qw(freeze thaw);
use GO::Utils qw(rearrange);
use GO::Model::Graph;
use GO::Model::GraphNodeInstance;
use FileHandle;
use Exporter;
use Data::Dumper;
use vars qw(@EXPORT_OK %EXPORT_TAGS);

use base qw(GO::Model::Root Exporter);

sub _valid_params {
    return qw(graph order sort_by noderefs direction no_duplicates reltype_filter visited arcs_visited);
}

=head2 order

  Usage   - $graphiter->order("breadth");
  Returns - string
  Args    - string

gets/sets traversal order; breadth or depth; default is depth

=cut

=head2 direction

  Usage   - $graphiter->direction("up");
  Returns - string
  Args    - string

gets/sets direction; default is "down"

=cut

#sub _initialize {
#    my $self = shift;
#    my $acc;
#    if (!ref($_[0])) {
#        $acc = shift;
#    }
#    $self->SUPER::_initialize(@_);
#    $self->reset_cursor($acc);
#}


sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->{'graph'} = shift;
  $self->{'selected_array'} = shift;
  $self->{'show_kids'} = shift;
  $self->{'closed_below'} = shift;
  $self->{'nit'} = $self->{'graph'}->create_iterator;
  $self->{'bootstrap_mode'} = 0;
#  $self->SUPER::_initialize(@_);
#  $self->{'current_path'};
  $self->{'nit'}->reset_cursor();
  return $self;
}


=head2 reset_cursor

  Usage   -
  Returns - GO::Model::Term
  Args    -

=cut

sub reset_cursor {
    my $self = shift;

    $self->{'nit'}->reset_cursor();
} 

=head2 next_node

  Usage   -
  Returns - GO::Model::Term
  Args    -

=cut

sub next_node {
    my $self = shift;
    my $ni = $self->next_node_instance;
    return $ni ? $ni->term : undef;
} 

=head2 set_bootstrap_mode

  Usage   -
  Returns - 
  Args    -

=cut

sub set_bootstrap_mode {
    my $self = shift;
   
  $self->{'bootstrap_mode'} = 1;
}

=head2 get_bootstrap_mode

  Usage   -
  Returns - 
  Args    -

=cut

sub get_bootstrap_mode {
    my $self = shift;
   
  return $self->{'bootstrap_mode'};
}

=head2 get_current_path

  Usage   -
  Returns - array ref
  Args    - none

=cut

sub get_current_path {
  my $self = shift;
  return $self->{'current_path'};
}

=head2 next_node_instance

  Usage   -
  Returns - GO::Model::GraphNodeInstance
  Args    -

=cut

sub next_node_instance {
  my $self = shift;

  my $current_coords = $self->{'current_coords'} || [];
  my $nit = $self->{'nit'};
  my $previous_depth = $self->{'previous_depth'} || 1;
  my $parent_array = $self->{'current_path'};

  my $ni = $nit->next_node_instance;
  if ($ni) {
    my $depth = $ni->depth;
    if ($previous_depth == $depth) {
      @$parent_array->[$depth] = $ni->term->public_acc;
    } elsif ($previous_depth > $depth) {
      while ($previous_depth > $depth) {
	$previous_depth -= 1;
	pop @$parent_array;
      }
      @$parent_array->[$depth] = $ni->term->public_acc;
    } elsif ($previous_depth < $depth) {
      push @$parent_array, $ni->term->public_acc;
    }

    $self->{'previous_depth'} = $ni->depth;
    $self->{'current_path'} = $parent_array;

    if ($self->get_bootstrap_mode) {
      return $ni;
    }
    
    if ($self->should_draw_below($parent_array)) {
      return $ni;
    } else {
	$self->next_node_instance;
    }
  } else {
    return 0;
  }
}

sub should_draw_below {
  my $self = shift;
  my $current_coords = shift;
  my $coord_list = $self->{'selected_array'};
  
  foreach my $coords (@$coord_list) {
    if (scalar(@$current_coords) <= scalar(@$coords)) {
      my $result = 1;
      my $i = 0;
      my $length;
      while ($i < scalar(@$current_coords)) {
	if (@$coords->[$i] ne @$current_coords->[$i]) {
	  $result = 0;
	}
      } continue {
	$i++;
      }
      if ($result == 1) {
	return 1;
      }
    } elsif (scalar(@$current_coords) > scalar(@$coords)) {
      my $i = 0;
      my $test = 1;
      while ($i < scalar(@$coords)) {
	if (@$current_coords->[$i] ne @$coords->[$i]) {
	  $test = 0;
	}
      } continue {
	$i++;
      }
	if ($test) {
	  my $parent_coords;
	  foreach my $anc(@$current_coords) {
	    push @$parent_coords, $anc;
	  }
	  pop @$parent_coords;
	  if ($self->is_selected($parent_coords, 'show_kids')) {
	    return 1;
	  }
	}
    }
  }
  return 0;
}


sub close_below {
    my $self = shift;
    my $closed_array = $self->{"closed_below"};
    
    foreach my $closed (@$closed_array) {
	$self->{'selected_array'} = $self->delete_array($closed);
    }
    foreach my $closed (@$closed_array) {
	$self->{'show_kids'} = $self->delete_array($closed, 'show_kids');
    }
}

sub delete_array {
    my $self = shift;
    my $parent_array = shift;
    my $array_to_test_against = shift || 'selected_array';


    my $selected_array = $self->{$array_to_test_against};
    my @two_d_array;

    foreach my $arr(@$selected_array) {
	my $test = 1;
	if (scalar(@$arr) >= scalar(@$parent_array)) {
	my $i = 0;
	while ($i < scalar(@$parent_array)) {
	    if (@$parent_array->[$i] ne @$arr->[$i]) {
		$test = 0;
	    }
	} continue {
	    $i++;
	}
    } else {
	$test = 0;
    }
	if ($test != 1) {
	    push @two_d_array, $arr;
	} else {
	}
    }
    return \@two_d_array;
}

sub is_selected {
  my $self = shift;
  my $parent_array = shift;
  my $array_to_test_against = shift || 'selected_array';

  my $selected_array = $self->{$array_to_test_against};

  foreach my $arr(@$selected_array) {
    if (scalar(@$arr) eq scalar(@$parent_array)) {
      my $i = 0;
      my $test = 1;
      while ($i < scalar(@$arr)) {
	if (@$parent_array->[$i] ne @$arr->[$i]) {
	  $test = 0;
	}
      } continue {
	$i++;
      }
      if ($test == 1) {
	return 1;
      }
    }
  }
  return 0;
}

1;





