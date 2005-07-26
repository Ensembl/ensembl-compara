# $Id$
#
# This GO module is maintained by Chris Mungall <cjm@fruitfly.org>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

 package GO::xml;

     use XML::Writer;
      use IO;


use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT_OK = qw(xml_dump);
%EXPORT_TAGS = (all=> [@EXPORT_OK]);

sub xml_dump {
      my ($class, $graph)=@_;
      my $output = new IO::File('>xml.xml');
      print $output '<?xml version = "1.0"?>';
      my $writer = new XML::Writer(OUTPUT => $output);
            $writer->startTag("go");
 
      foreach my $go_object (@{$graph->get_all_nodes}) {
        $writer->startTag("term_object", "obsolete" => $go_object->is_obsolete );
	$writer->startTag("term");
	$writer->characters($go_object->name);
	$writer->endTag("term");
	$writer->startTag("id");
	$writer->characters($go_object->acc);
	$writer->endTag("id");
	$writer->endTag("term_object");
      }
	$writer->endTag("go");
	$writer->end();
        $output->close;
 	#return $output->print;
    }
1;
