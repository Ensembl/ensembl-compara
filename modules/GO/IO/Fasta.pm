# $Id$
#
# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/local/bin/perl5.6.0 -w
package GO::IO::Fasta;

=head1 NAME

  GO::IO::Fasta;

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

use strict;
use GO::Utils qw(rearrange);
use XML::Writer;

=head2 new

    Usage   - my $xml_out = GO::IO::XML(-output=>$out);
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
    
    $self->{'out'} = $out;

    return $self;
}

sub out {
  my $self = shift;
  
  return $self->{'out'};
}

=head2 header

    Usage   - $writer->header;
    Returns - None
    Args    - None

start_document prints the "Content-type: text/plain" statement.
If creating a cgi script, you should call this before start_document.

=cut


sub header {
    my $self = shift;
    
    my $out = $self->out;
    print $out "Content-type: text/plain\n\n";

}

  
sub drawFastaSeq {
  my $self = shift;
  my $gene_product = shift;
  
  my $out = $self->out;
  print $out $gene_product->to_fasta;
}

=head2 

sub characters

  This is simply a wrapper to XML::Writer->characters
  which strips out any non-ascii characters.

=cut

sub characters {
  my $self = shift;
  my $string = shift;
  
  $self->{writer}->characters($self->__strip_non_ascii($string));
  
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

  return sprintf "GO:%07d", $acc;
}

1;




