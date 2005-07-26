# $Id$
#
# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

  GO::IO::ProtegeRDF;

=head1 SYNOPSIS

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_term({acc=>00003677});

    #### ">-" is STDOUT
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::ProtegeRDF(-output=>$out);
    $xml_out->start_document();
    $xml_out->draw_term($term);
    $xml_out->end_document();

OR:

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_node_graph(-acc=>00003677, -depth=>2);
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::ProtegeRDF(-output=>$out);
    $xml_out->start_document();
    $xml_out->draw_node_graph($term, 3677);
    $xml_out->end_document();

=head1 DESCRIPTION

Utility class to dump GO terms as xml.  Currently you just call
start_ducument, then draw_term for each term, then end_document.

If there's a need I'll add draw_node_graph, draw_node_list, etc.


=cut

package GO::IO::ProtegeRDF;
use strict;
use GO::Utils qw(rearrange);
use XML::Writer;
use base qw(GO::IO::ProtegeRDFS);

=head2 start_document

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
	 <!ENTITY go 'http://www.geneontology.org/go#'>
			     ]",
			     
			     );
    $self->{writer}->startTag(
			      'rdf:RDF',
			      "xmlns:rdf"=>'&rdf;',
			      "xmlns:go"=>'&go;',
			      );

#    if (defined ($timestamp)) {
#	$self->{writer}->emptyTag('go:version', 'timestamp'=>$timestamp);
#    }

}

sub end_document{
    my $self = shift;

    $self->{writer}->endTag('rdf:RDF');
}
 

sub draw_node_graph {
    my $self = shift;
    my ($graph, $focus, $show_associations, $show_terms, $show_xrefs) =
	rearrange([qw(graph focus show_associations show_terms show_xrefs)], @_);
    
    my %prodh;

    foreach my $term (@{$graph->get_all_nodes}) {
	foreach my $assoc (@{$term->association_list}) {
	    $self->{writer}->startTag("go:".$self->_rdfname($term),
				      "rdf:about"=>"&go;assoc".$assoc->id);
	    $self->{writer}->startTag("go:product",
			    'rdf:resource'=>
			    '&go;prod'.$assoc->gene_product->id);
	    $self->{writer}->endTag("go:product");
	    $self->{writer}->endTag("go:".$self->_rdfname($term));
	    $prodh{$assoc->gene_product->id} = $assoc->gene_product;
	}
    }
    foreach my $prod (values %prodh) {
	$self->{writer}->startTag("go:GeneProduct",
				  "rdf:about"=>"&go;prod".$prod->id,
				  "go:symbol"=>$prod->symbol);
	$self->{writer}->endTag("go:GeneProduct");
    }
}


1;







