package EnsEMBL::Web::Configuration::Search;

use strict;
use base qw( EnsEMBL::Web::Configuration );
use ExaLead::Renderer::HTML;

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub context_panel  { return $_[0]->_context_panel;  }

#TO DO
# - check active flags work on child1
# - filters on child1 know nothing about filters on child2 which makes navigation not intuitive
#ie restrict on gene then on Felis cattus; now if gene filter is removed then the Felis catus filter is also lost
# - labels are often wider than the panel -> shoren species name when shorter than eg 6 characters ?
 
sub populate_tree {
    my $self = shift;
    my $menu;
    $self->set_title( '- text search' );
    my $exa_obj = $self->object->Obj;

    #are there any filters in place ?
    my $filtered_already = 0;
    foreach my $group ( $exa_obj->groups ) {
	foreach my $child ($group->children) {
	    if ($child->link( 'reset' )) {
		$filtered_already = 1;
	    }
	}
    }

    #prevent selection of a node when there is no filtering by setting a hidden node to be active
    unless ($filtered_already) {	    
	$menu = $self->create_node('top','Show all',
				   [],
				   {'no_menu_entry' => 1, 'active'=> 1} );
    }


    foreach my $group ( $exa_obj->groups ) {
	my $name = $group->name;
	$name =~ s/answergroup\.//;
	next if ($name eq 'Source');

	my $c;
	if ($name eq 'Feature type') {
	    foreach ($group->children) {
		$c += $_->count;
	    }
	}
	else { $c = scalar($group->children); }


	#create top level node
	$menu = $self->create_node( "$name", "$name ($c)",[],{});
	
	foreach my $child1 ( sort {$a->name cmp $b->name} $group->children ) {
	    my $name1 = $child1->name;
	    my $c1    = $child1->count;
	    my $disp_name = "$name1 ($c1)";
	    my $url1;
	    my $active = 0;
	    if ($child1->link( 'refine' )) {
		$url1 = $child1->link( 'refine' )->URL;
	    }
	    if ( $child1->link( 'reset' )) {
		$url1 = $child1->link( 'reset' )->URL;
		$disp_name = "$name1 [click to reset]";
		$active = 1;
	    }
	    my $menu1 = $self->create_node ( "$name:$name1", "$disp_name",
					     [qw(summary EnsEMBL::Web::Component::Search::Summary)],
					     {'availability' => 1, 'url'=> $url1, 'active' => $active} );
	    $menu->append($menu1);

	    foreach my $child2 ( sort {$a->name cmp $b->name} $child1->children ) {
		my $name2 = $child2->name;
		my $c2    = $child2->count;
		my $disp_name = "$name2 ($c2)";
		my $url2;
		if ($child2->link( 'refine' )) {
		    $url2 = $child2->link( 'refine' )->URL;
		}
		if ( $child2->link( 'reset' )) {
		    $url2 = $child2->link( 'reset' )->URL;
		    $disp_name = "$name2 [click to reset]"
		}
		my $menu2 = $self->create_node( "$name:$name1:$name2", "$disp_name",
						[qw(summary EnsEMBL::Web::Component::Search::Summary)],
						{'availability' => 1, 'url'=> $url2 } );
		$menu1->append($menu2);
	    }
	}
    }
}


1;
