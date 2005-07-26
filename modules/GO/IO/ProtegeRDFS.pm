# $Id$
#
# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::IO::XML;

=head1 SYNOPSIS

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_term({acc=>00003677});

    #### ">-" is STDOUT
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::XML(-output=>$out);
    $xml_out->start_document();
    $xml_out->draw_term($term);
    $xml_out->end_document();

OR:

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_node_graph(-acc=>00003677, -depth=>2);
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::XML(-output=>$out);
    $xml_out->start_document();
    $xml_out->draw_node_graph($term, 3677);
    $xml_out->end_document();

=head1 DESCRIPTION

Utility class to dump GO terms as xml.  Currently you just call
start_ducument, then draw_term for each term, then end_document.

If there's a need I'll add draw_node_graph, draw_node_list, etc.


=cut

package GO::IO::ProtegeRDFS;
use strict;
use GO::Utils qw(rearrange);
use XML::Writer;
use base qw(GO::IO::XML);

=head2 xml_header

    Usage   - $xml_out->xml_header;
    Returns - None
    Args    - None

start_document prints the "Content-type: text/xml" statement.
If creating a cgi script, you should call this before start_document.

=cut


sub xml_header {
    my $self = shift;
    
    print "Content-type: text/xml\n\n";

}



=head2 start_ducument

    Usage   - $xml_out->start_document(-timestamp=>$time);
    Returns - None
    Args    - optional: timestamp string, pre-formatted

start_ducument takes care of the fiddly bits like xml declarations,
namespaces, etc.  It draws the initial tags and leaves the document
ready to add go:term nodes.

=cut

sub start_document {
    my $self = shift;
    my ($timestamp) =
	rearrange([qw(timestamp)], @_);

    $self->{writer}->xmlDecl("UTF-8");

    $self->{writer}->doctype(
			     'rdf:RDF',
			     "",
			     "[
	 <!ENTITY rdf 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
	 <!ENTITY a 'http://protege.stanford.edu/system#'>
	 <!ENTITY go 'http://www.geneontology.org/go#'>
			     <!ENTITY rdfs 'http://www.w3.org/TR/1999/PR-rdf-schema-19990303#'>
			     ]",
			     
			     );
    $self->{writer}->startTag(
			      'rdf:RDF',
			      "xmlns:rdf"=>'&rdf;',
			      "xmlns:a"=>'&a;',
			      "xmlns:go"=>'&go;',
			      "xmlns:rdfs"=>'&rdfs;',
			      );

#    if (defined ($timestamp)) {
#	$self->{writer}->emptyTag('go:version', 'timestamp'=>$timestamp);
#    }

}

=head2 end_document

    Usage   - $xml_out->end_document();

Call this when done.

=cut

sub end_document{
    my $self = shift;

    $self->{writer}->dataElement("PROPERTIES");
    $self->{writer}->endTag('rdf:RDF');
}
 

=head2 draw_term

    Usage   - $xml_out->draw_term();
    Returns - None
    Args    -term=>$term, 
            -graph=>$graph, 
            -is_focus=>"yes" or "no",    ## optional
            -show_associations=>"yes" or "no",    ## optional
            -show_terms=>"yes" or "no",    ## optional, just draws associations
  

=cut


sub draw_term {
    my $self = shift;
    my ($term, $graph, $is_focus, $show_associations, $show_terms, $show_xrefs) =
	rearrange([qw(term graph focus show_associations show_terms show_xrefs)], @_);
    
    if ($show_terms ne 'no') {
	$self->{writer}->startTag(
				  'go:GONode', 
				  'rdf:about'=>'\&go;'.$self->_rdfname($term),
				  );

    }

    
    if ($term->synonym_list) {
	foreach my $syn (@{$term->synonym_list}) {
	    $self->{writer}->startTag('go:synonyms');
	    $self->characters($syn);  
	    $self->{writer}->endTag('go:synonyms');
	}	
    }
#    if ($term->definition ne '') {
#	$self->dataElement('go:definition', 
#			   $term->definition);
#    }
      
    if (defined $graph) {
	my $n_super = 0;
	my $n_rel = 0;
	foreach my $rel (@{$graph->get_parent_relationships($term->acc)}) {
	    my $parent = $graph->get_term($rel->acc1);
	    if ($rel->type eq 'isa') {
		$self->{writer}->dataElement('rdfs:subClassOf',
					     '',
					     'rdf:resource'=>
					     '&go;'.$self->_rdfname($parent));
		$n_super++;
	    }
	    else {
		$self->{writer}->dataElement('go:'.$rel->type,
					     '',
					     'rdf:resource'=>
					     '&go;'.$self->_rdfname($parent));
		$n_rel++;
	    }


	}

	if (!$n_super) {
	    if (!$n_rel) {
		$self->{writer}->dataElement('rdfs:subClassOf',
					     '',
					     'rdf:resource'=>
					     '&rdfs;Resource');
	    }
	    else {
		$self->{writer}->dataElement('rdfs:subClassOf',
					     '',
					     'rdf:resource'=>
					     '&go;GORoot');
	    }
	}

      
#      if ($show_xrefs ne 'no') {
#	foreach my $xref (@{$term->dbxref_list}) {
#	  $self->{writer}->startTag('go:dbxref');
#	  $self->{writer}->startTag('go:database_symbol');
#	  $self->characters($xref->xref_dbname);
#	  $self->{writer}->endTag('go:database_symbol');
#	  $self->{writer}->startTag('go:reference');
#	  $self->characters($xref->xref_key);
#	  $self->{writer}->endTag('go:reference');
#	  $self->{writer}->endTag('go:dbxref');
#	}
#      }
      
#      if (defined ($term->selected_association_list)) {
#	foreach my $selected_ass (@{$term->selected_association_list}) {
#	  $self->__draw_association($selected_ass, 1);
#	}
#      }
      
#      if ($show_associations eq 'yes') {
#	foreach my $ass (@{$term->association_list}) { 
#	  $self->__draw_association($ass, 0);
#	}	
#      }

	
    } else {
	if (defined ($term->selected_association_list)) {
	    foreach my $selected_ass (@{$term->selected_association_list}) {
		$self->__draw_association($selected_ass, 1);
	    }
	}
    }
    $self->{writer}->endTag('go:GONode');
    
}


sub _rdfname {
  my $self = shift;
  my $t = shift;
  if ($t->acc == 3673) {
      return "GORoot";
  }
  $_ = $t->name." ".$t->acc;
  s/ /_/g;
  s/\&//g;
  return $_;
#  return $t->name." - ".$t->public_acc;
#  return $t->public_acc;
}


1;







