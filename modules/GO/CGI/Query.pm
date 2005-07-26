=head1 SYNOPSIS

package GO::CGI::Query

=head2  Usage

use CGI 'param';
my $q = new CGI;   
my $params = $q->Vars;

my $data = GO::CGI::Query->do_query(-params=>$params);

my $writer = GO::CGI::HTML->drawDetails(
					-output=>$out,
				     	-data=>$data,
				       	-params=>$params
				       	);
  


=head2 do_query

  Arguments - $CGI->Vars
  returns   - GO::Model::Graph

  Takes a hash of parameters from CGI.pm and 
  returns:
    if view=query - list of GO::Model::Term
    Tree view  - GO::Model::Graph

=cut

package GO::CGI::Query;

use GO::Utils qw(rearrange);
use strict;

sub do_query {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  
  my $apph = $session->apph;
  unless (%param_hash->{'search_constraint'} eq 'gp' && 
      %param_hash->{'action'} ne 'query') {
      $self->setApphFilters(-session=>$session);
  }
  
  if (%param_hash->{'view'} eq 'query') {
    if (%param_hash->{'search_constraint'} eq 'gp') {
      return $self->getGeneProductList(-session=>$session);
    } else {
      return $self->getTermList(-session=>$session);
    }
  } elsif (%param_hash->{'view'} eq 'details') {
    if (%param_hash->{'action'} eq 'summary') {
      return $self->get_current_state_node_graph($session);
    } elsif (%param_hash->{'action'} eq 'dotty' &&
	     %param_hash->{'draw'} eq 'current'
	    ) {
      return $self->get_current_state_node_graph($session);
    } elsif (%param_hash->{'search_constraint'} eq 'gp') {
      if (%param_hash->{'format'} eq 'fasta') {
	return $self->getProductsByAcc(-session=>$session);
      } else {
	return $self->getTermsByProductAcc(-session=>$session);
      }
    } else {
      return $self->getNodeGraph(-session=>$session);
    }
  } else {
    return $self->getNodeGraph(-session=>$session);
  }
}

=head2 getNodeGraph

  Arguments - -session=>$session
  returns   - GO::Model::Graph

=cut

sub getNodeGraph{
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  
  my $apph = $session->apph;

  #  Decide if we're looking for gene products or term names.
  #  Then set the search case and search parameters.
  
  my @query = split('\0', %param_hash->{'query'});
  
  my $case;
  my @term_list = ();
  my @search_list = ();
  my $accession = %param_hash->{'query'};

  if (%param_hash->{'search_constraint'} eq 'gp') {
    my $term_list = $self->getGeneProductList(-session=>$session);
    @term_list = @$term_list;
  } 
  elsif ($session->get_param('view') eq 'details'){
    my $terms = $apph->get_terms({acc=>$session->get_param_values('open_0')});
    my $graph = $apph->get_graph_by_terms($terms, 0);
    return $graph;
  }
  elsif ($session->get_param('view') eq 'imago_details') {
    my $terms = $apph->get_terms({acc=>$session->get_param_values('open_0')});
    my $graph = $apph->get_graph_by_terms($terms, 10);
    return $graph;
  }
  elsif ($session->get_param('view') eq 'gp_details') {
    my $term_list = $self->getGeneProductList(-session=>$session);
    @term_list = @$term_list;
  } else {
    return $self->get_current_state_node_graph($session);
  }
}

sub get_current_state_node_graph {
  my $self = shift;
  my $session = shift;
  my @term_list = ();
  my @search_list = ();
  my $apph = $session->apph;
  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  my @query = split('\0', %param_hash->{'query'});

  #rockfish
  #$self->setApphFilters(-session=>$session);

  if ($session->get_param('open_0')) {
    my $accs = $session->get_param_values('open_0');
    my @new_accs;
    foreach my $acc(@$accs) {
      my @other_acc = split ',', $acc;
      push @new_accs, @other_acc->[scalar(@other_acc) - 1];
    }
    my $terms = $apph->get_terms({acc=>\@new_accs});
    my $graph = $apph->get_graph_by_terms($terms, 0);
    foreach my $term (@{$session->get_param_values('open_1') || []}) {
      my @other_acc = split ',', $term;
      my $new_term = @other_acc->[scalar(@other_acc) - 1];
      $apph->extend_graph($graph, $new_term, 1);
    }
    if ($session->get_param('graph_view') ne 'tree') {
      foreach my $close_below (@{$session->get_param_values('closed') || []}) {
	eval {
	  $graph->close_below($close_below);
	};
      }
    }
    return $graph;
  }
  elsif ($session->get_param('open_1')) {
    my $accs = $session->get_param_values('open_1');
    my @new_accs;
    foreach my $acc(@$accs) {
      my @other_acc = split ',', $acc;
      push @new_accs, @other_acc->[scalar(@other_acc) - 1];
    }
    my $terms = $apph->get_terms({acc=>\@new_accs});
    my $graph = $apph->get_graph_by_terms($terms, 1);
    if ($session->get_param('graph_view') ne 'tree') {
      foreach my $close_below (@{$session->get_param_values('closed') || []}) {
	eval {
	  $graph->close_below($close_below);
	};
      }
    }
    return $graph;
  } else {
    foreach my $query(@query){
      # queries like GO:0003700
      if ($query =~ m/^GO:?/) {
	$query =~ s/^GO:0*//;
	push @term_list, $query;
	# Text searches like 'apopt'
      } elsif ($query =~ m/[a-zA-Z]/) {
	# OK, this is backwards, but for now I'm just dealing.
	if (%param_hash->{'auto_wild_cards'} ne 'yes' ) {
	  $query = '*' . $query . '*';
	}
	eval {
	  my $add_acc_list = $apph->__get_accs_from_search(
							   -session=>$session,
							   -query=>$query
							  );
	  push @term_list, @$add_acc_list;
	};
	# queries like 3700
      } else {
	push @term_list, $query;
      }
    }
  }

  my $ass = %param_hash->{'show_gene_associations'};
  my $depth;
  if (defined(%param_hash->{'depth'})) {
    $depth = %param_hash->{'depth'};
  } else {
    $depth = 0;
  }

  my $data;
  if (scalar(@term_list) != 0 ){
    my @close_below = split ('\0', $session->get_param_hash->{'closed'});
    my @second_level_addons;


    my $terms = $apph->get_terms({acc=>\@term_list});
    $data = $apph->get_graph_by_terms($terms, 
				      $depth);
    foreach my $close (@close_below) {
      eval {
	$data->close_below($close);
      };
    }
  }
  return $data;
}

sub __is_inside {
    my $self = shift;
    my ($acc, $array) = @_;

    foreach my $node(@$array) {
	if ($acc == $node) {
	    return 1;
	}
    }
    return 0;
}

sub getProductsByAcc {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  my $apph = $session->apph;
  my @products;
  foreach my $product (split "\0", %param_hash->{'gp'}) {
    my $terms = $apph->get_product({acc=>$product});
    push @products, $terms;
  }
  return \@products;
}

sub getTermsByProductAcc {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  my $apph = $session->apph;
  my @products;
  foreach my $product (split "\0", %param_hash->{'gp'}) {
    my $terms = $apph->get_terms({product=>{acc=>$product}});
    push @products, @{$terms};
  }
  return \@products;
}

=head2 getGeneProductList

  Arguments - -session=>$session
  returns   - List of GO::Model::Term

=cut


sub getGeneProductList{
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  my $apph = $session->apph;
  my @terms;

  if ($params->{'query'}) {
    my @query = split '\0', $params->{'query'};
    if ($params->{'auto_wild_cards'} ne 'yes' &&
	$params->{'gfields'} ne 'xrefs'
       ) {
      foreach my $query(@query) {
	$query = "*$query*";
      }
    }
    if ($params->{'gfields'} eq 'name') {
      foreach my $query(@query) {
	eval {
	  my @products = @{$apph->get_products({'full_name'=>$query})};
	  push @terms, @{$apph->get_terms({'products'=>\@products})};
	};
      }
    } elsif ($params->{'gfields'} eq 'symbol'){
      foreach my $query(@query) {
	eval {
	  my @products = @{$apph->get_products({'symbol'=>$query})};
	  push @terms, @{$apph->get_terms({'products'=>\@products})};
	};
      }
    } elsif ($params->{'synonyms'} eq 'xrefs'){
      foreach my $query(@query) {
	eval {
	  my @products = @{$apph->get_products({'synonym'=>$query})};
	  push @terms, @{$apph->get_terms({'products'=>\@products})};
	};
      }
    } elsif ($params->{'gfields'} eq 'xrefs'){
      foreach my $query(@query) {
	eval {
	  push @terms, @{$apph->get_terms({'products'=>{'xref'=>$query}})};
	};
      }
    } elsif ($params->{'gfields'} eq 'seq_acc'){
      foreach my $query(@query) {
	eval {
	    $query =~ s/\*//g;
	    my @products = @{$apph->get_products({'seq_acc'=>$query})};
	    if (scalar(@products) > 0) {
		push @terms, @{$apph->get_terms({'products'=>\@products})};
	    }
	};
      }
    } else {
      foreach my $query(@query) {
	my @products;
	eval {
#	  push @products, @{$apph->get_products({'full_name'=>$query})};
	};
	eval {
	  push @products, @{$apph->get_products({'symbol'=>$query})};
	};
	eval {
	  push @products, @{$apph->get_products({'synonym'=>$query})};
	};
	if (scalar(@products) > 0) {
	    push @terms, @{$apph->get_terms({'products'=>\@products})};
	}
      }
    }
  }
  return \@terms;
}

=head2 getTermList

  Arguments - -session=>$session
  returns   - List of GO::Model::Term

=cut


sub getTermList{
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  my $apph = $session->apph;
  my @query = split('\0', %param_hash->{'query'});
  my @term_list;

  if (%param_hash->{'search_constraint'} eq 'gp') {
    return $self->getGeneProductList(-session=>$session);
  } else {
    foreach my $term (@query) {
      if ($term =~ m/^GO:?/) {
	my $synonym_terms = $apph->get_terms({'search'=>$term});
	push @term_list, @$synonym_terms;
	$term =~ s/^GO:?//;
	my @temp_array;
	my $new_term = $apph->get_term({acc=>$term});
	if ($new_term) {
	    if ($new_term->name ne '') {
		@temp_array[0]= $apph->get_term({acc=>$term});
		push @term_list, @temp_array;
	    }
	}
    } elsif ($term =~ m/[a-zA-Z._]/) {
	$term =~ s/^\s*//;
	$term =~ s/\s*$//;
	if ($session->get_param('auto_wild_cards') ne 'yes') {
	      $term = "*$term*";
	    }
	my $term_l;
	my $search_fields = $session->get_param('fields');
	if ($search_fields) {
	    if ($search_fields eq 'all') {
		$term_l = $apph->get_terms({search=>$term});
	    } else {

		my $search_field_map = 
		{'name'=>'name,synynom',
		 'def'=>'name,synynom,definition',
		 'sp'=>'dbxref'
		 };
		$term_l = $apph->get_terms({
		    search=>$term, 	  
		    search_fields=>$search_field_map->{$search_fields}
		});
	    }
	} else {
	    $term_l = $apph->get_terms({search=>$term, search_fields=>'name,synonym'});
	}
	foreach my $t(@$term_l) {
	    if ($t->name ne '') {
		push @term_list, $t;
	    }
	}
	#push @term_list, @{$apph->get_terms_by_search(-search=>$term)};
      } else {
	my @temp_array;
	my $new_term = $apph->get_term({acc=>$term});
	if ($new_term) {
	  @temp_array[0]= $apph->get_term({acc=>$term});
	  if (@temp_array->[0]->name ne '') {
	    push @term_list, @temp_array;
	  }
	}
      }	
    }
  }
  return \@term_list;
}

=head2 setApphFilters

  Arguments - -session=>$session
  returns   - Nothing

Sets the filters for datasource and ev_code

=cut


sub setApphFilters{
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  

  my $params = $session->get_param_hash;
  my %param_hash = %$params;
  
  my $apph = $session->apph;

  #  TODO:  Make this use ! (negation)

  my @ev_codes = split ('\0', %param_hash->{'ev_code'});
  my @species_list = split ('\0', %param_hash->{'species_db'});

  my @e;
  my @s;

  if ($self->__is_in('all', \@species_list)) {
    #no filter
  }
  elsif (scalar(@species_list) > 0) {
    push @s, @species_list;
  } else {
    # no filter
  }

  if (scalar(@ev_codes) == 0 || $self->__is_in('ca', \@ev_codes)) {
      if ($session->get_param('IEAS_LOADED')) {
	  push @e, '!IEA';
      }
  } elsif ($self->__is_in('all', \@ev_codes)) {
    #no filter
  } else {
    push @e, @ev_codes;
  }
  
  if (scalar(@e) > 0) {
    if (scalar(@s) > 0) {
      $apph->filters({evcodes=>\@e,
		     speciesdb=>\@s});
    } else {
      $apph->filters({evcodes=>\@e});
    }
  } elsif (scalar(@s) > 0) {
    $apph->filters({speciesdb=>\@s});
} else {
    $apph->filters({});
}   
}


sub __is_in {
    my $self = shift;
    my ($acc, $array) = @_;

    foreach my $node(@$array) {
	if ($acc eq $node) {
	    return 1;
	}
    }
    return 0;
}


sub remove_focus_node {
  my $self = shift;
  my ($graph, $term) =
    rearrange([qw(graph term)], @_);

  my @new_array;
  foreach my $node(@{$graph->focus_nodes}) {
    if ($node->acc != $term && $node->acc) {
      push @new_array, $node;
    }
  }
  $graph->focus_nodes(\@new_array);

}

=head2 getSummaryGraph

    Usage   - GO::CGI::Query->getSummaryGraph(-session=>$session);
Returns - GO::Model::Graph;
    Args    -session=>$session, #GO::CGI::Session


=cut


sub getSummaryGraph {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

    $self->setApphFilters(-session=>$session);


    my $apph = $session->apph;
    
    my $accs = $session->get_param_values('open_1');
    my @new_accs;
    foreach my $acc(@$accs) {
	my @other_acc = split ',', $acc;
	push @new_accs, @other_acc->[scalar(@other_acc) - 1];
    }
    my $apph = $session->apph;
    my $terms = $apph->get_terms({acc=>\@new_accs});
    my $graph = $apph->get_graph_by_terms($terms, 1);
    foreach my $close_below (@{$session->get_param_values('closed') || []}) {
      eval {
	$graph->close_below($close_below);
      };
    }
    return $graph;
}



=head2 getSummaryInfo 

    Usage   - GO::CGI::Query->getSummaryInfo(-session=>$session);
    Returns - hashtable of $info->{$ont_acc}->{$db}->{'all'}
              or $info->{$ont_acc}->{'total'}->{'all'}
    Args    -session=>$session, #GO::CGI::Session


=cut

sub getSummaryInfo {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $apph = $session->apph;
  
  if ($session->get_param('query')) {
    my $query = $session->get_param('query');
    my $graph = $apph->get_graph($query, 1);
    
    my $children = $graph->get_child_relationships($query);
    
    my $info;
    %{$info}->{'label'} = $graph->get_term($query)->name;

    foreach my $child(@$children) {
      my $child_acc = $child->acc2;
      my $name = $graph->get_term($child_acc)->name;
      %{$info}->{$name}->{'is_leaf'} = scalar(@{$apph->get_relationships({parent_acc=>$child_acc})}); 
      %{$info}->{$name}->{'acc'} = $child_acc;
      %{$info}->{$name}->{'all'} = 
	$apph->get_deep_product_count({term=>$child_acc,
				       speciesdbs=>$session->get_param('species_db')});
    }
    return $info;
  } else {
    if (!$session) {
      require CGI;
      require GO::CGI::Session;
      
      my $q = new CGI;
      $session = new GO::CGI::Session(-q=>$q);
    }
    
    my $params = $session->get_param_hash;
    
    my $ont_list = $session->get_param('ont_summary_list') || 'GO:0003674|GO:0005575|GO:0008150';
    
    my @onts = split '\|', $ont_list;
    my $dbs = $apph->get_speciesdbs;

    my $info;
    
    foreach my $ont (@onts) {
      my $term = $apph->get_term_by_acc($ont);
      %{$info}->{$ont}->{'name'} = $apph->get_term_by_acc($ont)->name;
      %{$info}->{$ont}->{'total'}->{'all'} = $apph->get_deep_product_count({term=>$term});
      foreach my $db (@$dbs) {
	%{$info}->{$ont}->{$db}->{'all'} = $apph->get_deep_product_count({term=>$term,
									  speciesdbs=>$db});
      }
    }
    return $info;
  }
}


1;
















