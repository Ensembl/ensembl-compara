# $Id$
#
# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org #          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself

#!/usr/local/bin/perl5.6.0 -w
package GO::CGI::HTMLTemplate;
use GO::Utils qw(rearrange);
use XML::Writer;

=head1 NAME

  WebUtils::HTMLTemplate;

=head1 SYNOPSIS

 NOTE:  I usually wrap this in another class, like GO::IO::HTML.
  However, for simple things it works fine like this.
 
 NOTE:  This uses the HTML formatting from XML:Writer, which is
  quite strange.

use FileHandle;
use GO::CGI::HTMLTemplate;

my $out = new FileHandle(">-");  #stdout
my $temp = GO::CGI::HTMLTemplate(-output=>$out);

$temp->htmlHeader;
$temp->startHtml();
$temp->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
$temp->startBody(-bgcolor=>'white');

$temp->startTitlebar(-bgcolor=>'blue', -align=>'center');
$temp->startTag('h1');
$temp->characters('Blather');
$temp->endTag('h1');
$temp->endTitlebar;

$temp->startSidebar(-bgcolor=>'red');

$temp->startTag('h1');
$temp->characters('Blather');
$temp->endTag('h1');
$temp->endSidebar();
	  
$temp->startContent();
$temp->characters('Blather');

$temp->endContent;
$temp->endHtml;

=head1 DESCRIPTION

This is a utility class that gives you some tools to easily format
HTML pages with Titlebars, Sidebars and Footers.  It also provides the 
ability to add Dublin Core RDF statements to the header as metadata.

To see the dublin core elements, check out:

http://dublincore.org/documents/dces/

=cut


=head2 new

    Usage   - my $temp = new GO::CGI::HTMLTemplate(-output=>$out);
    Returns - GO::CGI::HTMLTemplate
    Args    - Output FileHandle

Initializes the writer object.  To write to standard out, do:

my $out = new FileHandle(">-");
my $xml_out = new GO::IO::XML(-output=>$out);

=cut

sub new {
  my $class = shift;
  my $self = {};
  my ($out) =
    rearrange([qw(output)], @_);
  
  $self->{'writer'} =
    new XML::Writer(
		    OUTPUT=>$out,
		    UNSAFE=>1,
		    NEWLINES=>1
		   ); 
  bless $self, $class;
}

=head2 htmlHeader

    Usage   - $temp->htmlHeader
    Returns - nothing
    Args    - none

  print the Content-type:text/html\n\n

=cut

sub htmlHeader {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  $writer->characters("Content-type:text/html\n\n");
}

=head2 startHtml

    Usage   - $temp->startHtml
    Returns - GO::CGI::HTMLTemplate
    Args    - Output FileHandle

Initializes the writer object.  To write to standard out, do:

my $out = new FileHandle(">-");
my $xml_out = new GO::IO::XML(-output=>$out);

=cut

sub startHtml{
  my $self = shift;
  my $writer = $self->{'writer'};


  $writer->startTag('html');
}

=head2 head

    Usage   - $temp->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
    Returns - nothing
    Args    -  -rdf=>{HASH}

  Creates the <head/> element.  Dublin Core metadata can be passed in
  as an anonymous hash. 

  If you'd like to add more to the head element, you should use :
  $temp->startHead(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $temp->characters('blather');
  $temp->endHead;

=cut

sub head {
  my $self = shift;
  $self->startHead(@_);
  $self->endHead();
}

=head2 startHead

  Same as head(), but you can add more stuff:

  $temp->startHead(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $temp->characters('blather');
  $temp->endHead;

=cut

sub startHead{
  my $self = shift;
  my ($rdf) =
    rearrange([qw(rdf)], @_);
  my $writer = $self->{'writer'};

  $writer->startTag('head');

  if ($rdf) {
    $writer->startTag('rdf:RDF',
		      'xmlns:rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
		      'xmlns:dc'=>'http://purl.org/dc/elements/1.0/'
		     );
    $writer->emptyTag('rdf:Description',
		      %$rdf);
    $writer->endTag('rdf:RDF');

  }

}

=head2 endHead

  Usage   - $temp->endHead;
  Returns - nothing
  Args    - none

  Not necessary to call this explicitly if you used head()

=cut

sub endHead{
  my $self = shift;
  my $writer = $self->{'writer'};

  $writer->endTag('head');


}

=head2 startBody

    Usage   - $temp->startBody(-bgcolor=>'white');
    Returns - nothing
    Args    - bgcolor       
              text_color    
              link_color

   This does the <body> element.  Use it before startTitlebar
   or startSidebar
=cut

sub startBody{
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my ($bgcolor, $text_color, $link_color ) =
    rearrange([qw( bgcolor text_color link_color )], @_);
   
  $writer->startTag('body',
		    bgcolor=>$bgcolor,
		    text=>$text_color,
		    link=>$link_color
		   );

  $writer->startTag('table',
		    #width=>'100%',
		    valign=>"top",
		    border=>0,
		    cellpadding=>3,
		    cellspacing=>0
		   );

  
}

=head2 startTitlebar

    Usage   - $temp->startTitlebar(-bgcolor=>'blue', -align=>'center');
    Returns - nothing
    Args    - bgcolor
              corner_color  #Color of "corner" between titlebar and 
                            #sidebar.  If you're using a sidebar, 
                            # you MUST put in a corner_color.
              align         # Denotes where text will be aligned 
                            # horizontally within the bar.
              
   This starts a titlebar.  The titlebar takes the full width
   of the main page:

   ------------------------
       Title
   ------------------------
      Body
=cut

sub startTitlebar{
  my $self = shift;
  my $writer = $self->{'writer'};

  my ($bgcolor, $align, $corner_color) =
    rearrange([qw( bgcolor align corner_color )], @_);
  
  unless ($writer->in_element('tr')) {
    $writer->startTag('tr');
  }
  
  if ($corner_color) {
    $writer->startTag('td',
		      colspan=>1,
		      bgcolor=>$corner_color,
       		      nowrap=>1
		     );
    $writer->startTag('font',
		      color=>$corner_color
		     );
    
    $writer->characters('.');
    $writer->endTag('font');
    $writer->endTag('td');
      $writer->startTag('td',
		    colspan=>1,
		    align=>$align,
		    bgcolor=>$bgcolor,
		    valign=>'top',
		    nowrap=>1
		   );
  } else {
    
    $writer->startTag('td',
		      colspan=>1,
		      align=>$align,
		      bgcolor=>$bgcolor,
		      valign=>'top',
		      nowrap=>1
		     );
  }
}

=head2 endTitlebar

    Usage   - $temp->endTitlebar;
    Returns - nothing
    Args    - none

=cut

sub endTitlebar{
  my $self = shift;
  my $writer = $self->{'writer'};
  
  $writer->endTag('td');
  $writer->endTag('tr');
}

=head2 startSidebar

    Usage   - $temp->startSidebar(-bgcolor=>'red');
    Returns - nothing
    Args    - bgcolor

  starts sidebar.  It can be used with or without Titlebar to
  make either:

  ---------------------
     Titlebar
  ---------------------
  | S |
  | i |  Content
  | d |
  | e |
  | b |
  | a |
  | r |


 or:

  | S |
  | i |  Content
  | d |
  | e |
  | b |
  | a |
  | r |

=cut

sub startSidebar {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my ( $bgcolor ) =
    rearrange([qw( bgcolor )], @_);
  
  unless ($writer->in_element('tr')) {
    $writer->startTag('tr');
  }
  $writer->startTag('td',
		    bgcolor=>$bgcolor,
		    valign=>'top',
		    width=>'5%',
		    colspan=>1,
		    nowrap=>1,
		    cellpadding=>3
		   );
}

=head2 startSidebar

    Usage   - $temp->endSidebar;
    Returns - nothing
    Args    - none

=cut

sub endSidebar {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my ( $bgcolor ) =
    rearrange([qw( bgcolor )], @_);
  
  $writer->endTag('td');
}

=head2 startContent

    Usage   - $temp->startContent(-bgcolor=>'white');
    Returns - nothing
    Args    - bgcolor

  Call this before content is created.

=cut

sub startContent {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my ( $bgcolor, $nowrap ) =
    rearrange([qw( bgcolor nowrap)], @_);
  
  $writer->startTag('td',
		    colspan=>1,
		    align=>$align,
		    bgcolor=>$bgcolor,
		    valign=>'top',
		    $nowrap=>''
		   );
}

=head2 endContent

    Usage   - $temp->endContent;
    Returns - nothing
    Args    - bgcolor

  Call this when all content ends.

=cut

sub endContent {
  my $self = shift;
  my $writer = $self->{'writer'};
 
  $writer->endTag('td');
  $writer->endTag('tr');
}

=head2 startFooter

    Usage   - $temp->startFooter(-bgcolor=>'red');
    Returns - nothing
    Args    - bgcolor
              align
              corner_color   # see startTitlebar

  Add a footer for:

  ---------------------
     Titlebar
  ---------------------
  | S |
  | i |  Content
  | d |
  | e |
  | b |
  | a |
  | r |
  ---------------------
      Footer
  ---------------------


 or:

  | S |
  | i |  Content
  | d |
  | e |
  | b |
  | a |
  | r |
  ---------------------
      Footer
  ---------------------

=cut

sub startFooter{
  my $self = shift;

  $self->startTitlebar(@_);
}

=head2 endFooter

    Usage   - $temp->endFooter;
    Returns - nothing
    Args    - none

=cut

sub endFooter{
  my $self = shift;
  
  $self->endTitlebar;
}

=head2 endHtml

    Usage   - $temp->endHtml;
    Returns - nothing
    Args    - none

  Call this last

=cut

sub endHtml{
  my $self = shift;
  my $writer = $self->{'writer'};
  
  $writer->endTag('table');
  $writer->endTag('body');
  $writer->endTag('html');
}

=head2 startTable

    Usage   - $temp->startTable('th');
    Returns - nothing
    Args    - type('th') colspan, rowspan, valign

This is to start a new table.
IF the 'th' is passed the table's first 
cell will be a th, otherwise it'll be a td.

The other args go with the first cell.  They
are the same as the HTML attributes.

=cut

sub startTable{
  my $self = shift;
  my ( $type, $colspan, $rowspan, $valign, $nowrap, $cellspacing, $cellpadding, $border, $bgcolor, $width ) =
    rearrange([qw( type colspan rowspan valign nowrap cellspaing cellpadding border bgcolor width)], @_);
  my $writer = $self->{'writer'};
  
  $type = $type || 'td';

  $writer->startTag('table',
		    'cellspacing'=>$cellspacing || '0',
		    'cellpadding'=>$cellpadding || '2',
		    'border'=>$border || '0',
		    'bgcolor'=>$bgcolor || '',
		    'width'=>$width
                    );
  $writer->startTag('tr');
  $self->__startCell($type,
                     -colspan=>$colspan,
                     -rowspan=>$rowspan,
                     -valign=>$valign,
                     -nowrap=>$nowrap,
                     -type=>$type
                     );
}
  
=head2 endTable

    Usage   - $temp->startTable('th');
    Returns - nothing
    Args    - none

This is to end a table.

=cut

sub endTable{
  my $self = shift;
  my $writer = $self->{'writer'};
  
  $self->__endCell();

  $writer->endTag('tr');
  $writer->endTag('table');

}

=head2 startCell

    Usage   - $temp->startCell('th');
    Returns - nothing
    Args    - 'th', colspan, rowspan, valign, nowrap

This ends the current cell and starts a new one.  
If the 'th' is passed, it will be a th cell.

=cut

sub startCell{
  my $self = shift;
  my ( $type, $colspan, $rowspan, $valign, $nowrap ) =
    rearrange([qw( type colspan rowspan valign nowrap )], @_);


  my $writer = $self->{'writer'};

  $self->__endCell();
  
  $self->__startCell($type,
                     -colspan=>$colspan,
                     -rowspan=>$rowspan,
                     -valign=>$valign,
                     -nowrap=>$nowrap,
                     -type=>$type
                     );

}

=head2 startRow

    Usage   - $temp->startRow('th');
    Returns - nothing
    Args    - 'th', colspan, rowspan, valign, nowrap

Ends current row and starts a new one.
IF the 'th' is passed the new row's first 
cell will be a th, otherwise it'll be a td.

=cut

sub startRow{
  my $self = shift;
  my ( $type, $colspan, $rowspan, $valign, $nowrap ) =
    rearrange([qw( type colspan rowspan valign nowrap )], @_);
  my $writer = $self->{'writer'};

  $self->__endCell();

  $writer->endTag('tr');
  $writer->startTag('tr');

  $self->__startCell($type,
                     -colspan=>$colspan,
                     -rowspan=>$rowspan,
                     -valign=>$valign,
                     -nowrap=>$nowrap,
                     -type=>$type
                     );

}

sub __endCell {  
  my $self = shift;
  my $writer = $self->{'writer'};

  if ($writer->in_element('th')) {
    $writer->endTag('th');
  } else {
    $writer->endTag('td');
  }
}

sub __startCell {
  my $self = shift;
  my $type = shift;  
  my ( $type, $colspan, $rowspan, $valign, $nowrap) =
    rearrange([qw( type colspan rowspan valign nowrap )], @_);
  my $writer = $self->{'writer'};

  if ($type ne 'th') {
    $type = 'td';
  }

  if ($nowrap) {
    $writer->startTag($type,
                      'colspan'=>$colspan,
                      'rowspan'=>$rowspan,
                      'valign'=>$valign,
                      'nowrap'=>'');
  } else {
    $writer->startTag($type,
                      'colspan'=>$colspan,
                      'rowspan'=>$rowspan,
                      'valign'=>$valign);
  }  
}

=head2 out

Usage   - $temp->out('&nbsb;');

Use this in place of XML::Writer->characters
  when you need to output text that you don't want escaped for XML outputting,
 ie the & in &nbsp;.'

=cut

sub out{
  my $self = shift;
  my $text = shift;
  my $out = $self->{'writer'}->getOutput;
  
  $out->print($text);
}

sub AUTOLOAD {
  my $self = shift;
  my $program = our $AUTOLOAD;
			   $program =~ s/.*:://;
  $self->{'writer'}->$program(@_);
}

1;




