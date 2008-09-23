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


sub search {
  my $self  = shift;
  my $obj   = $self->{'object'};
  return unless @{$obj->Obj};
  my $species = $obj->Obj->[0]->{'species'};
  my $idx     = $obj->Obj->[0]->{'idx'};
  $self->set_title( "Search results" );
  if( my $panel1 = $self->new_panel( '',
    'code'    => "info#",
    'caption' => "Search results for $species $idx"
  )) {
    $panel1->add_components(qw(
      results     EnsEMBL::Web::Component::Search::results
    ));
    $self->add_panel( $panel1 );
  }
}

sub populate_tree {
    my $self = shift;
    $Data::Dumper::Maxdepth = 2;
    my $exa_obj = $self->object->Obj;
#    my $renderer = new ExaLead::Renderer::HTML( $exa_obj );
    my %seen_results;
    my $menu;
    foreach my $group ( $exa_obj->groups ) {
	my $name = $group->name;
	$name =~ s/answergroup\.//;
	next if ($name eq 'Source');
#	warn Dumper($group);
	my $c = $group->children;
#	warn "name = $name";
#	my $menu = $self->create_submenu( "$name", $name );
	$menu = $self->create_node( "$name", "$name ($c)",
				    [qw(summary EnsEMBL::Web::Component::Search::Summary)],
				    {'availability' => 1, 'url'=> "Search/params?$name"} );
	foreach my $category1 ( sort {$a->name cmp $b->name} $group->children ) {
	    my $name1 = $category1->name;
	    my $c1 = $category1->count;
#	    warn "name1 = $name1";
	    my $menu1 = $self->create_node ( "$name:$name1", "$name1 ($c1)",
					     [qw(summary EnsEMBL::Web::Component::Search::Summary)],
					     {'availability' => 1, 'url'=> "Search/params?$name:$name1"} );
	    $menu->append($menu1);
	    foreach my $category2 ( sort {$a->name cmp $b->name} $category1->children ) {
		my $name2 = $category2->name;
		my $c2 = $category2->count;
		my $menu2 = $self->create_node( "$name:$name1:$name2", "$name2 ($c2)",
						[qw(summary EnsEMBL::Web::Component::Search::Summary)],
						{'availability' => 1, 'url'=> "Search/params?$name:$name1:$name2"} );
		$menu1->append($menu2);
#		warn "name2 = $name2";
	    }
	}
    }
}


1;
