# $Id$
#
# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/local/bin/perl5.6.0 -w
package GO::IO::XML;

=head1 NAME

  GO::IO::XML;

=head1 SYNOPSIS

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_term({acc=>00003677});

    #### ">-" is STDOUT
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::XML->new(-output=>$out);
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

use strict;
use GO::Utils qw(rearrange);
use XML::Writer;

=head2 new

    Usage   - my $xml_out = GO::IO::XML->new(-output=>$out);
    Returns - None
    Args    - Output FileHandle

Initializes the writer object.  To write to standard out, do:

my $out = new FileHandle(">-");
my $xml_out = new GO::IO::XML(-output=>$out);

=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my ($out) =
	rearrange([qw(output)], @_);

    $out = new FileHandle(">-") unless $out;
    my $gen = new XML::Writer(OUTPUT=>$out);    
    $self->{writer} = $gen;

    $gen->setDataMode(1);
    $gen->setDataIndent(4);

    return $self;
}

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
    $self->{writer}->doctype("go:go", 
			     '-//Gene Ontology//Custom XML/RDF Version 2.0//EN',
			     'http://www.godatabase.org/dtd/go.dtd');
    $self->{writer}->startTag('go:go', 
		   'xmlns:go'=>'http://www.geneontology.org/dtds/go.dtd#',
		   'xmlns:rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#');

    if (defined ($timestamp)) {
	#$self->{writer}->emptyTag('go:version', 'timestamp'=>$timestamp);
    }
    $self->{writer}->startTag('rdf:RDF');

}


=head2 end_document

    Usage   - $xml_out->end_document();

Call this when done.

=cut

sub end_document{
    my $self = shift;

    $self->{writer}->endTag('rdf:RDF');
    $self->{writer}->endTag('go:go');    
}
 
=head2 draw_node_graph

    Usage   - $xml_out->draw_node_graph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut

   
sub draw_node_graph {
    my $self = shift;
    my ($graph, $focus, $show_associations, $show_terms, $show_xrefs) =
	rearrange([qw(graph focus show_associations show_terms show_xrefs)], @_);
    
    my $is_focus;
    
    foreach my $term (@{$graph->get_all_nodes}) {
      $is_focus = $self->__is_focus(-node_list=>$graph->focus_nodes,
				    -term=>$term
				   );
      $self->draw_term(-term=>$term, 
		       -graph=>$graph,
		       -focus=>$is_focus, 
		       -show_associations=>$show_associations,
		       -show_terms=>$show_terms,
		       -show_xrefs=>$show_xrefs
		      );
    }
}

sub __is_focus {
  my $self = shift;
  my ($node_list, $term) =
    rearrange([qw(node_list term)], @_);
  
  foreach my $node (@$node_list) {
    if ($node->acc eq $term->acc) {
      return "yes";
    } 
  }
      return "no";
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
    
    $show_terms = $show_terms || "";
    $is_focus = $is_focus || "";
    $show_xrefs = $show_xrefs || "";

    if ($show_terms ne 'no') {
      if ($is_focus eq "yes") {
	$self->{writer}->startTag('go:term', 
				  'focus'=>'yes', 
				  'rdf:about'=>'http://www.geneontology.org/go#'.$term->public_acc,
				  'n_associations'=>$term->n_deep_products
				 );
      } else {
	$self->{writer}->startTag('go:term', 
				  'rdf:about'=>'http://www.geneontology.org/go#'.$term->public_acc,
				  'n_associations'=>$term->n_deep_products
				 );
      }
      $self->{writer}->startTag('go:accession');
      $self->characters($term->acc);
      $self->{writer}->endTag('go:accession');
      $self->dataElement('go:name', $term->name);
      
      if ($term->synonym_list) {
	foreach my $syn (sort @{$term->synonym_list}) {
	  $self->{writer}->startTag('go:synonym');
	  $self->characters($syn);  
	  $self->{writer}->endTag('go:synonym');
	}	
      }
      if ($term->definition) {
	$self->dataElement('go:definition', 
			   $term->definition);
      };
      if (defined $graph) {
	foreach my $rel (sort by_acc1 @{$graph->get_parent_relationships($term->acc)}) {
	  if (lc($rel->type) eq 'partof') {
	    $self->{writer}->emptyTag('go:part-of', 
				      'rdf:resource'=>"http://www.geneontology.org/go#"
				      .$self->__make_go_from_acc($rel->acc1));
	  } else {
	    $self->{writer}->emptyTag("go:".$rel->type, 
				      'rdf:resource'=>"http://www.geneontology.org/go#"
				      .$self->__make_go_from_acc($rel->acc1));
	  }
	}    
      }
      
      if ($show_xrefs ne 'no') {
	  if ($term->dbxref_list) {
	      if (scalar(@{$term->dbxref_list}) > 0) {
		  foreach my $xref (sort by_xref_key @{$term->dbxref_list}) {
		      $self->{writer}->startTag('go:dbxref',
					       'rdf:parseType'=>'Resource');
		      $self->{writer}->startTag('go:database_symbol');
		      $self->characters($xref->xref_dbname);
		      $self->{writer}->endTag('go:database_symbol');
		      $self->{writer}->startTag('go:reference');
		      $self->characters($xref->xref_key);
		      $self->{writer}->endTag('go:reference');
		      $self->{writer}->endTag('go:dbxref');
		  }
	      }
	  }
      }
      
      if (defined ($term->selected_association_list)) {
	foreach my $selected_ass (sort by_gene_product_symbol @{$term->selected_association_list}) {
	  $self->__draw_association($selected_ass, 1);
	}
      }
      
      if ($show_associations eq 'yes') {
	foreach my $ass (sort by_gene_product_symbol @{$term->association_list}) { 
	  $self->__draw_association($ass, 0);
	}	
      }
      $self->{writer}->endTag('go:term');
    } else {
      if (defined ($term->selected_association_list)) {
	foreach my $selected_ass (sort by_gene_product_symbol @{$term->selected_association_list}) {
	  $self->__draw_association($selected_ass, 1);
	}
      }
    }
    
}

sub by_acc1 {
  lc($a->acc1) cmp lc($b->acc1);

}

sub by_xref_key {
  lc($a->xref_key) cmp lc($b->xref_key);
}

sub by_gene_product_symbol {
  lc($a->gene_product->symbol) cmp lc($b->gene_product->symbol);

}

sub __draw_association {
  my $self = shift;
  my $ass = shift;
  my $is_selected = shift;
  
  my $rdf_id = 'http://www.geneontology.org/go#'.$ass->go_public_acc;


  if ($is_selected) {
    $self->{writer}->startTag('go:association', 
			      'selected'=>'yes',
			      'rdf:parseType'=>'Resource'
			     );	  

  } else {
    $self->{writer}->startTag('go:association', 
			      'rdf:parseType'=>'Resource'
			     );

  }
  foreach my $ev (@{$ass->evidence_list}) {
    $self->{writer}->startTag('go:evidence', 'evidence_code'=>$ev->code);
    if (defined($ev->xref)) {
      $self->{writer}->startTag('go:dbxref',
			       'rdf:parseType'=>'Resource');
      $self->{writer}->startTag('go:database_symbol');
      $self->characters($ev->xref->xref_dbname);
      $self->{writer}->endTag('go:database_symbol');
      $self->{writer}->startTag('go:reference');##, 'type'=>$ev->xref->xref_keytype);
      $self->characters($ev->xref->xref_key);
      $self->{writer}->endTag('go:reference');
      $self->{writer}->endTag('go:dbxref');
    }
    $self->{writer}->endTag('go:evidence');
  }
  $self->{writer}->startTag('go:gene_product',
			   'rdf:parseType'=>'Resource');
  $self->dataElement('go:name', $ass->gene_product->symbol);
  $self->{writer}->startTag('go:dbxref',
			   'rdf:parseType'=>'Resource');
  $self->dataElement('go:database_symbol', $ass->gene_product->speciesdb);
  $self->dataElement('go:reference', $ass->gene_product->acc);
  $self->{writer}->endTag('go:dbxref');
  $self->{writer}->endTag('go:gene_product');   
  $self->{writer}->endTag('go:association');
  
}

=head2 

sub characters

  This is simply a wrapper to XML::Writer->characters
  which strips out any non-ascii characters.

=cut

sub characters {
  my $self = shift;
  my $string = shift;
  
  if ($string) {
      $self->{writer}->characters($self->__strip_non_ascii($string));
  }
  
}

=head2 

sub dataElement

  This is simply a wrapper to XML::Writer->dataElement
  which strips out any non-ascii characters.

=cut

sub dataElement {
  my $self = shift;
  my $tag = shift;
  my $content = shift;

  $self->{writer}->dataElement($tag,
			       $self->__strip_non_ascii($content));
  
}

sub __strip_non_ascii {
  my $self = shift;
  my $string = shift;

  $string =~ s/\P{IsASCII}//g;

  return $string;
}

sub __make_go_from_acc {
  my $self = shift;
  my $acc = shift;
  return $acc;
}

1;




