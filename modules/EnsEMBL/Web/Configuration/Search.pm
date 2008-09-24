package EnsEMBL::Web::Configuration::Search;

use strict;
use base qw( EnsEMBL::Web::Configuration );
use ExaLead::Renderer::HTML;
use Data::Dumper;

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
#sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub populate_tree {
    my $self = shift;
    $Data::Dumper::Maxdepth = 2;
    my $exa_obj = $self->object->Obj;
    my %seen_results;
    my $menu;
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

	#prevent initial selection of a node by setting a hidden node to be active
	$menu = $self->create_node("","",[],{'no_menu_entry' => 1, 'active'=> 1} );

	my $url;
	if ($group->link( 'refine' )) {
	    $url = $group->link( 'refine' )->URL;
	}
	$menu = $self->create_node( "$name", "$name ($c)",
				    [qw(summary EnsEMBL::Web::Component::Search::Summary)],
				    {'availability' => 1, 'url'=> $url} );
	foreach my $category1 ( sort {$a->name cmp $b->name} $group->children ) {
	    my $name1 = $category1->name;
	    my $c1    = $category1->count;
	    my $url1;
	    if ($category1->link( 'refine' )) {
		$url1 = $category1->link( 'refine' )->URL;
	    }
	    my $menu1 = $self->create_node ( "$name:$name1", "$name1 ($c1)",
					     [qw(summary EnsEMBL::Web::Component::Search::Summary)],
					     {'availability' => 1, 'url'=> $url1} );
	    $menu->append($menu1);
	    foreach my $category2 ( sort {$a->name cmp $b->name} $category1->children ) {
		my $name2 = $category2->name;
		my $c2    = $category2->count;
		
		my $url2;
		if ($category2->link( 'refine' )) {
		    $url2 = $category2->link( 'refine' )->URL;
		}
		my $menu2 = $self->create_node( "$name:$name1:$name2", "$name2 ($c2)",
						[qw(summary EnsEMBL::Web::Component::Search::Summary)],
						{'availability' => 1, 'url'=> $url2 } );
		$menu1->append($menu2);
	    }
	}
    }
}


1;
