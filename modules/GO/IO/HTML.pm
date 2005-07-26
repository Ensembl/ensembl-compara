# This GO module is maintained by Brad Marshall <bradmars@yahoo.com>
#
# see also - http://www.geneontology.org
#          - http://www.fruitfly.org/annot/go
#
# You may distribute this module under the same terms as perl itself
#
#!/usr/local/bin/perl5.6.0 -w
package GO::IO::HTML;
use GO::CGI::HTMLTemplate;
use GO::CGI::NameMunger;
use GO::Utils qw(spell_greek);
use base qw(GO::Model::Root);
## This needs to be made a require "
## statement, but I need to figure out how to import single
## methods into the namespace that way.
#use WebReports::BlastMarkup qw(markup);

## For further documentation, see :
## go-dev/apps/htmlbrowser/amigo_configuration_guide
## go-dev/apps/htmlbrowser/amigo_programming_guide

=head1 NAME

  GO::IO::HTML;

=head1 SYNOPSIS

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_term({acc=>00003677});

    #### ">-" is STDOUT
    my $out = new FileHandle(">-");
    my $xml_out = GO::IO::XML(-output=>$out);
    $xml_out->start_document();
    $xml_out->drawTerm($term);
    $xml_out->end_document();

OR:

    my $apph = GO::AppHandle->connect(-d=>$go, -dbhost=>$dbhost);
    my $term = $apph->get_node_graph(-acc=>00003677, -depth=>2);
    my $out = new FileHandle(">-");  
    
    my $xml_out = GO::IO::XML(-output=>$out);
    $xml_out->start_document();
    $xml_out->drawNodeGraph($term, 3677);
    $xml_out->end_document();

=head1 DESCRIPTION

Utility class to dump GO terms as xml.  Currently you just call
start_ducument, then drawTerm for each term, then end_document.

If there's a need I'll add drawNodeGraph, draw_node_list, etc.


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
    my $gen;
    $gen = new GO::CGI::HTMLTemplate(-output=>$out);    
    $self->{writer} = $gen;

    return $self;
}

=head2 drawSimpleQueryInterface 

    Usage   - $xml_out->drawSimpleQueryInterface(-session=>$session);
    Returns - None
    Args    -session=>$session, #GO::CGI::Session
            -layout=>'horizontal'  ## optional


=cut

sub drawSimpleQueryInterface {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $params = $session->get_param_hash;
  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
  $writer->startTag('table',
		    'cellspacing'=>'0',
		    'cellpadding'=>'2',
		   );
  $writer->startTag('tr');
  #  The logo.
  $writer->startTag('td',
		    'rowspan'=>'2',
		    'cellspacing'=>'0', 
		    'nowrap'=>''
		    );
  $self->__drawLogo(-session=>$session);
  $writer->endTag('td');
  #  Spacer column.
  $writer->startTag('td');
  $writer->endTag('td');
  #  Query box.
  $writer->startTag('td',
		    'cellspacing'=>'0',
		    'valign'=>'top',
		    'nowrap'=>''
		   );
  $writer->startTag('form',
		    'action'=>'go.cgi',
		   'name'=>'simple_query');
  $writer->startTag('b');
  $writer->characters('Search GO: ');
  $writer->endTag('b');
  if ($session->get_param('view') eq 'query' &&
      $session->get_param('query')) {
    $writer->emptyTag('input',
		      'type'=>'text',
		      'name'=>'query',
		      'size'=>'19',
		      'value'=>$session->get_param("query")
		   );
  } else {
    $writer->emptyTag('input',
		      'type'=>'text',
		      'name'=>'query',
		      'size'=>'19'
		     );
  }
  $writer->characters(' ');

  $writer->startTag('font',
		    'size'=>'-1');
  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
  my $wc_checked = %$params->{'auto_wild_cards'} || 'no';
  
  if ($wc_checked eq 'yes') {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		      'checked'=>''
		     );
  } else {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		     );
  }

  
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
  $writer->startTag('a', 
		    'href'=>'javascript:NewWindow(\'go.cgi?def=query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
  $writer->characters('Exact Match');
  $writer->endTag('a');

  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');

  $writer->endTag('td');
  #  Query input.

  $writer->startTag('td',
		    'cellspacing'=>'0',
		    'valign'=>'top',
		    'nowrap'=>'',
		   );
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'view',
		    'value'=>'query'
		   );
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'session_id',
		    'value'=>$session->get_param('session_id')
		   );
   $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'action',
		    'value'=>'query'
		   );
  $writer->emptyTag('input',
		    'type'=>'submit',
		    'value'=>'Submit',
		   );
  $writer->startTag('br');
  ## Blast Link
#  if ($session->get_param('show_blast') eq 'yes') {
#    my $href = 'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']);
#    $writer->startTag('a', 
#		      'href'=>'javascript:NewWindow(\''.$href.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
#    $writer->startTag('font',
#		      'size'=>'');
#    $writer->out('GOst Search');
#    $writer->endTag('font');  
#    $writer->endTag('a');
#  }
  
  $writer->endTag('td');

  $writer->endTag('td');

  # New row.
  $writer->endTag('tr');
  $writer->startTag('tr');

  # spacer cell.
  $writer->startTag('td');
  $writer->endTag('td');

  $writer->startTag('td',
		    'valign'=>'top');

  ##  IFF gene products are in database, allow
  ## a choice to search either them or terms

  if ($session->get_param('show_gp_options')) {
    # Search Constraint chooser.
    
    my $sc_checked = %$params->{'search_constraint'} || 'terms';
    $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');

    # checkbox for terms.
    
    if ($sc_checked eq 'terms' || 
	$sc_checked eq 'term' ||
	!$sc_checked) {
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'terms',
			'checked'=>'');
    
    } else {
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'terms');
    }
    $writer->startTag('font',
		      'size'=>'-1');
    my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
    
    $writer->startTag('a', 
		      'href'=>'javascript:NewWindow(\'go.cgi?def=query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
    $writer->characters('Terms');
    $writer->endTag('a');
    $writer->endTag('font');
    
    #  Other query options.
    
      ##  Makes chooser between gene products and terms.
    
    if ($sc_checked eq 'gp') {
      
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'gp',
			'checked'=>''
		       );
    } else {
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'gp'
		       );
    }
    my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
    
    $writer->startTag('font',
		      'size'=>'-1');
  $writer->startTag('a', 
		      'href'=>'javascript:NewWindow(\'go.cgi?def=query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
    $writer->characters('Gene Products');
    $writer->endTag('a');
    $writer->endTag('font');
    $writer->startTag('br');

  }
    $writer->endTag('td');


  $writer->startTag('td',
                   'valign'=>'top',
		    'nowrap'=>'');
    #  Advanced queries link.

  $writer->startTag('font',
                    'size'=>'-1');
  $writer->startTag('a',
                    'href'=>'go.cgi?advanced_query=yes'.$session->get_session_settings_urlstring(['session_id', 'query', 'search_constraint', 'fields', 'gfields', 'auto_wild_cards', 'view']));
  $writer->characters('Advanced Query');
  $writer->endTag('a');
  $writer->out('&nbsp;&nbsp;');
  $writer->endTag('font');


  if ($session->get_param('show_blast') eq 'yes') {
    $writer->startTag('br');
    my $href = 'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']);
    $writer->startTag('a', 
		      'href'=>'javascript:NewWindow(\''.$href.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
    $writer->startTag('font',
		      'size'=>'+1');
    $writer->out('GOst Search');
    $writer->endTag('font');  
    $writer->endTag('a');
  }


  $writer->endTag('td');




  #  Last row.

  $writer->endTag('tr');
  $writer->startTag('tr');
  
  #  Nav links.

  $writer->startTag('td',
		    'cellspacing'=>'0',
		    'valign'=>'bottom',
		   'nowrap'=>'');
  $self->__draw_nav_links(-session=>$session);
  $writer->endTag('td');

  # spacer cell.
  $writer->startTag('td');
  $writer->endTag('td');
  $writer->startTag('td',
		    'align'=>'right',
		    'valign'=>'top');

#  ## Iff gene products are in DB, then draw species selector

#  if ($session->get_param('show_gp_options')) {

#    $writer->startTag('b');
#    $writer->characters('Datasource:');
#    $writer->endTag('b');
  
#    $writer->endTag('td');
    
#    $writer->startTag('td',
#		      'valign'=>'top',
#		      'nowrap'=>'');
#    $writer->endTag('form');
#    $writer->startTag('form',
#		      'action'=>'go.cgi',
#		      'name'=>'gaf_widget');
#    $writer->startTag('b');
#    $self->_make_form_hiddens(-session=>$session, -fields=>['session_id', 'query', 'search_constraint']);
#    $writer->emptyTag('input',
#		      'type'=>'hidden',
#		      'name'=>'depth',
#		      'value'=>'0'
#		     );
#    $writer->startTag('font', 
#		      'size'=>'-1');
#    $self->__draw_species_selector(-session=>$session, -style=>"short");
#    $writer->out('&nbsp;');
#    $writer->emptyTag('input',
#		      'type'=>'submit',
#		      'value'=>'go');
#    $writer->endTag('font');
#    $writer->startTag('br');
#    $writer->endTag('form');
#  }

#  $writer->endTag('td');
  $writer->endTag('form');
  $writer->endTag('tr');
  $writer->endTag('table');
}


sub drawQuickSpeciesSelector {
    my $self = shift;
    my ($session) =
      rearrange([qw(session)], @_);

    my $writer = $self->{'writer'};
    $writer->startTag('td',
		      'valign'=>'top',
		      'nowrap'=>'',
		      'rowspan'=>'3'
		     );
    $writer->startTag('form',
		      'action'=>'go.cgi',
		      'name'=>'gaf_widget');
    $writer->startTag('b');
    $writer->characters('Datasource:');
    $writer->endTag('b');
    $writer->startTag('br');
    $writer->startTag('b');
    $self->_make_form_hiddens(-session=>$session, -fields=>['session_id']);
#    $writer->emptyTag('input',
#		      'type'=>'hidden',
#		      'name'=>'depth',
#		      'value'=>'0'
#		     );
#    $writer->emptyTag('input',
#		      'type'=>'hidden',
#		      'action'=>'plus_node',
#		      'value'=>'0'
#		     );
#    $writer->emptyTag('input',
#		      'type'=>'hidden',
#		      'action'=>'query',
#		      'value'=>$session->get_param('query')
#		     );
    $writer->startTag('font', 
		      'size'=>'-1');
    $self->__draw_species_selector(-session=>$session);
    $writer->out('&nbsp;');
    $writer->emptyTag('input',
		      'type'=>'submit',
		      'value'=>'go');
    $writer->endTag('font');
    $writer->startTag('br');
    $writer->endTag('form');
}

sub __draw_nav_links {
my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

if ($session->get_param('details_view') eq 'imago_details') {
  my $writer = $self->{'writer'};
  my $html_dir = '/ex';
  
  $writer->startTag('font',
		    'size'=>'-1');
  my $settings = $session->get_session_settings_urlstring(['session_id', 'advanced_query']);
  $settings =~ s/^&//;
  $writer->startTag('a',
		    'href'=>'/cgi-bin/ex/go.cgi?'.$settings."&action=replace_tree&search_constraint=terms");
  $writer->characters('Top');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>"$html_dir/imagodocs.html");
  $writer->characters('Docs');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>'http://www.geneontology.org');
  $writer->characters('Gene Ontology');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>"/cgi-bin/ex/basic.pl");
  $writer->characters('Search');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>'/cgi-bin/ex/insitu.pl');
  $writer->characters('in situ Home');
  $writer->endTag('a');
  
  $writer->endTag('font');
}
else {
  my $writer = $self->{'writer'};
  my $html_dir = $session->get_param('html_dir') || '..';
  
  $writer->startTag('font',
		    'size'=>'-1');
  my $settings = $session->get_session_settings_urlstring(['session_id', 'advanced_query']);
  $settings =~ s/^&//;
  $writer->startTag('a',
		    'href'=>'go.cgi?'.$settings."&action=replace_tree&search_constraint=terms");
  $writer->characters('Top');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>"$html_dir/docs.html");
  $writer->characters('Docs');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>'http://www.geneontology.org');
  $writer->characters('Gene Ontology');
  $writer->endTag('a');
  $writer->characters(' ');
  $writer->characters(' ');
  $writer->startTag('a',
		    'href'=>"$html_dir/links.html");
  $writer->characters('GO Links');
  $writer->endTag('a');
  if ($session->get_param('show_gp_options')) {
    $writer->characters(' ');
    $writer->characters(' ');
    $writer->startTag('a',
		      'href'=>'go.cgi?view=summary&'.$settings);
    $writer->characters('GO Summary');
    $writer->endTag('a');
  }
  $writer->endTag('font');
}


}


sub __drawLogo {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $writer = $self->{'writer'};
  my $image_dir = $session->get_param('image_dir') || "../images";
  my $logo = $session->get_param('logo') || "GOthumbnail.gif";
  
  my $logo_height = $session->get_param('logo_height') || 48;
  my $logo_width = $session->get_param('logo_width') || 176;
  
  
  $writer->startTag('a', 
		    'href'=>'go.cgi');
  $writer->emptyTag('img',
		    'height'=>$logo_height,
		    'width'=>$logo_width,
		    'src'=>"$image_dir/$logo",
		   'border'=>'0');
  $writer->endTag('a');


}


sub __drawPopupLogo {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $writer = $self->{'writer'};
  my $image_dir = $session->get_param('image_dir') || "../images";
  my $logo = $session->get_param('logo') || "GOthumbnail.gif";
  
  my $logo_height = $session->get_param('logo_height') || 48;
  my $logo_width = $session->get_param('logo_width') || 176;
  
  my $session_id = $session->get_param('session_id');
  $writer->startTag('a', 
		    'href'=>"javascript:ChangeParentDocument('go.cgi?session_id=$session_id&search_constraint=terms')");
  $writer->emptyTag('img',
		    'height'=>$logo_height,
		    'width'=>$logo_width,
		    'src'=>"$image_dir/$logo",
		   'border'=>'0');
  $writer->endTag('a');


}


=head2 drawAdvancedQueryInterface 

    Usage   - $xml_out->draw_simple_query_interface(-session=>$session);
    Returns - None
    Args    -session=>$session, #GO::CGI::Session
            -layout=>'horizontal'  ## optional


=cut

sub drawAdvancedQueryInterface {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $params = $session->get_param_hash;
  my $writer = $self->{'writer'};

  $writer->startTag('table',
		    'cellspacing'=>'0',
		    'cellpadding'=>'2',
		   );
  $writer->startTag('tr');
  #  The logo.
  $writer->startTag('td',
		    'rowspan'=>'2',
		    'cellspacing'=>'0',
		    'valign'=>'top',
		    'nowrap'=>''
		    );
  $self->__drawLogo(-session=>$session);

  $writer->endTag('td');
  #  Spacer column.
  $writer->startTag('td');
  $writer->endTag('td');
  #  Query box.
  $writer->startTag('td',
		    'colspan'=>'2',
		    'cellspacing'=>'0',
		    'valign'=>'top',
		    'nowrap'=>''
		   );
  $writer->startTag('form',
		    'action'=>'go.cgi',
		    'ENCTYPE'=>'multipart/form-data',
		    'name'=>'advanced_query',
		    'method'=>'POST'
		    );
  $writer->startTable(-valign=>'top',
		      );
  $writer->startTag('b');
  $writer->characters('Search GO: ');
  $writer->endTag('b');
  $writer->startCell();
  $writer->startTag('textarea',
		    'name'=>'query',
		    'cols'=>'19',
		    'rows'=>'2',
		    'wrap'=>'off');
  foreach my $query(split '\0', $session->get_param_hash->{'query'}) {
    $writer->characters($query."\n");
  }
  $writer->endTag('textarea');
  $writer->characters(' ');
  $writer->startCell(-valign=>'bottom');
  $writer->startTag('font',
		    'size'=>'-1');
  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
  my $wc_checked = %$params->{'auto_wild_cards'} || 'no';
  
  if ($wc_checked eq 'yes') {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		      'checked'=>''
		     );
  } else {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		     );
  }

  
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

  $writer->startTag('a', 
		    'href'=>'javascript:NewWindow(\'go.cgi?def=query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
  $writer->characters('Exact Match');
  $writer->endTag('a');
  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');

  $writer->startRow('colspan'=>3);
  $writer->startTag('b');
  $writer->out('Or Input File: ');
  $writer->startTag('b');
  $writer->startTag('input',
		    'type'=>'file',
		    'name'=>'idfile');

  $writer->endTable();
  
  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
  $writer->endTag('td');
  $writer->startTag('td');
  $self->_make_form_hiddens(-session=>$session, -fields=>['session_id']);

  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'view',
		    'value'=>'query'
		   );
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'action',
		    'value'=>'query'
		   );
  $writer->startTag('input',
		    'type'=>'hidden',
		   'name'=>'advanced_query',
		   'value'=>'yes');

    $writer->emptyTag('input',
		    'type'=>'submit',
		    'value'=>'Submit',
		   );
  $writer->startTag('br');
  if ($session->get_param('show_blast')) {
      my $href = 'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']);
      $writer->startTag('a', 
			'href'=>'javascript:NewWindow(\''.$href.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
      $writer->startTag('font',
			'size'=>'-1');
      $writer->out('Blast Search');
      $writer->endTag('font');  
      $writer->endTag('a');
  }
  $writer->startTag('br');
  $writer->startTag('font',
		    'size'=>'-1');
    my $query_link = $session->get_session_settings_urlstring(['session_id', 'depth', 'auto_wild_cards', 'view', 'search_constraint', 'query']);
  $query_link =~ s/^\&//;
  $writer->startTag('a',
		    'href'=>'go.cgi?advanced_query=no&'.$query_link);
  $writer->characters('Simple Query');
  $writer->endTag('a');

  
  $writer->endTag('font');
  $writer->endTag('td');
  # New row.
  $writer->endTag('tr');
  $writer->startTag('tr');

  # spacer cell.
  $writer->startTag('td');
  $writer->endTag('td');

  # Search Constraint chooser.
  
  $writer->startTag('td',
		    'rowspan'=>'2',
		    'valign'=>'top');
  
  my $sc_checked = %$params->{'search_constraint'} || 'terms';

  # checkbox for terms.
  
  if ($sc_checked eq 'terms' ||
     $sc_checked eq 'term' ||
     !$sc_checked
     ) {
    $writer->emptyTag('input',
		      'type'=>'radio',
		      'name'=>'search_constraint',
		      'value'=>'term',
		      'checked'=>'');
    
  } else {
    $writer->emptyTag('input',
		      'type'=>'radio',
		      'name'=>'search_constraint',
		      'value'=>'term');
  }
  $writer->startTag('font',
		    'size'=>'-1');
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

  $writer->startTag('a', 
		    'href'=>'javascript:NewWindow(\'go.cgi?def=advanced_query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
  $writer->characters('Terms');
  $writer->endTag('a');
  $writer->startTag('br');
  

  ##  Field selector for term search.

  $writer->startTag('b');
  $writer->characters(' Fields: ');
  $writer->endTag('b');

  $writer->startTag('select',
		   'name'=>'fields'
		   );
  my $options = {'Name and Synonym'=>'name', 
		 'Name and Definition'=>'def', 
		 'External References'=>'sp', 
		 'GO ID'=>'id',
		 'All fields'=>'all'};
  foreach my $option(keys %$options) {
    if (
	$session->get_param('fields') eq %{$options}->{$option} ||
	(!$session->get_param('fields') && %{$options}->{$option} eq 'name')
       ) {
      $writer->startTag('option',
			'value'=>%{$options}->{$option},
			'selected'=>'yes');
    } else {
      $writer->startTag('option',
			'value'=>%{$options}->{$option}
		       );
    }
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->characters($option);
    $writer->endTag('option');
  }
  $writer->endTag('select');
  $writer->endTag('font');
  
  $writer->endTag('td');
  
  #  other query options.
  
  $writer->startTag('td',
		    'rowspan'=>'2',
		    'valign'=>'bottom');
  if ($session->get_param('show_gp_options')) {
    $writer->startTag('font',
		      'size'=>'-1');
    ##  Makes chooser between gene products and terms.
  
    if ($sc_checked eq 'gp') {
      
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'gp',
			'checked'=>''
		       );
    } else {
      $writer->emptyTag('input',
			'type'=>'radio',
			'name'=>'search_constraint',
			'value'=>'gp'
		     );
    }
    my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

    $writer->startTag('a', 
		      'href'=>'javascript:NewWindow(\'go.cgi?def=advanced_query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
    $writer->characters('Gene Products');
    $writer->endTag('a');
    $writer->startTag('br');
  
    ##  Field selector for Gene Product search.
    $writer->startTag('table',
		      'cellpadding'=>'0',
		      'cellspacing'=>'2');
    $writer->startTag('tr');
    $writer->startTag('td');
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('b');
    $writer->characters(' Fields: ');
    $writer->endTag('b');
    $writer->endTag('font');
    $writer->endTag('td');
    $writer->startTag('td');
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('select',
		      'name'=>'gfields');
    my $options = {'Gene Symbol'=>'symbol', 
		   'Full Gene Name'=>'name', 
		   'Synonyms'=>'synonyms',
		   'External References'=>'xrefs',
		   'Sequence Accession'=>'seq_acc',
		   'Name and Symbol'=>'all'};
    foreach my $option(keys %$options) {
      if (
	  $session->get_param('gfields') eq %{$options}->{$option} ||
	  (!$session->get_param('gfields') && %{$options}->{$option} eq 'all')
	 ) {
	$writer->startTag('option',
			  'value'=>%{$options}->{$option},
			  'selected'=>'yes');
      } else {
	$writer->startTag('option',
			  'value'=>%{$options}->{$option}
			 );
      }
      $writer->characters($option);
      $writer->endTag('option');
    }
    $writer->endTag('select');
    $writer->endTag('font');
    $writer->endTag('td');
    $writer->endTag('tr');
    $writer->startTag('tr');
    $writer->startTag('td',
		      'valign'=>'top');
  
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('b');
    $writer->characters('Datasource: ');
    $writer->endTag('b');
    $writer->endTag('font');
    $writer->endTag('td');
    $writer->startTag('td',
		      'valign'=>'top');


    my $params = $session->get_param_hash; 
    
    $writer->startTag('b');
    $writer->startTag('font',
		      'size'=>'-1');
    $self->__draw_species_selector(-session=>$session);
    $writer->endTag('td');
    $writer->endTag('tr');
    $writer->startTag('tr');
    $writer->startTag('td',
		      'valign'=>'top');
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('b');
    $writer->characters('Evidence Type:');
    $writer->endTag('b');
    $writer->endTag('font');
    $writer->endTag('td');
    $writer->startTag('td');
    $writer->startTag('font');

    $self->__draw_evidence_selector(-session=>$session);
    
    
    $writer->endTag('td');
    $writer->endTag('tr');
    $writer->endTag('table');

    $writer->endTag('font');
  }
  $writer->endTag('td');

  #  Last row.

  $writer->endTag('tr');
  $writer->startTag('tr');
  
  #  Nav links.

  $writer->startTag('td',
		    'cellspacing'=>'0',
		    'valign'=>'bottom',
		   'nowrap'=>'yes');
  $self->__draw_nav_links(-session=>$session);
  $writer->endTag('td');

  # spacer cell.
  $writer->startTag('td',
		    'cellspacing'=>'0',
		   'rowspan'=>'1',
		   'width'=>'100');
  $writer->endTag('td');



  #  Advanced queries link.
  $writer->startTag('td',
		   'valign'=>'top',
		   'nowrap'=>'');
  $writer->endTag('font');
  $writer->endTag('td');
  $writer->endTag('tr');
  $writer->endTag('form');
  $writer->endTag('table');
}

sub drawCheckAllJscript {
  my $self = shift;
  my $writer = $self->{'writer'};

  my $js = q[
	     <SCRIPT LANGUAGE="JavaScript">
	     <!-- Modified By:  Steve Robison, Jr. (stevejr@ce.net) -->
	     
	     <!-- This script and many more are available free online at -->
	     <!-- The JavaScript Source!! http://javascript.internet.com -->
	     
	     <!-- Begin
	     var checkflag = "false";
	     function check(field) {
	       if (checkflag == "false") {
		 for (i = 0; i < field.length; i++) {
		   field[i].checked = true;}
		 checkflag = "true";
		 return "Uncheck All"; }
	       else {
		 for (i = 0; i < field.length; i++) {
		   field[i].checked = false; }
		 checkflag = "false";
		 return "Check All"; }
	     }
	     //  End -->
	     </script>
	    ];
  $writer->out($js);
}

=head2 drawPopupJscript

    Usage   - $xml_out->draw_popup_jscript();
    Returns - None
    Args    -params=>$hash_table, 
            -layout=>'horizontal'  ## optional

=cut

sub drawPopupJscript {
  my $self = shift;

  my $writer = $self->{'writer'};


  my $js = q[
	     <SCRIPT LANGUAGE='JAVASCRIPT' TYPE='TEXT/JAVASCRIPT'>
	     <!--
	     /****************************************************
	   AUTHOR: WWW.CGISCRIPT.NET, LLC
	   URL: http://www.cgiscript.net
	     Use the code for FREE but leave this message intact.
	     Download your FREE CGI/Perl Scripts today!
	     ( http://www.cgiscript.net/scripts.htm )
	     ****************************************************/
	     var win=null;
	     function NewWindow(mypage,myname,w,h,pos,infocus){
	       if(pos=="random"){myleft=(screen.width)?Math.floor(Math.random()*(screen.width-w)):100;mytop=(screen.height)?Math.floor(Math.random()*((screen.height-h)-75)):100;}
	       if(pos=="center"){myleft=(screen.width)?(screen.width-w)/2:100;mytop=(screen.height)?(screen.height-h)/2:100;}
	       else if((pos!='center' && pos!="random") || pos==null){myleft=524;mytop=50}
	       settings="width=" + w + ",height=" + h + ",top=" + mytop + ",left=" + myleft + ",scrollbars=yes,location=yes,directories=yes,status=yes,menubar=yes,toolbar=yes,resizable=yes";win=window.open(mypage,myname,settings);
	       win.opener.name = "opener";
	       win.focus();}
	     // -->
	     </script>
	    ];

    $writer->out($js);
}

sub drawParentOpenJscript {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my $js = q[ <SCRIPT LANGUAGE='JAVASCRIPT' TYPE='TEXT/JAVASCRIPT'>
	      function ChangeParentDocument(url) {
		opener.location = url;
		opener.focus();
	      }</script>
	    ];

  $writer->out($js);
}

sub drawSendToParentJscript {
  my $self = shift;
  my $writer = $self->{'writer'};
  
  my $js = q[ <SCRIPT LANGUAGE='JAVASCRIPT' TYPE='TEXT/JAVASCRIPT'>
	      function SendToParent(form) {
		var url = 'go.cgi'
		opener.location = url;
		opener.focus();
	      }</script>
	    ];

  $writer->out($js);
}


=head2 drawSearchConstraints

    Usage   - $xml_out->drawNodeGraph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut

sub drawSearchConstraints {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $writer = $self->{'writer'};
  my $params = $session->get_param_hash; 
  
  my $wc_checked = %$params->{'auto_wild_cards'} || 'no';
  
  $writer->startTag('font',
		    'size'=>'-1');

  if ($wc_checked eq 'yes') {graph
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		      'checked'=>''
		     );
  } else {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'auto_wild_cards',
		      'value'=>'yes',
		     );
  }

  my $wc_checked = %$params->{'search_descriptions'} || 'no';
  
  if ($wc_checked eq 'yes') {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'search_descriptions',
		      'value'=>'yes',
		      'checked'=>''
		     );
  } else {
    $writer->emptyTag('input',
		      'type'=>'checkbox',
		      'name'=>'search_descriptions',
		      'value'=>'yes',
		     );
  }
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

  $writer->startTag('a',
		    'href'=>'javascript:NewWindow(\'go.cgi?def=query_options\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
  $writer->characters('Search Descriptions');
  $writer->endTag('a');
  $writer->out('&nbsp;&nbsp');

  $writer->endTag('font');

}

=head2 drawGeneProductList

    Usage   - $xml_out->drawNodeGraph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut

sub drawGeneProductList {
  my $self = shift;
  my ($session, $list, $gp_order, $is_popup) =
    rearrange([qw(session list gp_order is_popup)], @_);

  $self->drawParentOpenJscript;

  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_list = $list || $session->get_data();
  my $all_term_query;
  foreach my $t(@$term_list) {
    $all_term_query .= "query=".$t->acc."&";
  }

  if (scalar(@$term_list) < 1) {
    $writer->characters('Sorry, there are no gene products that match your search.  Maybe you should ');
    $writer->startTag('a',
		      'href'=>'go.cgi?view=query&search_constraint=terms&query='.$session->get_param('query').$href_pass_alongs);
    $writer->characters(' search by term name ');
    $writer->endTag('a');
    if ($session->get_param('advanced_query') eq 'yes') {
      $writer->characters('.');
    } else {
      $writer->characters(' or ');
      $writer->startTag('a',
			'href'=>'go.cgi?view=query&advanced_query=yes&search_constraint=gp&query='.$session->get_param('query').$href_pass_alongs);
      $writer->characters(' try an advanced query. ');
      $writer->endTag('a');
    }
  } else {
    my %products;
    foreach my $term(@{$term_list}) {    
      if ($term->selected_association_list) {
	foreach my $ass(@{$term->selected_association_list}) {
	  my $sym = $ass->gene_product->symbol;
	  my $spec = $ass->gene_product->speciesdb;
	  if (!%products->{$sym}->{$spec}->{'gp'}) {
	    %products->{$sym}->{$spec}->{'gp'} = $ass->gene_product;
	  }
	  push @{%products->{$sym}->{$spec}->{$ass->gene_product->symbol}->{'term'}}, $term;
	  push @{%products->{$sym}->{$spec}->{$ass->gene_product->symbol}->{'ass'}->{$term->name}}, $ass;
	}
      }
    }
    $writer->startTable(
			-cellpadding=>'5',
			-border=>'1'
		       );
    $writer->startTag('b');
    $writer->characters('Gene Product: ');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    $writer->characters('Datasource: ');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    $writer->characters('Associated To Terms: ');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

    if ($is_popup) {
      $writer->startTag('a',
			'href'=>'go.cgi?def=ev_codes');
    } else {
      $writer->startTag('a', 
			'href'=>'javascript:NewWindow(\'go.cgi?def=ev_codes\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');'
		       );
    }
    $writer->characters('Association Evidence: ');
    $writer->endTag('a');
    $writer->endTag('b');
    if ($is_popup) {
      $writer->startTag('form',
			'action'=>'go.cgi',
			'name'=>'gp_list'
		       );
    } else {
      $writer->startTag('form',
			'target'=>$window_name,
			'action'=>'go.cgi',
			'onSubmit'=>'javascript:NewWindow(\'go.cgi\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');',
			'name'=>'gp_list'
		       );
    }
    $self->_make_form_hiddens(-session=>$session, -fields=>['session_id']);
    $writer->emptyTag('input',
		      'type'=>'hidden',
		      'name'=>'search_constraint',
		      'value'=>'gp');
    $writer->emptyTag('input',
		      'type'=>'hidden',
		      'name'=>'view',
		      'value'=>'details');
    if ($session->get_param('gp_view') ne 'detailed') {
      $writer->startRow(-colspan=>'5',
			-nowrap=>'');
      $self->__draw_gene_product_select_widget(-session=>$session, -form=>'gp_list', -field=>'gp');
    }

    if (!$gp_order) {
      foreach my $gp(sort __product_key_sort keys %products) {
	foreach my $species (keys %{%products->{$gp}}) {
	  my $gene_product = %products->{$gp}->{$species};
	  $self->__draw_gene_product_line($session, $gene_product, $is_popup);
	}
      }
    } else {
      foreach my $gp(@$gp_order) {
	foreach my $species (keys %{%products->{$gp}}) {
	  my $gene_product = %products->{$gp}->{$species};
	  $self->__draw_gene_product_line($session, $gene_product, $is_popup);
	}
      }
    }
    $writer->startRow(-colspan=>'5',
		      -nowrap=>'');

    if ($session->get_param('gp_view') ne 'detailed') {
      $self->__draw_gene_product_select_widget(-session=>$session, -form=>'gp_list', -field=>'gp');
    }

    $writer->endTag('form');
    $writer->endTable();
    }
  }




sub __draw_gene_product_line {
  my $self = shift;
  my $session = shift;
  my $gene_product_h = shift;
  my $is_popup = shift;

  my $gene_product = $gene_product_h->{'gp'};
  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $url = GO::CGI::NameMunger->get_url(
					 -database=>$gene_product->speciesdb,
					 -acc_no=>$gene_product->acc
					);
  my @ev_list;
  $writer->startRow(-valign=>'top', -nowrap=>'yes');
  $writer->emptyTag('input',
		    'type'=>'checkbox',
		    'name'=>'gp',
		    'value'=>$gene_product->acc);
  my $gp_url = 'go.cgi?gp='.$gene_product->acc.'&search_constraint=gp&view=details'.$href_pass_alongs;
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

  if ($is_popup) {
    $writer->startTag('a',
		      'href'=>$gp_url);
  } else {
    $writer->startTag('a',
		      'href'=>"javascript:NewWindow(\'$gp_url\', \'$window_name\', \'550\', \'650\', \'custom\', \'front\');"
		     );
  }
  $writer->characters(spell_greek($gene_product->symbol));
  $writer->endTag('a');
  $self->__draw_GOst_link(-session=>$session,
			  -gene_product=>$gene_product);
  $writer->startCell(-valign=>'top', -nowrap=>'yes');
  if ($url) {
    if ($is_popup) {
      $writer->startTag('a',
			'href'=>$url);
    } else {
      $writer->startTag('a',
			'href'=>"javascript:NewWindow(\'$url\', \'$window_name\', \'550\', \'650\', \'custom\', \'front\');"
		       );
    }
  }
  $writer->characters(GO::CGI::NameMunger->get_human_name($gene_product->speciesdb));
  if ($url) {
    $writer->endTag('a');
  }
  $writer->startCell(-valign=>'top', -nowrap=>'yes');
  foreach my $term (sort __by_term_name @{$gene_product_h->{$gene_product->symbol}->{'term'}}) {
    my $href = 'go.cgi?query='.$term->acc.'&view=details&search_constraint=terms&depth=0'.$term_pass_alongs;
    my $is_not;
    foreach my $gp (@{$gene_product_h->{$gene_product->symbol}->{'ass'}->{$term->name}}) {
      if ($gp->is_not) {
	$is_not = 1;
      }
    }
    if ($is_not) {
      $writer->startTag('i');
      $writer->startTag('b');
      $writer->out('NOT ');
      $writer->endTag('b');
    }
    if ($is_popup) {
      $writer->startTag('a',
			'href'=>$href);
    } else {
      $writer->startTag('b');
#      $writer->out($term->type." : ");
      $writer->endTag('b');
      $writer->startTag('a', 
			'href'=>'javascript:NewWindow(\''.$href.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');'
		       );
    }

    $writer->characters(spell_greek($term->name));
    $writer->endTag('a');
    if ($is_not) {
      $writer->endTag('i');
    }
    my @length = (1..scalar(@{$gene_product_h->{$gene_product->symbol}->{'ass'}->{$term->name}->[0]->evidence_list}));
    foreach my $count(@length) {
      $writer->startTag('br');
    }
  }
  $writer->startCell(-valign=>'top', -nowrap=>'yes');
  foreach my $term (sort __by_term_name @{$gene_product_h->{$gene_product->symbol}->{'term'}}) {
    my $href = "go.cgi?action=replace_tree&search_constraint=terms&query=".$term->acc.$href_pass_alongs;
    #Salmon

    if ($is_popup) {      
      $writer->startTag('a', 
			'href'=>"JavaScript:ChangeParentDocument(\'$href\')");
    } else {
      $writer->startTag('a', 
			'href'=>$href,
			'nowrap'=>''
		       );
    }
    $writer->characters("Tree View");
    $writer->endTag('a');
    my @length = (1..scalar(@{$gene_product_h->{$gene_product->symbol}->{'ass'}->{$term->name}->[0]->evidence_list}));
    foreach my $count(@length) {
      $writer->startTag('br');
    }
  }
  $writer->startCell(-valign=>'top', -nowrap=>'yes');
  foreach my $ass_key (sort __by_name keys %{$gene_product_h->{$gene_product->symbol}->{'ass'}}) {
    foreach my $ass (@{$gene_product_h->{$gene_product->symbol}->{'ass'}->{$ass_key}}) {
      foreach my $ev(@{$ass->evidence_list}) {
	$writer->characters(GO::CGI::NameMunger->get_full_name($ev->code));
	$writer->startTag('br');
      }
    }
  }
}

sub __draw_gene_product_select_widget {
  my $self = shift;
  my ($session, $form, $field) =
    rearrange([qw(session form field)], @_);

  my $writer = $self->{'writer'};
  
  $writer->emptyTag('input',
		    'type'=>'button',
		    'onClick'=>"JavaScript:check(document.forms[\"$form\"].$field);",
		    'value'=>'Check/Uncheck All'
		   );
  $writer->out('&nbsp;&nbsp;');
  $writer->startTag('select',
		    'name'=>'format',
		    'size'=>'1');
  $writer->startTag('option',
		    'value'=>'');
  $writer->characters('Get Detailed View');
  $writer->endTag('option');
  $writer->startTag('option',
		    'value'=>'fasta');
  $writer->characters('Get Fasta Sequences');
  $writer->endTag('option');
  $writer->endTag('select');
  $writer->out('&nbsp;&nbsp;');
  $writer->startTag('input',
		    'type'=>'submit',
		    'value'=>'Submit.',
		   );
}

sub __draw_term_select_widget {
  my $self = shift;
  my ($session, $form, $field) =
    rearrange([qw(session form field)], @_);
  
  my $writer = $self->{'writer'};

  $writer->emptyTag('input',
		    'type'=>'button',
		    'onClick'=>"JavaScript:check(document.forms[\"$form\"].$field);",
		    'value'=>'Check/Uncheck All'
		   );
  
  ##  I wish this worked.  Not sure why it doesn't.
  
  #    $writer->startTag('a',
  #		      'onClick'=>'javascript:check(this.form.query);');
  #    $writer->characters('Check All');
  #    $writer->endTag('a');
  
  $writer->out('&nbsp;&nbsp;');
  
  $writer->startTag('select',
		    'size'=>'1',
		    'name'=>'action');
  $writer->startTag('option',
		    'value'=>'replace_tree');
  $writer->characters('Draw New Tree');
  $writer->endTag('option');
  $writer->startTag('option',
		    'value'=>'plus_node');
  $writer->characters('Append To Tree');
  $writer->endTag('option');
  $writer->endTag('select');
  
  $writer->out('&nbsp;&nbsp;');
  
  $writer->startTag('input',
		    'type'=>'submit');
}

=head2 drawGeneProductDetails

    Usage   - $xml_out->drawNodeGraph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut

sub drawGeneProductDetails {
  my $self = shift;
  my ($session, $term_list) =
    rearrange([qw(session term_list)], @_);
  $self->drawParentOpenJscript;

  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_list = $term_list || $session->get_data();
  my $all_term_query;
  foreach my $t(@{$term_list || []}) {
    $all_term_query .= "query=".$t->acc."&";
  }
  if (scalar(@$term_list) < 1) {
    $writer->characters('Sorry, there are no gene products that match your search.  Maybe you should ');
    $writer->startTag('a',
		      'href'=>'go.cgi?view=query&search_constraint=terms&query='.$session->get_param('query').$href_pass_alongs);
    $writer->characters(' search by term name ');
    $writer->endTag('a');
  } else {
    my %products;
    foreach my $term(@{$term_list}) {    
      foreach my $ass(@{$term->selected_association_list || []}) {
	my $key = $ass->gene_product->symbol.'||'.$ass->gene_product->speciesdb;
	if (!%products->{$key}->{'gp'}) {
	  %products->{$key}->{'gp'} = $ass->gene_product;
	}
	push @{%products->{$key}->{$ass->gene_product->symbol}->{'term'}}, $term;
	push @{%products->{$key}->{$ass->gene_product->symbol}->{'ass'}->{$term->name}}, $ass;
      }
    }
    $writer->startTag('form',
		      'target'=>'opener',
		      'action'=>'go.cgi',
		      'onSubmit'=>'opener.focus()',
		     'name'=>'gp_details');
    $writer->startTag('input',
		      'type'=>'hidden',
		      'name'=>'search_constraint',
		      'value'=>'terms');
    $self->_make_form_hiddens(-session=>$session, -fields=>['session_id']);
    foreach my $gp(sort __product_key_sort keys %products) {
      my $gene_product_hash = %products->{$gp};
      $self->__draw_detailed_gp(-session=>$session,
				-gene_product_hash=>$gene_product_hash,
			       );
    }

    $self->__draw_term_select_widget(-session=>$session, -form=>'gp_details', -field=>'query');

    $writer->endTag('form');
  }
}

sub __draw_detailed_gp {
  my $self = shift;
  my ($session, $gene_product_hash) =
    rearrange([qw(session gene_product_hash)], @_);
  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);
  my $term_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db']);

  my $gene_product = %$gene_product_hash->{'gp'};
  
  $writer->startTable();
  $writer->startTag('h3');
  $writer->characters('Gene Product: ');      
  $writer->characters(spell_greek($gene_product->symbol));      
  $writer->endTag('h3');
  
  $writer->startTag('b');
  $writer->characters('Full Name: ');
  $writer->endTag('b');
  $writer->characters($gene_product->full_name || "Not Available");
  $writer->startTag('br');
  $writer->startTag('b');
  $writer->characters('Synonyms: ');
  $writer->endTag('b');
  print $gene_product->synonym_list;
  if ($gene_product->synonym_list) {
    foreach my $syn (@{$gene_product->synonym_list}) {
      $writer->startTag('br');
      $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
      $writer->out($syn);
    }
  } else {
    $writer->characters('None');
  }
  $writer->startTag('br');
  $writer->startTag('b');
  $writer->characters('Data Source: ');
  $writer->endTag('b');
  my $url = GO::CGI::NameMunger->get_url(
					 -database=>$gene_product->speciesdb,
					 -acc_no=>$gene_product->acc
					);
  if ($url) {
    $writer->startTag('a',
		      'href'=>$url
		     );
    $writer->characters(GO::CGI::NameMunger->get_human_name($gene_product->speciesdb));
    $writer->endTag('a');      
  } else {
    $writer->characters($gene_product->speciesdb);
  }
  
  my @ev_list;
  
  $writer->startTag('h3');
  $writer->characters('Associated To Terms:');
  $writer->endTag('h3');
  $writer->startTable(-valign=>'top',
		      -align=>'left'
		     );
  $writer->startTag('b');
  $writer->characters('Term Name');
  $writer->endTag('b');
  $writer->startCell(-valign=>'top',
		     -nowrap=>'yes');
  $writer->startCell(-valign=>'top',
		     -align=>'left',
		     -nowrap=>'yes'
		    );
  $writer->startTag('b');
  $writer->characters('Association Evidence');
  $writer->endTag('b');
  $writer->startCell(-valign=>'top',
		     'nowrap'=>'yes');
  $writer->startTag('b');
  $writer->characters('Sequence Similarities');
  $writer->endTag('b');
  
  $writer->startRow(-valign=>'top',
		    -nowrap=>'yes');
  foreach my $term (sort __by_term_name @{%$gene_product_hash->{$gene_product->symbol}->{'term'}}) {
      $writer->startTag('input',
			'type'=>'checkbox',
			'name'=>'query',
			'value'=>$term->acc);
      $writer->startTag('a', 
			'href'=>'go.cgi?query='.$term->acc.'&view=details&search_constraint=term&depth=0'.$term_pass_alongs);
      $writer->characters($term->public_acc." : ");
      $writer->characters(spell_greek($term->name));
      $writer->endTag('a');
      $writer->out('&nbsp;&nbsp;');
      my @length = (1..scalar(@{%$gene_product_hash->{$gene_product->symbol}->{'ass'}->{$term->name}->[0]->evidence_list}));
      foreach my $count(@length) {
	$writer->startTag('br');
      }
    }
  $writer->startCell(-valign=>'top',
		     -nowrap=>'yes');
  foreach my $term (sort __by_term_name @{%$gene_product_hash->{$gene_product->symbol}->{'term'}}) {
    my $url = "go.cgi?action=replace_tree&search_constraint=terms&query=".$term->acc.$href_pass_alongs;
    $writer->startTag('a', 
		      href=>"JavaScript:ChangeParentDocument(\'$url\')",
		      'nowrap'=>''
		     );
    $writer->characters("Tree View");
    $writer->endTag('a');
    $writer->out('&nbsp;&nbsp;');
    my @length = (1..scalar(@{%$gene_product_hash->{$gene_product->symbol}->{'ass'}->{$term->name}->[0]->evidence_list}));
    foreach my $count(@length) {
      $writer->startTag('br');
    }
  }
  $writer->startCell(-valign=>'top',
			-nowrap=>'yes');
  foreach my $ass_key (sort __by_name keys %{%$gene_product_hash->{$gene_product->symbol}->{'ass'}}) {
    foreach my $ass (@{%$gene_product_hash->{$gene_product->symbol}->{'ass'}->{$ass_key}}) {
      foreach my $ev(@{$ass->evidence_list}) {
	$writer->characters(GO::CGI::NameMunger->get_full_name($ev->code));
	$writer->out('&nbsp;&nbsp;');
	$writer->startTag('br');
      }
    }
  }
  $writer->startCell(-valign=>'top',
		     -nowrap=>'yes');
  foreach my $ass_key (sort __by_name keys %{%$gene_product_hash->{$gene_product->symbol}->{'ass'}}) {
      foreach my $ass (@{%$gene_product_hash->{$gene_product->symbol}->{'ass'}->{$ass_key}}) {
	  foreach my $ev(@{$ass->evidence_list}) {

	      my $refs = $ev->xref_list;
	      shift @$refs;
	      foreach my $ref(@$refs) {
		  my $ref_url = GO::CGI::NameMunger->get_ref_url(
								 -database=>$ref->xref_dbname,
								 -acc_no=>$ref->xref_key
								 );
		  if ($ref_url && $ref_url ne 'none') {
		      $writer->startTag('a',
					'href'=>$ref_url);
		      $writer->characters($ref->xref_key);
		      $writer->endTag('a');
		      $writer->out('&nbsp;&nbsp;');
		  } else {
		      $writer->characters($ref->xref_dbname.":".$ref->xref_key." ");
                  $writer->out('&nbsp;&nbsp;');
		  }
	      }
	  }
	  $writer->startTag('br');
      }
  }

  $writer->endTable();
  if ($gene_product->to_fasta) {
    $writer->startTable();
    $writer->startTag('p');
    $writer->startTag('br');
    $writer->startTag('b');
    $writer->characters('Peptide Sequence:');
    $writer->endTag('b');
    $self->__draw_GOst_link(-session=>$session,
			    -gene_product=>$gene_product);
    $writer->startRow();
    $writer->startTag('pre');
    $writer->out($gene_product->to_fasta);
    $writer->endTag('pre');
    $writer->endTag('p');
    $writer->endTable();
  } else {
    $writer->startTag('br');
    $writer->characters('No peptide sequence available.');
  }
  $writer->endTable();
  $writer->startTag('hr');
  
  
}


sub __product_key_sort {
  my @a_fields = split /\|\|/, $a;
  my @b_fields = split /\|\|/, $b;
  
  lc($a_fields[0]) cmp lc($b_fields[0])
    ||
  $a_fields[0] <=> $b_fields[0]
    ;
  
}

sub __by_name {
  lc(spell_greek($a)) cmp lc(spell_greek($b));
}

sub __by_term_name{
  lc(spell_greek($a->name)) cmp lc(spell_greek($b->name))
#    and
#      lc($a->type) cmp lc($b->type)
    ;
}

=head2 drawTermList

    Usage   - $xml_out->drawNodeGraph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut

sub drawTermList {
  my $self = shift;
  my ($session, $list) =
    rearrange([qw(session list)], @_);

  my $list = $list || $session->get_data;
  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'auto_wild_cards', 'ev_code', 'species_db', 'advanced_query', 'search_constraint']);
  
  $writer->startTag('form',
		   'action'=>'go.cgi',
		   'name'=>'term_list');
  
  $writer->startTag('input',
		    'type'=>'hidden',
		    'name'=>'depth',
		    'value'=>0);
  $writer->startTag('input',
		    'type'=>'hidden',
		    'name'=>'session_id',
		    'value'=>$session->get_param('session_id'));
  $writer->startTag('input',
		    'type'=>'hidden',
		    'name'=>'advanced_query',
		    'value'=>$session->get_param('advanced_query'));
  $writer->startTag('input',
		    'type'=>'hidden',
		    'name'=>'search_constraint',
		    'value'=>$session->get_param('search_constraint'));

  #  To see all terms in one tree.
  my $all_term_query;
  foreach my $term(@$list) {
    $all_term_query .= "query=".$term->acc."&";
  }

  if (scalar(@$list) < 1) {
    $writer->characters('Sorry, there are no terms that match your search.  Maybe you should ');
    $writer->startTag('a',
		      'href'=>'go.cgi?view=query&search_constraint=gp&query='.$session->get_param('query').$href_pass_alongs);
    $writer->characters(' search by gene product ');
    $writer->endTag('a');
    if ($session->get_param('advanced_query') eq 'yes') {
      $writer->characters('.');
    } else {
      $writer->characters(' or ');
      $writer->startTag('a',
			'href'=>'go.cgi?view=query&advanced_query=yes&query='.$session->get_param('query').$href_pass_alongs);
      $writer->characters(' try an advanced query. ');
      $writer->endTag('a');
    }
  } else {
    $writer->startTable(-border=>'1');
    $writer->startTag('b');
    $writer->characters('GO Term Name: ');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    $writer->endTag('b');
    $writer->startCell();
    $writer->startTag('b');
    $writer->characters('Definition:');
    $writer->endTag('b');
    foreach my $term(sort __by_term_name @$list) {
      if ($term->name ne '') {
        $writer->startRow(-nowrap=>'1');
	$writer->startTag('input',
			  'type'=>'checkbox',
			  'name'=>'query',
			  'value'=>$term->acc
			 );
	$writer->out('&nbsp;');
	my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
	
	$writer->startTag('a', 
			  'href'=>'javascript:NewWindow(\'go.cgi?query='.$term->acc.'&view=details&search_constraint=terms&depth=0'.$href_pass_alongs.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');'
		       );
        $writer->characters(spell_greek($term->name));
        $writer->endTag('a');
        $writer->startCell(-valign=>'top',
			  -nowrap=>'1');
        $writer->startTag('a', 
			  'href'=>'go.cgi?action=replace_tree&query='.$term->acc.$href_pass_alongs,
		       );
        $writer->characters('Tree View');
        $writer->endTag('a');
	$writer->startCell(-valign=>'top', -nowrap=>'1');
	$writer->characters($term->definition);
      }
    }
    $writer->startRow(-colspan=>'4'
		      );
    $self->__draw_term_select_widget(-session=>$session, -form=>'term_list', -field=>'query');
    $writer->endTag('form');
    $writer->endTable();
  }
}

=head2 drawNodeGraph

    Usage   - $xml_out->drawNodeGraph(-graph=>$graph);
    Returns - None
    Args    -graph=>$node_graph, 
            -focus=>$acc,                      ## optional
            -show_associations=>"yes" or "no"  ## optional

=cut



sub drawNodeGraph {
  my $self = shift;
  my ($session,
     $depth,
     $focus,
     $current_node,
     $view,
     $link_to) =
    rearrange([qw(session depth focus current_node view link_to)], @_);

  my %term_count;

  my $graph = $session->get_data;
  if ($graph) {
      if ($session->get_param('graph_view') eq 'tree' && 
	  $session->get_param('view') ne 'details'
	  ) {
	  require "GO/Model/TreeIterator.pm";
	  my $open_0 = $session->get_param_values(-field=>'open_0');
	  my $open_1 = $session->get_param_values(-field=>'open_1');
	  my $closed = $session->get_param_values(-field=>'closed');
	  my @closed;
	  foreach my $t (@$closed) {
	      my @array = split ",", $t;
	      push @closed, \@array;
	  }
	  my $terms;
	  foreach my $t (@$open_0) {
	      my @array = split ",", $t;
	      push @$terms, \@array;
	  }
	  my @op_1;
	  foreach my $t (@$open_1) {
	      my @array = split ",", $t;
	      push @op_1, \@array;
	      push @$terms, \@array;
	  }
	  my $nit = GO::Model::TreeIterator->new($graph, $terms, \@op_1, \@closed);
	  $nit->close_below;
	  
	  ## This is a kind of weak test.  The idea is that if someone 
	  ## comes into "tree" mode from a command like:
	  ## go.cgi?query=3700 , we need to use that to do a graph
	  ## style query and 'bootstrap' them into 'tree' mode
	  ## on the next go-round.

	  ## IFF they come in with a querystring like above, there
	  ## will be 1 field in open_0 without a comma.
	  
	  #$nit->set_bootstrap_mode();
	  
	  my $is_focus;
	  my $sib_depth;
	  while (my $ni = $nit->next_node_instance) {
	      if ($ni->depth > $sib_depth) {
		  next;
	      } else {
		  $sib_depth = 1000;
	      }
	      $is_focus = $nit->is_selected($nit->get_current_path);
	      if ($is_focus) {
		  $is_focus = 'yes';
	      }
	      my $reltype;
	      if ($ni->parent_rel) {
		  $reltype = $ni->parent_rel->type;
	      }
	      my $acc_list = $nit->get_current_path;
	      my $new_acc;
	      foreach my $acc(@$acc_list) {
		  $new_acc .= $acc.",";
	      }
	      chop $new_acc;
	
	      $self->drawTerm(-term=>$ni->term,
			      -session=>$session,
			      -focus=>$is_focus,
			      -depth=>$ni->depth,
			      -view=>$view,
			      -relationship=>$reltype,
			      -acc=>$new_acc,
			      -nit=>$nit
			      );
	  }
      } else {
	  my $nit = $graph->create_iterator;
	  
	  my $is_focus;
	  my $sib_depth;
	  my $is_obsolete = 0;
	  my $obsolete_level;
	  
	  while (my $ni = $nit->next_node_instance) {
	      if ($obsolete_level) {
		  if ($ni->depth <= $obsolete_level) {
		      $obsolete_level = undef;
		      $is_obsolete = 0;
		  }
	      }   
	      if ($ni->term->name eq 'obsolete') {
		  $is_obsolete = 1;
		  $obsolete_level = $ni->depth;
	      }
	      $is_focus = $self->__is_focus(-node_list=>$graph->focus_nodes,
					    -term=>$ni->term,
					    -session=>$session
					    );
	      my $reltype;
	      if ($ni->parent_rel) {
		  $reltype = $ni->parent_rel->type;
	      }
	
	      $self->drawTerm(-term=>$ni->term,
			      -session=>$session,
			      -focus=>$is_focus,
			      -depth=>$ni->depth,
			      -view=>$view,
			      -relationship=>$reltype,
			      -is_obsolete=>$is_obsolete
			      );
	  }
      }
  } else {
      my $gen = $self->{'writer'};
      $gen->characters('Sorry, no terms matched your query.');
  }
} 

sub advanceToNextSibling {
  my $self = shift;
  my $iter = shift;
  my $curr_node = shift;

  my $par = $curr_node->parent_rel->acc1;
  
  while (my $ni = $iter->next_node_instance) {
    if ($ni->parent_rel->acc1 == $par) {
      return $iter;
    }
  }
}

sub lastJobLink {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $writer = $self->{'writer'};

if ($session->get_param('last_job')) {
    my $job_link = "go.cgi?action=get_job_by_id&view=blast&session_id=".$session->get_param('session_id');
    $writer->startTag('br');
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('a',
		      'href'=>$job_link);
    $writer->characters('Last Job Submitted');
    $writer->endTag('a');
  }
}

sub drawXmlLink {
  my $self = shift;
  my ($session,
      $text) =
	rearrange([qw(session text)], @_);

  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
  if ($session->get_param('action') ne 'dotty') {
    if ($session->get_param('dag_gifs')) {
      my $url = "go.cgi?action=dotty&draw=current&view=details$href_pass_alongs";
      $self->start_popup_link(-session=>$session,
			      -url=>$url);
      $writer->characters('DAG view');
      $writer->endTag('a');
    $writer->startTag('br');
    }
    $writer->startTag('a',
		      'href'=>'go.cgi?'.$session->get_cgi->query_string.'&format=xml');
    $writer->characters($text ||  'Get this data as RDF XML.');
    $writer->endTag('a');
    $writer->startTag('br');
    if (!($session->get_param('view') eq 'details' && 
	  $session->get_param('search_constraint') eq 'gp')) {
      $writer->startTag('a',
			'href'=>'go.cgi?'.$session->get_cgi->query_string.'&format=go_ff');
      $writer->characters('Get this data as a GO flat file.');
      $writer->endTag('a');
    }
  }
}

sub drawTrackerLinks {
    my $self = shift;
    my ($session) =
    rearrange([qw(session)], @_);
    
    my $writer = $self->{'writer'};
    $writer->startTag('font',
		      'size'=>'-1');
    $writer->startTag('a',
		    'href'=>'https://sourceforge.net/tracker/?atid=440764&group_id=36855&func=browse');
    $writer->characters('Submit GO term or definition request.');
    $writer->endTag('a');
    $writer->startTag('br');
    $writer->startTag('a',
		      'href'=>'https://sourceforge.net/tracker/?atid=494390&group_id=36855&func=browse');
    $writer->characters('Submit AmiGO bug report.');
    $writer->endTag('a');
    $writer->endTag('font');
}


sub drawFooter {
    my $self = shift;
    my ($session) =
    rearrange([qw(session)], @_);
    
    my $writer = $self->{'writer'};

    $writer->startTag('hr');
    $self->drawTrackerLinks(-session=>$session);
    $writer->startFooter(-align=>'left',-bgcolor=>'white' );
    $writer->startTag('br');
    $writer->startTag('font',
		   'size'=>'-2');
    $writer->characters('Copyright');
    $writer->startTag('a',
		   'href'=>'http://www.geneontology.org');
    $writer->characters(' The Gene Ontology Consortium');
    $writer->endTag('a');
    $writer->characters('. All rights reserved.');
    $writer->endTag('font');
    
    $writer->endFooter;
}

sub drawBookmarkLink {
  my $self = shift;
    my ($session,
     $text) =
    rearrange([qw(session text)], @_);

  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring(['open_0', 'open_1']);
  $href_pass_alongs =~ s/^&//;
  $writer->startTag('p');
  $writer->startTag('a',
		    'href'=>'go.cgi?'.$href_pass_alongs);
  $writer->characters($text);
  $writer->endTag('a');
  $writer->endTag('p');

}

sub __is_in_focus_list {
  my $self = shift;
  my $acc = shift;
  my $focus_list = shift;
  
  foreach my $node(@$focus_list) {
    if ($acc == $node->acc) {
      return 1;
    }
  }
  return 0;
}

sub __is_focus {
  my $self = shift;
  my ($node_list, $term, $session) =
    rearrange([qw(node_list term session)], @_);
  
  foreach my $node (@$node_list) {
    if ($node->acc 
	eq $term->acc) {
      my $closed_list = $session->get_param_values(-field=>'closed');
      my $focused_list = $session->get_param_values(-field=>'focused');
      if ($self->__is_inside($term->acc, $closed_list) 
	  && !$self->__is_inside($term->acc, $focused_list)) { 
	return "no";
      } else {
	return "yes";
      }
    }
  }
  return "no";
}


=head2 drawTerm

    Usage   - $xml_out->drawTerm();
    Returns - None
    Args    -term=>$term, 
            -graph=>$graph, 
            -is_focus=>"yes" or "no",    ## optional
            -show_associations=>"yes" or "no",    ## optional
            -show_terms=>"yes" or "no",    ## optional, just draws associations
            -view=>'details'   ##  If details, 

=cut


sub drawTerm {
    my $self = shift;
    my ($term, 
	$session, 
	$is_focus, 
	$depth, 
	$relationship,
	$view,
	$link_to,
	$is_obsolete,
	$acc,
	$nit
       ) =
	   rearrange([qw(term 
			 session
			 focus 
			 depth 
			 relationship
			 view
			 link_to
			 is_obsolete
			 acc
			 nit
			)], @_);

    use GO::CGI::NameMunger;
    my $graph = $session->get_data;
    my $image_dir = $session->get_param('image_dir') || "../images";
    my $writer = $self->{'writer'};
    my $view = $view || $session->get_param('view');

    my $root_node = $session->get_param('root_node') || $session->apph->get_root_term->public_acc;
    if ($view eq 'details') {
	$self->drawTermNameAndDescription(-term=>$term);
	my $apph = $session->apph;
	my $tl = $apph->get_terms_with_associations({acc=>$term->acc});
	if ($session->get_param('gp_view') eq 'detailed') {
	  $self->drawGeneProductDetails(-session=>$session, -term_list=>$tl);
	} else {
	  $self->drawGeneAssociationList(-term_list=>$tl, -session=>$session);
	}

    } elsif ($view eq 'dag') {
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);

	if ($session->get_param('show_vert') eq 'yes') {
	  $writer->out('|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' x $depth);
	} else {
	  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' x $depth);
	}
	if ($relationship) {
	  if ($relationship eq "is_a") {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/is_a.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  } elsif ($relationship eq "developsfrom") {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/develops_from.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  } else {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/part_of.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  }
	}
	if ($link_to) {
	  require "GO/CGI/NameMunger.pm"; 
	  $writer->startTag('a',
                          'href'=>GO::CGI::NameMunger->get_link_to(-session=>$session, 
								   -extension=>$term->name));
	} else {
	  
	  $writer->startTag('a',
			    'href'=>'go.cgi?query='.$term->public_acc.'&view=details&search_constraint=terms&depth=0'.$href_pass_alongs);
	} 
	if ($is_obsolete) {
	  $writer->startTag('font',
			    'color'=>'#707070');
	}
        if ($is_focus eq "yes") {
            $writer->startTag('b');
        }
        $writer->characters($term->public_acc);
        $writer->characters(" : ");
        $writer->characters($term->name);
        $writer->characters(' ('.$term->n_deep_products.')')
          unless ($session->get_param('suppress_product_count'));
        if ($is_focus eq "yes") {
            $writer->endTag('b');
        }
	if ($is_obsolete) {
	  $writer->endTag('font');
	}
        $writer->endTag('a');
        $writer->startTag('br');              
    } else {    
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'advanced_query']);

	if ($session->get_param('show_vert') eq 'yes') {
	  $writer->out('|&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' x $depth);
	} else {
	  $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' x $depth);
	}
	
	my $new_acc;
	
	if($acc) {
	  $new_acc = $acc;
	} else {
	  $new_acc = $term->public_acc;
	}

	if ($self->__is_in($term->acc, $graph->focus_nodes())) {
	  if ($graph->n_children($term->public_acc) == scalar(@{$graph->get_child_relationships($term->public_acc)})) {
	    $writer->startTag('a', 
			      'href'=>'go.cgi?action=minus_node&search_constraint=term&query='.$term->public_acc.$href_pass_alongs
			     );
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/ominus.png",
			      'border'=>0
			     );
	    if ($new_acc ne $root_node) {
	      $writer->endTag('a');
	    }
	  } else {
	    $writer->startTag('a', 
			      'href'=>'go.cgi?action=plus_node&search_constraint=terms&query='.$new_acc.'&depth=1'.$href_pass_alongs
			     );
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/plus.png",
			      'border'=>0
			     );
	    $writer->endTag('a');
	  }
	} else {
	  $writer->startTag('a', 
			    'href'=>'go.cgi?action=plus_node&search_constraint=terms&query='.$new_acc.$href_pass_alongs.'&depth=1'
			   );
	  if ($graph->n_children($term->public_acc) > 0 ) {
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/plus.png",
			      'border'=>0
			     );
	  } else {
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/dot.png",
			      'border'=>0
			     );
	  }
	  $writer->endTag('a');
	} 
	if ($relationship) {
	  if ($relationship eq "is_a") {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/is_a.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  } elsif ($relationship eq "developsfrom") {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/develops_from.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  } else {
	    $writer->characters(' ');
	    $writer->emptyTag('img', 
			      'src'=>"$image_dir/part_of.gif",
			      'border'=>0
			     );
	    $writer->characters(' ');
	  }
	}
	my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';

	$writer->startTag('a', 
			  'href'=>'javascript:NewWindow(\'go.cgi?query='.$term->acc.'&view=details&search_constraint=terms&depth=0'.$href_pass_alongs.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');'
			 );
	
	if ($is_focus eq "yes") {
	    $writer->startTag('b');
	}
	if ($is_obsolete) {
	  $writer->startTag('font',
			    'color'=>'#707070');
	}
	$writer->characters($term->public_acc);
	$writer->characters(" : ");
	$writer->characters($term->name);
	$writer->characters(' ('.$term->n_deep_products.')')
	  unless ($session->get_param('suppress_product_count'));
	$writer->endTag('a');
	if ($session->get_param('pie_charts')) {
	  if ($is_focus eq "yes") {
	    if ($graph->n_children($term->public_acc) == scalar(@{$graph->get_child_relationships($term->public_acc)})) {
		$self->drawPiecon(-session=>$session, -term=>$term);
	      }
	  }
	}
	$writer->endTag('b');
	if ($is_obsolete) {
	  $writer->endTag('font');
	}
	$writer->endTag('a');
	my $xrl = $term->dbxref_list;
	if ($xrl) {
	  foreach my $xr (@$xrl) {
	    if ($xr->xref_dbname eq 'ec') {
	      my $href = GO::CGI::NameMunger->get_url(-database=>'ec',
						      -acc_no=>$xr->xref_key);
	      $writer->characters(' ');
	      if (!($xr->xref_key =~ m/\-/)){
		$writer->startTag('a',
				  'href'=>$href);
	      }
	      if ($is_obsolete) {
		$writer->startTag('font',
				  'color'=>'#707070');
	      }
	      $writer->characters('EC: '.$xr->xref_key);
	      if ($is_obsolete) {
		$writer->endTag('font');
	      }
	      if (!($xr->xref_key =~ m/\-/)){
		$writer->endTag('a');
	      }
	      
	    }
	  }
	}
	    
	$writer->startTag('br');
    }
}

sub drawPiecon {
    my $self = shift;
    my ($session, $term) =
	rearrange([qw(session term)], @_);
    
    my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'advanced_query']);
    my $writer = $self->{'writer'};

    $writer->out('&nbsp;');
    my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
    $writer->startTag('a',
		      'href'=>'javascript:NewWindow(\'go.cgi?query='.$term->public_acc.'&view=details&action=summary'.$href_pass_alongs.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
    my $image_dir = $session->get_param('image_dir') || "../images";
    $writer->startTag('img',
		      'src'=>"$image_dir/piecon.gif",
		      'border'=>'0');
    $writer->endTag('a');
}

sub drawRootPie {
    my $self = shift;
    my ($session, $graph) =
	rearrange([qw(session graph)], @_);

    my $root_node = $session->get_param('root_node') || $session->apph->get_root_term->public_acc;

    my $children = $graph->get_child_terms($root_node);
    foreach my $child (@$children) {
	if ($graph->n_children($child->public_acc) == scalar(@{$graph->get_child_relationships($child->public_acc)})) {
	    return 1;
	}
    }
    return 0;
}


=head2 drawTermNameAndDescription

    Usage   - $xml_out->drawTermNameAndDescription(-term->$term);
    Returns - None
    Args    -term=>$term, 
            
Formats the name, syonoym and definitions for the 
term.

=cut

sub drawTermNameAndDescription {
  my $self = shift;
  my ($term, $color, $session) =
    rearrange([qw(term color session)], @_);
  
    my $writer = $self->{'writer'};
    $writer->startTable(-colspan=>'2',
			-bgcolor=>$color);
    $writer->startTag('h2');
    $writer->characters($term->name);
    $writer->endTag('h2');
    $writer->endTable();
    $writer->startTag('b');
    $writer->characters('Accession:');
    $writer->endTag('b');
    $writer->characters($term->public_acc);
    $writer->startTag('br');
    $writer->startTag('b');
    $writer->characters('Synonyms:');
    $writer->endTag('b');

    if ($term->synonym_list) {
	foreach my $syn (@{$term->synonym_list}) {
	    $writer->startTag('br');
	    $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;");
	    $writer->characters($syn." ");  
	}
    } else {
	$writer->characters(" None.");  
    }
    $writer->startTag('br');
    $writer->startTag('b');
    $writer->characters('Definition: ');
    $writer->endTag('b');

    if ($term->definition) {
	$writer->startTable(-valign=>'top', -width=>'500');
	$writer->out('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
	$writer->startCell();
	$writer->characters($term->definition);  
	$writer->endTable();
    } else {
	$writer->characters(" None.");  
    }
  if ($term->comment) {
    $writer->startTag('br');
    $writer->startTag('b');
    $writer->characters('Comment: ');
    $writer->endTag('b');
    $writer->characters($term->comment);
  }
}

=head2 drawTermXrefList

    Usage   - $xml_out->drawTermXrefList(-xref_list=>$term->xref_list, );
    Returns - None

=cut

sub drawTermXrefList {
  my $self = shift;
  my ($xref_list, $session) =
    rearrange([qw(xref_list session)], @_);
  
  my $writer = $self->{'writer'};
  
  my $href_pass_alongs = $session->get_session_settings_urlstring;
  
  my $n_drawn_xrefs = 0;
  my $param_hash = $session->get_param_hash;

  if (!$xref_list) {
    $writer->characters('None.');
  } else {    
    my $image_dir = $session->get_param('image_dir') || "../images";
    my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
								     'view',
								     'query'
								    ]);
    my %xref_hash;
    foreach my $reference(@$xref_list) {
      push @{%xref_hash->{$reference->xref_dbname}}, $reference;
    }
    
    foreach my $db(keys %xref_hash) {
      my $param_hash = $session->get_param_hash();
      my @xrefs = split '\0', $param_hash->{'selected_xrefs'};
      if ($self->__is_inside($db, \@xrefs)) {
	$writer->startTag('a',
			  'href'=>"go.cgi?unselected_xrefs=$db$href_pass_alongs"
			 );
	$writer->emptyTag('img',
			  'border'=>'0',
			  'src'=>"$image_dir/ominus.png"
			 );
	$writer->endTag('a');
	$writer->out('&nbsp;');
	$writer->characters($db);
	$writer->startTag('br');
	foreach my $ref(@{%xref_hash->{$db}}) {
	    my $url = GO::CGI::NameMunger->get_url(
						   -database=>lc($ref->xref_dbname),
						   -acc_no=>$ref->xref_key
						  );
	    my $xref_db_name = GO::CGI::NameMunger->get_human_name(lc($ref->xref_dbname));
	    if ($url) {
	      if ($url eq "none") {
	      }
	      else {
		my $key = $ref->xref_key;
		
		$writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
		if ($ref->xref_desc) {
		  $writer->characters($ref->xref_desc);
		} else {
		  $writer->characters($key);
		}
		$writer->out('&nbsp;&nbsp;');
		$writer->startTag('a', 
				  'href'=>$url
				 );
		my $img = GO::CGI::NameMunger->get_xref_image(-session=>$session,
							      -database=>lc($ref->xref_dbname),
							      -acc_no=>$ref->xref_key);
		if ($img) {
		  $writer->startTag('img',
				    'src'=>$img,
				    'border'=>'0');
		  $writer->endTag('img');
		} else {
		  $writer->characters($ref->xref_dbname);
		}
		$writer->endTag('a');
		$writer->out('&nbsp;&nbsp;');
		$self->drawReciprocalLink(				      
					  -acc_no=>$ref->xref_key,
					  -session=>$session
					 );
	      }
	    } else {
	      $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
	      if ($xref_db_name) {
		$writer->characters($xref_db_name);
	      } else {
		$writer->characters($ref->xref_dbname);
	      }
	      $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
	      $writer->characters($ref->xref_key);
	      $writer->out('&nbsp;&nbsp;');
	      $self->drawReciprocalLink(
					-acc_no=>$ref->xref_key,
					-session=>$session);
	    }
	  $writer->startTag('br');
	}
      } else {

	my $image_dir = $session->get_param('image_dir') || "../images";
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									 'view',
									 'query'
									]);
	$writer->startTag('a',
			  'href'=>"go.cgi?selected_xrefs=$db$href_pass_alongs"
			 );
	$writer->emptyTag('img',
			  'border'=>'0',
			  'src'=>"$image_dir/plus.png"
			 );
	$writer->endTag('a');
	$writer->out('&nbsp;');
	$writer->characters($db);
	$writer->out('&nbsp;');
	$writer->out("(".scalar(@{%xref_hash->{$db}}).")");
	$writer->startTag('br');
      }
    }
  }
}
  
sub __drawXrefHeaders {
    my $self = shift;
    my $writer = $self->{'writer'};

        $writer->startTag('table');
    $writer->startTag('tr');
    $writer->startTag('th',
		      'align'=>'left');
    $writer->characters('Source: ');
    $writer->endTag('th');
    $writer->startTag('th',
		      'align'=>'left');
    $writer->characters('References: ');
    $writer->endTag('th');
    $writer->endTag('tr');
    


}

=head2 drawReciprocalLink

Draws the link to get all terms associated with a given
xref and an icon if available.

=cut

sub drawReciprocalLink {
  my $self = shift;
  my ($database, $acc_no, $session) =
    rearrange([qw(database acc_no session)], @_);
  my $image_dir = $session->get_param('image_dir') || "../images";
  my $href_pass_alongs = $session->get_session_settings_urlstring;
  my $writer = $self->{'writer'};
  my $link = 'go.cgi?view=query&query='.$acc_no.$href_pass_alongs;
  $writer->startTag('a', href=>"JavaScript:ChangeParentDocument(\'$link\')");
  

	      $writer->startTag('img',
				'src'=>"$image_dir/littleAmigo.gif",
				'border'=>'0');
	      $writer->endTag('img');
	    $writer->endTag('a');


}


=head2 drawGeneAssociationList

    Usage   - $xml_out->drawTerm(-association_list=>$term->association_list, );
    Returns - None
            
Draws a table with :

Gene product link.   Database.    Evidencelist.  

=cut

sub drawGeneAssociationList {
  my $self = shift;
  my ($association_list, $term_list, $session) =
    rearrange([qw(association_list term_list session)], @_);
  my $href_pass_alongs = $session->get_session_settings_urlstring;
  my $query_extension = '';
  
  $self->drawPopupJscript;
  
  my $writer = $self->{'writer'};

  if ($term_list) {
    if (scalar(@{$term_list}) != 0) {	
      $writer->startTag('table');
      $writer->startTag('tr');
      $writer->startTag('th',
		       'colspan'=>'4',
		       'align'=>'left');
      $writer->characters('GO Term:');
      $writer->endTag('tr');
      $writer->startTag('tr');
      $writer->startTag('th',
			align=>'left',
			'nowrap'=>''
		       );
      $writer->out("&nbsp;&nbsp;");
      $writer->characters('Gene Symbol:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left' );
      $writer->characters('Datasource:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->startTag('a',
			'href'=>'http://www.geneontology.org/doc/GO.evidence.html');
      $writer->characters('Evidence:');
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left',
		       'nowrap'=>'');
      $writer->characters('Full name:');
      $writer->endTag('th');
      $writer->endTag('tr');
      my $ass_page = $session->get_param('association_page') || 1;
      my $low_association_count = ($ass_page - 1) * 1000; 
      my $high_association_count = $ass_page * 1000;
      my $association_count = 1;
      my $have_drawn_yet = 0;
      my %term_list;
      foreach my $term (@$term_list) {
	if (!%term_list->{$term->public_acc}) {
	    %term_list->{$term->public_acc} = 1;
	      my $current_association_count = $association_count;
	  if ($association_count < $high_association_count || $ass_page eq 'all') {
	      if ($current_association_count >= $low_association_count) {
		  $writer->startTag('tr');
		  $writer->startTag('td', 
				    'colspan'=>'4');
		  $writer->startTag('a',
				    'href'=>'go.cgi?query='.$term->public_acc.'&view=details&search_constraint=terms&depth=0'.$href_pass_alongs);  
		  $writer->characters($term->public_acc." : ".$term->name);
		  $writer->endTag('a');
		  $writer->endTag('td');
		  $writer->endTag('tr');
		  foreach my $ass (@{$term->association_list}) {
		      $self->__draw_association(-association=>$ass,
						-session=>$session);
		      $association_count = $association_count + 1;
		  }
		  $have_drawn_yet = 1;
	      } else {
		  $association_count = $association_count + scalar(@{$term->association_list});
	      }
	  }
      }
    }
      my $is_next = 1;
      if ($association_count < $high_association_count) {
	$is_next = 0;
      }
      if ($have_drawn_yet == 0) {
	$writer->startTag('tr');
	$writer->startTag('td', 
			  'colspan'=>'4');
	$writer->characters(" None on this page.");  
	$writer->endTag('td');
	$writer->endTag('tr'); 
      }
      $writer->startTag('tr');
      $writer->startTag('td', 'colspan'=>'2');
      $writer->endTag('td');
      $writer->startTag('td', 'colspan'=>'2');
	$writer->endTag('td');
	$writer->endTag('tr'); 
      $writer->startTag('tr');
      $writer->startTag('td', 
			'colspan'=>'4');
      $writer->startTag('font',
			'size'=>'-1');
      $self->drawAssociationPageIterator(-session=>$session,
					-is_next=>$is_next);
      $writer->endTag('td');
      $writer->endTag('tr'); 
      $writer->endTag('table');
    } else {
      $writer->characters(" None selected.");  
    }
  } elsif ($association_list) {
    if (scalar(@{$association_list}) != 0) {
      $writer->startTag('table');
      $writer->startTag('tr');
      $writer->startTag('th',
			align=>'left');
      $writer->characters('Gene Symbol:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left' );
      $writer->characters('Datasource:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->startTag('a',
			'href'=>'go.cgi?def=ev_codes');
      $writer->characters('Evidence:');
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->characters('Full name:');
      $writer->endTag('th');
      $writer->endTag('tr');
      
      foreach my $ass (@{$association_list}) {
	$self->__draw_association(-association=>$ass,
				 -session=>$session);
      }

      $writer->endTag('form');
      $writer->endTag('table');
    } else {
      $writer->characters(" None selected.");  
    }
  }
} 

=head2 drawImagoGeneAssociationList

    Usage   - $xml_out->drawTerm(-association_list=>$term->association_list, );
    Returns - None
            
Draws a table with :

Gene product link.   Database.    Evidencelist.  

=cut

sub drawImagoGeneAssociationList {
  my $self = shift;
  my ($association_list, $term_list, $session) =
    rearrange([qw(association_list term_list session)], @_);
  my $href_pass_alongs = $session->get_session_settings_urlstring;
  my $query_extension = '';
  
  $self->drawPopupJscript;
  
  my $writer = $self->{'writer'};
  
  
  if ($term_list) {
    if (scalar(@{$term_list}) != 0) {	
      $writer->startTag('table');
      $writer->startTag('tr');
      $writer->startTag('th',
		       'colspan'=>'4',
		       'align'=>'left');
      $writer->characters('ImaGO Term:');
      $writer->endTag('tr');
      $writer->startTag('tr');
      $writer->startTag('th',
			align=>'left',
			'nowrap'=>''
		       );
      $writer->out("&nbsp;&nbsp;");
      $writer->characters('Expression Pattern:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left' );
      $writer->characters('Annotation Report:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->characters('Gene Report:');
      $writer->endTag('th');
      $writer->endTag('tr');
      my $ass_page = $session->get_param('association_page') || 1;
      my $low_association_count = ($ass_page - 1) * 1000; 
      my $high_association_count = $ass_page * 1000;
      my $association_count = 1;
      my $have_drawn_yet = 0;
      foreach my $term (@$term_list) {
	my $current_association_count = $association_count;
	if ($association_count < $high_association_count || $ass_page eq 'all') {
	  if ($current_association_count >= $low_association_count) {
	    $writer->startTag('tr');
	    $writer->startTag('td', 
			      'colspan'=>'4');
	    $writer->startTag('a',
			      'href'=>'go.cgi?query='.$term->public_acc.'&view=details&search_constraint=terms&depth=0'.$href_pass_alongs);  
	    $writer->characters($term->public_acc." : ".$term->name);
	    $writer->endTag('a');
	    $writer->endTag('td');
	    $writer->endTag('tr');
	    foreach my $ass (@{$term->association_list}) {
	      $self->__draw_imago_association(-association=>$ass,
				       -session=>$session);
	      $association_count = $association_count + 1;
	    }
	    $have_drawn_yet = 1;
	  } else {
	    $association_count = $association_count + scalar(@{$term->association_list});
	  }
	}
      }
      my $is_next = 1;
      if ($association_count < $high_association_count) {
	$is_next = 0;
      }
      if ($have_drawn_yet == 0) {
	$writer->startTag('tr');
	$writer->startTag('td', 
			  'colspan'=>'4');
	$writer->characters(" None on this page.");  
	$writer->endTag('td');
	$writer->endTag('tr'); 
      }
      $writer->startTag('tr');
      $writer->startTag('td', 'colspan'=>'2');
      $writer->endTag('td');
      $writer->startTag('td', 'colspan'=>'2');
	$writer->endTag('td');
	$writer->endTag('tr'); 
      $writer->startTag('tr');
      $writer->startTag('td', 
			'colspan'=>'4');
      $writer->startTag('font',
			'size'=>'-1');
      $self->drawAssociationPageIterator(-session=>$session,
					-is_next=>$is_next);
      $writer->endTag('td');
      $writer->endTag('tr'); 
      $writer->endTag('table');
    } else {
      $writer->characters(" None selected.");  
    }
  } elsif ($association_list) {
    if (scalar(@{$association_list}) != 0) {
      $writer->startTag('table');
      $writer->startTag('tr');
      $writer->startTag('th',
			align=>'left');
      $writer->characters('Gene Symbol:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left' );
      $writer->characters('Datasource:');
      $writer->out("&nbsp;&nbsp;&nbsp;&nbsp;");
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->startTag('a',
			'href'=>'go.cgi?def=ev_codes');
      $writer->characters('Evidence:');
      $writer->endTag('th');
      $writer->startTag('th',
			'align'=>'left');
      $writer->characters('Full name:');
      $writer->endTag('th');
      $writer->endTag('tr');
      
      foreach my $ass (@{$association_list}) {
	$self->__draw_imago_association(-association=>$ass,
				 -session=>$session);
      }

      $writer->endTag('form');
      $writer->endTag('table');
    } else {
      $writer->characters(" None selected.");  
    }
  }
} 

=head2 drawGeneAssociationSummary

Depracated.

=cut

sub drawGeneAssociationSummary {
    my $self = shift;

    warn ('GO::IO::drawGeneAssociationSummary is depracated.');
}

sub drawGeneAssociationFilterWidget {
  my $self = shift;
  my ($term, $session) =
    rearrange([qw(term session)], @_);
  my $params = $session->get_param_hash; 
  
  my $writer = $self->{'writer'};
  
  $writer->endTag('td');

  $writer->startTag('td',
		    'rowspan'=>'3',
		   'valign'=>'top',
		    'nowrap'=>'');
  $writer->startTag('b');
  $writer->startTag('font',
		   'size'=>'-1');
  $writer->characters('Gene Filters:');
  $writer->endTag('font');
  $writer->endTag('b');
  $writer->endTag('td');
  $writer->startTag('td',
		   'valign'=>'top');
  $writer->startTag('form',
		   'action'=>'go.cgi',
		   'name'=>'gaf_widget');
  $writer->startTag('b');
  $writer->startTag('font',
		   'size'=>'-1');
  $writer->characters('Filter by database: ');
  $writer->startTag('br');
  $self->_make_form_hiddens(-session=>$session, -fields=>['session_id', 'query', 'search_constraint']);
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'view',
		    'value'=>'details'
		   );
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'depth',
		    'value'=>'0'
		   );
  $self->__draw_species_selector(-session=>$session);
  $writer->startTag('br');
  $writer->characters('Filter by Evidence for Association:');
  $writer->startTag('br');
  $writer->startTag('font');
  $writer->endTag('b');
  $self->__draw_evidence_selector(-session=>$session);
  $writer->startTag('br');
  $writer->emptyTag('input',
		    'type'=>'submit',
		    'value'=>'Filter Associated Genes');
  $writer->endTag('form');
}

sub __draw_evidence_selector {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  my $writer = $self->{'writer'};
  my $params = $session->get_param_hash; 
  
  my @selected_ev = split('\0', %$params->{'ev_code'});
  my @ev_code_list = ('ca', 'IMP', 'IGI', 'IPI', 'ISS', 'IDA', 'IEP', 'TAS', 'NAS');#, 'IEA');

  $writer->startTag('select',
		   'name'=>'ev_code',
		   'multiple'=>'yes',
		   'size'=>'3');
  foreach my $ev (@ev_code_list) {
    if ($ev eq 'ca' ) {
      if (scalar(@selected_ev) == 0) {
	$writer->startTag('option', 
			  'value'=>$ev,
			  'selected'=>'');
      } elsif ($self->__is_inside($ev, \@selected_ev)) {
	$writer->startTag('option', 
			  'value'=>$ev,
			  'selected'=>'');
      } else {
	$writer->startTag('option', 
			  'value'=>$ev);
      }
    }
    elsif ($self->__is_inside($ev, \@selected_ev)) {
      $writer->startTag('option', 
			'value'=>$ev,
			'selected'=>'');
    } else {
      $writer->startTag('option', 
			'value'=>$ev);
    }
    $writer->characters(GO::CGI::NameMunger->get_full_name($ev));
    $writer->endTag('option');
  }
  $writer->endTag('select');
}

sub __draw_species_selector {
  my $self = shift;
  my ($session, $style) =
    rearrange([qw(session style)], @_);

  my $params = $session->get_param_hash; 
  my $writer = $self->{'writer'};
  
  my @selected_dbs = split('\0', %$params->{'species_db'});
  my @db_list = ('all', 'fb', 'sgd', 'mgi', 'genedb_spombe', 'sptr', 'cgen', 'tair', 'wb', 'ensembl', 'rgd',
		'tigr_cmr', 'tigrfams', 'tigr_ath1', 'gr', 'genedb_tsetse', 'genedb_tbrucei', 'genedb_pfalciparum', 'genedb_lmajor');
  if ($style eq 'short') {
      $writer->startTag('select', 
			'name'=>'species_db',
				);
  } else {
      $writer->startTag('select', 
			'name'=>'species_db',
			'multiple'=>'yes',
			'size'=>'3'
			);
  }
  foreach my $db (@db_list) {
    if ($db eq 'all' && scalar(@selected_dbs) == 0) {
      $writer->startTag('option',
			'value'=>$db,
			'selected'=>'');
    }
    elsif ($self->__is_inside($db, \@selected_dbs)) {
      $writer->startTag('option', 
			'value'=>$db,
			'selected'=>'');
    } else {
    $writer->startTag('font',
		      'size'=>'-2');
    $writer->startTag('option', 
		     'value'=>$db
		     );
    }
    $writer->characters(GO::CGI::NameMunger->get_human_name($db));
    $writer->endTag('option');
    $writer->endTag('font');
  }
  $writer->endTag('select');
}


sub _make_form_hiddens {
  my $self = shift;
  my ($session, $fields) =
    rearrange([qw(session fields)], @_);

  my $writer = $self->{'writer'};
  my $param_hash = $session->get_param_hash;
  foreach my $param (keys %$param_hash) {
    if ($self->__is_inside($param, $fields)) {
      foreach my $value (split("\0", %$param_hash->{$param})) {
        $writer->emptyTag('input',
                          'type'=>'hidden',
                          'name'=>$param,
                          'value'=>$value
                         );
      }
    }
  }
}

sub drawAssociationPageIterator {
  my $self = shift;
    my ($session, $is_next) =
      rearrange([qw(session is_next)], @_);
  my $writer = $self->{'writer'};
  my $href_pass_alongs = $session->get_session_settings_urlstring;
  my $query_extension = $session->get_session_settings_urlstring(['query']);
  
  my $ass_page = $session->get_param('association_page') || 1;

  my $prev_num = $ass_page - 1;
  if ($ass_page != 1 && $ass_page ne 'all') {
    $writer->startTag('a',
		      'href'=>'go.cgi?view=details&depth=0'.$href_pass_alongs.$query_extension.'&association_page='.$prev_num);
}
  $writer->characters("Previous Page");
  if ($ass_page != 1 && $ass_page ne 'all') {
    $writer->endTag('a');
  }
  $writer->out("&nbsp;&nbsp;");
  my $next_num = $ass_page + 1;
  if ($is_next && $ass_page ne 'all') {
    $writer->startTag('a',
		      'href'=>'go.cgi?view=details&depth=0'.$href_pass_alongs.$query_extension.'&association_page='.$next_num);
  }
  $writer->characters("Next Page");
  if ($is_next && $ass_page ne 'all') {
    $writer->endTag('a');
  }
  $writer->out("&nbsp;&nbsp;");
  if ($ass_page != 1) {
    $writer->startTag('a',
		      'href'=>'go.cgi?view=details&depth=0'.$href_pass_alongs.$query_extension.'&association_page=1');
  }
  $writer->characters("First Page");
  if ($ass_page != 1) {
    $writer->endTag('a');
  }
  $writer->out("&nbsp;&nbsp;");
  if ($ass_page ne 'all') {
    $writer->startTag('a',
		      'href'=>'go.cgi?view=details&depth=0'.$href_pass_alongs.$query_extension.'&association_page=all');
  }
  $writer->characters("All Gene Products");
  if ($ass_page ne 'all') {
    $writer->endTag('a');
  }
}

sub n_non_ieas {
  my $self = shift;
    my $ass = shift;
 
    my $count = 0;
    foreach my $a (@$ass) {
	foreach my $ev (@{$a->evidence_list}) {
	    if ($ev->code ne 'IEA') { $count += 1;}
	}
    }
    return $count;
    
}

sub __draw_association {
  my $self = shift;
  my ($ass, $session) =
    rearrange([qw(association session)], @_);

  my $writer = $self->{'writer'};

  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);

  $writer->startTag('tr');
  $writer->startTag('td', 'nowrap'=>'');
  $writer->out('&nbsp;&nbsp;');
  $writer->startTag('input',
		    'type'=>'checkbox',
		    'name'=>'gp',
		    'value'=>$ass->gene_product->acc			
		   );
  $writer->out('&nbsp;&nbsp;');
  if ($ass->is_not) {
    $writer->startTag('i');
    $writer->startTag('b');
    $writer->out('NOT ');
    $writer->endTag('b');
    my $url = 'go.cgi?gp='.$ass->gene_product->acc.'&search_constraint=gp&view=details'.$href_pass_alongs;
    if ($url) {
      $writer->startTag('a', 
			'href'=>$url
		       );
    }
    $writer->characters(spell_greek($ass->gene_product->symbol));
    if ($url) {
      $writer->endTag('a');
    }
    $writer->endTag('i');
  } else {
    my $url = 'go.cgi?gp='.$ass->gene_product->acc.'&search_constraint=gp&view=details'.$href_pass_alongs;
    if ($url) {
      $writer->startTag('a', 
			'href'=>$url
		       );
    }
    $writer->characters(spell_greek($ass->gene_product->symbol));
    if ($url) {
      $writer->endTag('a');
      
    }
  }
  
  if ($session->get_param('show_blast') eq 'yes') {
    if ($ass->gene_product->to_fasta) {
    $self->__draw_GOst_link(-session=>$session,
			    -gene_product=>$ass->gene_product);
    }
  }
  $writer->endTag('td');
  $writer->startTag('td');
  my $url = GO::CGI::NameMunger->get_url(
					 -database=>$ass->gene_product->speciesdb,
					 -acc_no=>$ass->gene_product->acc
					);
  if ($url) {
    $writer->startTag('a',
		      'href'=>$url);
  }
  $writer->characters(GO::CGI::NameMunger->get_human_name($ass->gene_product->speciesdb) ||
		     $ass->gene_product->speciesdb);
  if ($url ) {
    $writer->endTag('a');
  }

  $writer->endTag('td');
  $writer->startTag('td',
		   'nowrap'=>'');
  ## This mainly happens when collapse_ev is set to 1
  ## in the config file.  This will only give you the 
  ##first evidence link of each evidence code
  if ($session->get_param('COLLAPSE_EV')) {
    my %ev_type_hash;
    foreach my $ev(@{$ass->evidence_list}) {
      if (%ev_type_hash->{$ev->code} != 1) {
	%ev_type_hash->{$ev->code} = 1;
	my $ref_url = GO::CGI::NameMunger->get_ref_url(
						       -database=>$ev->xref->xref_dbname,
						       -acc_no=>$ev->xref->xref_key
						      );
	if ($ref_url && $ref_url ne 'none') {
	  $writer->startTag('a',
			    'href'=>$ref_url);
	  $writer->characters($ev->code);
	  $writer->endTag('a');
	  $writer->out('&nbsp;&nbsp;');
	} else {
	  $writer->characters($ev->code);
	  $writer->characters(" - ".$ev->xref->xref_key." ");
	  $writer->out('&nbsp;&nbsp;');
	}
      }
    }
  } else {
    foreach my $ev(@{$ass->evidence_list}) {
      my $ref_url = GO::CGI::NameMunger->get_ref_url(
						     -database=>$ev->xref->xref_dbname,
						     -acc_no=>$ev->xref->xref_key
						    );
      if ($ref_url && $ref_url ne 'none') {
	$writer->startTag('a', 
			  'href'=>$ref_url);
	$writer->characters($ev->code);
	$writer->endTag('a');
	$writer->out('&nbsp;&nbsp;');
      } else {
	$writer->characters($ev->code);
	print " - ";
	$writer->characters($ev->xref->xref_key." ");
	$writer->out('&nbsp;&nbsp;');
      }
      #if ($ev->code eq 'ISS') {
	my $refs = $ev->xref_list;
	shift @$refs;
	foreach my $ref(@$refs) {
	  my $ref_url = GO::CGI::NameMunger->get_ref_url(
							 -database=>$ref->xref_dbname,
							 -acc_no=>$ref->xref_key
							);
	  if ($ref_url && $ref_url ne 'none') {
	    $writer->startTag('a', 
			      'href'=>$ref_url);
	    $writer->characters('- With ');
	    $writer->endTag('a');
	    $writer->out('&nbsp;&nbsp;');
	  } else {
	      if ($session->get_param('show_unlinked_iss')) {
		  $writer->characters('- With '.$ref->xref_dbname.":".$ref->xref_key." ");
		  $writer->out('&nbsp;&nbsp;');
	      }
	  }
	}
      #}
    }
  }
  $writer->endTag('td');
    $writer->startTag('td',
		      'nowrap'=>'');
    if ($ass->gene_product->full_name) {
      $writer->characters($ass->gene_product->full_name);
    } else {
      $writer->characters('Not Available');
    }
  $writer->endTag('td');
  $writer->endTag('tr');
}

sub __draw_GOst_link {
  my $self = shift;
  my ($gene_product, $session)  = 
    rearrange([qw(gene_product session)], @_);

  my $writer = $self->{'writer'};

  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
  if ($session->get_param('show_blast') eq 'yes') {
    if ($gene_product->to_fasta) {
      my $seq_id = uc($gene_product->speciesdb)."|".$gene_product->acc;
      $writer->startTag('a', 
			'href'=>'go.cgi?view=blast&action=blast&program=blastp&seq_id='.$seq_id.$href_pass_alongs
		       );
      my $image_dir = $session->get_param('image_dir') || "../images";
      $writer->emptyTag('img',
			'src'=>"$image_dir/GOst.png",
			'height'=>12,
			'width'=>28,
			'border'=>0);
      $writer->endTag('a');
    }
  }
}

sub __draw_imago_association {
  my $self = shift;
  my ($ass, $session) =
    rearrange([qw(association session)], @_);

  my $writer = $self->{'writer'};

  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);

  my $gene = $ass->gene_product->get_property('gene');
  #filter out cDNA without gene link
  return unless ($gene);

  $writer->startTag('tr');

  ########################
  # Ev Link
  ########################

  $writer->startTag('td',
		   'nowrap'=>'');
  $writer->out('&nbsp;&nbsp;&nbsp;');
  ## This mainly happens when collapse_ev is set to 1
  ## in the config file.  This will only give you the 
  ##first evidence link of each evidence code
  if ($session->get_param('COLLAPSE_EV')) {
    my %ev_type_hash;
    foreach my $ev(@{$ass->evidence_list}) {
      if (%ev_type_hash->{$ev->code} != 1) {
	%ev_type_hash->{$ev->code} = 1;
	my $ref_url = GO::CGI::NameMunger->get_ref_url(
						       -database=>$ev->xref->xref_dbname,
						       -acc_no=>$ev->xref->xref_key
						      );
	if ($ref_url && $ref_url ne 'none') {
	  $writer->startTag('a', 
			    'href'=>$ref_url);
	  $writer->characters('Expression Pattern');
	  $writer->endTag('a');
	  $writer->out('&nbsp;&nbsp;');
	} else {
	  $writer->characters($ev->code);
	  
	  $writer->characters(" - ".$ev->xref->xref_key." ");
	  $writer->out('&nbsp;&nbsp;');
	}
      }
    }
  } else {
    foreach my $ev(@{$ass->evidence_list}) {
      my $ref_url = GO::CGI::NameMunger->get_ref_url(
						     -database=>$ev->xref->xref_dbname,
						     -acc_no=>$ev->xref->xref_key
						    );
      if ($ref_url && $ref_url ne 'none') {
	$writer->startTag('a', 
			  'href'=>$ref_url);
	$writer->characters('Expression Pattern');
	$writer->endTag('a');
	$writer->out('&nbsp;&nbsp;');
      } else {
	$writer->characters('Expression Pattern');
	
	$writer->characters(" - ".$ev->xref->xref_key." ");
	$writer->out('&nbsp;&nbsp;');
      }
    }
  }
  $writer->endTag('td');

  ###########################
  # gene Link
  ##########################

  $writer->startTag('td');
#  my $cdna = $ass->gene_product->acc;
  my $url = "http://www.fruitfly.org/cgi-bin/annot/gene?$gene";
  if ($gene) {
    $writer->startTag('a',
		      'href'=>$url);
    $writer->characters($gene);
    $writer->endTag('a');
  }
  $writer->endTag('td');

  ###########################
  # Flybase Link
  ##########################

  $writer->startTag('td');
  my $fbgn = $ass->gene_product->get_property('fbgn');
  $url = "http://flybase.bio.indiana.edu/.bin/fbidq.html?$fbgn";
  if ($fbgn) {
    $writer->startTag('a',
		      'href'=>$url);
    $writer->characters($fbgn);
    $writer->endTag('a');
  }
  $writer->endTag('td');

  $writer->endTag('tr');
}

sub drawBlastQuery {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);


  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
  my $params = $session->get_param_hash;
  my $writer = $self->{'writer'};

  $self->check_blast_jobs(-session=>$session);

  if (!$session->get_param('deadly_seq_input_error')) {
      my $transaction = $session->get_data;
      $writer->startTag('h1');
      $writer->characters('GOst Results:');
      $writer->endTag('h1');
      if ($session->get_param('seq_input_error')) {
	  $self->drawErrorMessage(-session=>$session,
				  -error_type=>'seq_input_error'
				  );
      }
      $writer->startTag('h2');
      $writer->characters("Your query sequence: ");
      $writer->endTag('h2');
      $writer->startTag('pre');
      $writer->characters($session->get_param('sequence'));
      $writer->endTag('pre');
      $writer->startTag('p');
      
      require "Pipeline/CGI/Analysis.pm";
      require "GO/CGI/Analysis.pm";
    GO::CGI::Analysis->launchJob(-session=>$session);
      my $job_link = "go.cgi?action=get_job_by_id&view=blast&session_id=".$session->get_param('session_id');
      
      $writer->startTag('h2');
      $writer->out('Results:');
      $writer->endTag('h2');

      $writer->out("Your job has been submitted to AmiGO.  ");
      $writer->out("Your results should be ready shortly. ");
      $writer->startTag('br');
      $writer->startTag('br');
     $writer->startTag('a', 
			'href'=>$job_link);
      $writer->out('Retrieve your job.');
      $writer->endTag('a');
      
  } else {
      $self->drawErrorMessage(-session=>$session,
			      -error_type=>'deadly_seq_input_error'
			      );
      
  } 
}

sub drawRawBlastData {
  my $self = shift;
  my ($session, $raw) =
    rearrange([qw(session raw)], @_);
  my $writer = $self->{'writer'};
    require "GO/CGI/Blast.pm";

    my ($node_graph, $symbols) = GO::CGI::Blast->getgraph($raw, $session->apph);
    if (!$node_graph) {
      $writer->startTag('h2');
      $writer->characters('High Scoring Gene Products:');
      $writer->endTag('h2');
      $writer->characters('Sorry, your GOst search produced no hits.');
    } else {
      $writer->startTag('h2');
      $writer->characters('High Scoring Gene Products:');
      $writer->endTag('h2');
      $self->drawGeneProductList(-session=>$session,
				 -list=>$node_graph->focus_nodes,
				 -gp_order=>$symbols,
				 -is_popup=>"1"
				);
    }
    $writer->startTag('h2');
    $writer->characters('Blast Text:');
    $writer->endTag('h2');

    my $fh = new FileHandle;
    my $filename = "sessions/".$session->get_param('session_id')."_tmpseq2";
    $fh->open( "> $filename");
    print $fh $raw;
    $fh->close();

    require "WebReports/BlastMarkup.pm";
    import WebReports::BlastMarkup qw(markup);

#    my $blast_out = WebReports::BlastMarkup->markup($filename);
    my $blast_out = markup($filename);
    $writer->startTag('pre');
    foreach my $line (@$blast_out) {
      print $line;
    }
    $writer->endTag('pre');

    `rm $filename`;

}


sub finish_job {
  my $self = shift;
  my $job = shift;

# while ($job->state ne 'FIN') {
    sleep 1;
#    $job->nudge;
#    if ($job->state eq 'FAIL') {
#      last;
#    }
#  }
}

sub check_blast_jobs {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);

  require "Pipeline/Manager.pm";
  # Mark
  if ($session->get_param('last_job')) {
    my $seq_id = $session->get_param('last_job');
    #my $mgr = Pipeline::Manager->new;
    
#    my $job = $mgr->get_job({id=>$seq_id});
    
#    if ($job) {
#      if ($job->state ne 'FIN') {
#	$session->__set_param(-field=>'deadly_seq_input_error',
#			      -values=>['job_still_running']);
#      }
#      if ($job->state eq 'FAIL') {
#	$session->__set_param(-field=>'deadly_seq_input_error',
#			      -values=>['job_failed']);
#      }
#    }
  }
}

sub drawBlastResults {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  my $writer = $self->{'writer'};

  require "Pipeline/Manager.pm";
  my $data_dir = $session->get_param('data_dir');;

  my $transaction = $session->get_data;
  $writer->startTag('h1');
  $writer->characters('GOst Results:');
  $writer->endTag('h1');
  $writer->startTag('h2');
  $writer->characters("Your query sequence: ");
  $writer->endTag('h2');
  $writer->startTag('pre');
  
  my $seq_file = "$data_dir/".$session->get_param('session_id')."_blast/current_seq";

  $writer->startTag('pre');
  open (SEQFILE, $seq_file);
  while (my $line = <SEQFILE>) {
      $writer->out($line);
  }
  close FILE;
  $writer->endTag('pre');

  $writer->endTag('pre');
  $writer->startTag('p');

  my $seq_id = $session->get_param('last_job');


  my $result_file = "$data_dir/".$session->get_param('session_id')."_blast/result";

  my $raw_result;
  if(open (FILE, $result_file)) {
      while (my $line = <FILE>) {
	  $raw_result .= $line;
      }
      close FILE;
      
      $raw_result =~ s/^Warning\:\ no.*\n//;
      $raw_result =~ s/^Thus\ no\ job.*//;

      $self->drawRawBlastData(-session=>$session,
			      -raw=>$raw_result);
  } else {
      $writer->startTag('h2');
      $writer->out('Results:');
      $writer->endTag('h2');


      $writer->out('Sorry, your job has not yet finished.  ');
      $writer->out('Please ');
      my $job_link = "go.cgi?action=get_job_by_id&view=blast&session_id=".$session->get_param('session_id');
      $writer->startTag('a',
			'href'=>$job_link
			);
      $writer->out('click here ');
      $writer->endTag('a');
      $writer->out('to check again. ');
      $writer->startTag('br');

  }
}

sub drawBlastForm {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $params = $session->get_param_hash;
  my $writer = $self->{'writer'};
  $writer->startTable();
  $writer->startTag('form',
		    'enctype'=>"multipart/form-data",
		    'method'=>'POST',
		    'action'=>'go.cgi',
		    'name'=>'blast_form'
		   );
  $writer->startTag('font',
		    'size'=>'+1');
  $writer->characters("Welcome to GOst, the ");
  $writer->startTag('u');
  $writer->characters("G");
  $writer->endTag('u');
  $writer->characters("ene ");
  $writer->startTag('u');
  $writer->characters("O");
  $writer->endTag('u');
  $writer->characters("ntology Bla");
  $writer->startTag('u');
  $writer->characters("st");
  $writer->endTag('u');
  $writer->characters(" server.  ");
  $writer->endTag('font');
  $writer->startTag('p');
#  $writer->characters("To perform a GOst search, either: ");
#  $writer->startTag('p');
  $writer->characters("Enter a UNIPROT/SWISS-PROT sequence ID: ");
  $writer->emptyTag('input',
		    'type'=>'text',
		    'name'=>'sptr_id'
		   );

  $writer->startTag('p');
  $writer->characters("Paste in a FASTA sequence:");
  $writer->startTag('br');
  $writer->startTag('textarea',
		    'name'=>'seq',
		    'cols'=>'50',
		    'rows'=>'20'
		   );
  $writer->endTag('textarea');
  $writer->startTag('br');
  $self->_make_form_hiddens(-session=>$session,
			    -fields=>['session_id']);
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'action',
		    'value'=>'blast');
  $writer->emptyTag('input',
		    'type'=>'hidden',
		    'name'=>'view',
		    'value'=>'blast');
  $writer->startTag('p');
  $writer->characters("Or upload a fasta file:");
  $writer->startTag('br');
  $writer->emptyTag('input',
		    'type'=>'file',
		    'name'=>'upfile'
		   );
  $writer->startTag('p');
  $writer->startTag('b');
  $writer->out('Threshhold: ');
  $writer->endTag('b');
  $writer->startTag('select',
		    'name'=>'threshhold');
  my @options = ('1.0', '0.1', '0.01', '0.001');
  my $selected_option = 0;
  foreach my $option (@options) {
    if ((!$selected_option && $option eq '0.001') ||
	$session->get_param('threshhold') eq $option) {
      $writer->startTag('option', 'selected'=>'yes');
      $writer->out($option);
      $writer->endTag('option');
      $selected_option = 1;
    } else {
      $writer->startTag('option');
      $writer->out($option);
      $writer->endTag('option');
    }
  }
  $writer->endTag('select');
  
  $writer->emptyTag('input',
		    'type'=>'submit');
  $writer->endTag('form');
  $writer->endTable();

}

sub drawGostHeader {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  
  my $image_dir = $session->get_param('image_dir') || "../images";
  my $params = $session->get_param_hash;
  my $writer = $self->{'writer'};

  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
  $writer->startTag('table',
		    'cellspacing'=>'0',
		    'cellpadding'=>'2',
		    'bgcolor'=>'9fb7ea'
		   );
  $writer->startTag('tr');
  #  The logo.
  $writer->startTag('td',
		    'rowspan'=>'1',
		    'cellspacing'=>'0',
		    'nowrap'=>''
		    );
  $self->__drawPopupLogo(-session=>$session);

  $writer->startTag('img',
		    'src'=>"$image_dir/GOst.png"
		   );
  $writer->endTag('img');
  $writer->endTag('td');
  $writer->startTag('td',
		   'valign'=>'bottom');
  $writer->startTag('font',
		    'size'=>'-1');
  $writer->startTag('a',
		    'href'=>'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']));
  $writer->characters('New GOst Search');
  $writer->endTag('a');
  $writer->endTag('font');
  $self->lastJobLink(-session=>$session);
  $writer->endTag('td');
  $writer->endTag('tr');
  $writer->endTag('table');

}

=head2 writeSummaryPage

    Args    -session=>$session, #GO::CGI::Session

=cut


sub writeSummaryPage {
  my $self = shift;
  my ($session) =
    rearrange([qw(session)], @_);
  my $writer = $self->{'writer'};
  

  my $html_dir = $session->get_param('html_dir') || "../docs";
  my $file = "$html_dir/amigo_summary_page.html";
  
  open(FILE, "$file") or die $!;
  while (<FILE>) {
    $writer->out($_);
  }
  close FILE;

}

=head2 drawSummaryPage

    Usage   - $xml_out->drawSummaryPage(-session=>$session,
				       -info=>$summary_info);
    Returns - None
    Args    -session=>$session, #GO::CGI::Session

  The summary info comes from GO::CGI::Query->getSummaryInfo

=cut


sub drawSummaryPage {
    my $self = shift;
    my ($session, $info) =
	rearrange([qw(session info)], @_);
    
    my $apph = $session->apph;
    
    require "GD/Graph/pie.pm";
    
    if ($session->get_param('action') eq 'summary') {
	
	my $graph = $session->get_data();
	my $nit = $graph->create_iterator;
	
	my $is_selected = 0;
	my $selected_level;
	
	## First we run through the iterator and chop off the
	## Graph's dangling branches.
	
	while (my $ni = $nit->next_node_instance) {
	    if ($selected_level) {
		if ($ni->depth <= $selected_level) {
		    $selected_level = undef;
		    $is_selected = 0;
		}
	    }
	    if ($ni->term->acc eq $session->get_param('query')) {
		$is_selected = 1;
		$selected_level = $ni->depth;
	    }
	    
	    if ($is_selected) {
		if (!$self->__is_inside($ni->term->acc, $session->get_param_values('open_1'))) {
		    eval {
	      $graph->close_below($ni->term);
	  };
	  }
	    }
	}
	
	## Now we do the real work.
	
	my $graph = $session->get_data();
	my $nit = $graph->create_iterator;
	
	my @data = ([], []);
	my $is_selected = 0;
	my $selected_level;
	my $info;
	
	
	while (my $ni = $nit->next_node_instance) {
	    if ($selected_level) {
		if ($ni->depth <= $selected_level) {
		    $selected_level = undef;
		    $is_selected = 0;
		}
	    }
	    if ($ni->term->acc eq $session->get_param('query')) {
		$is_selected = 1;
		$selected_level = $ni->depth;
		my $node = $ni->term;
		my $name = $node->name;
		%{$info}->{$name}->{'is_leaf'} = scalar(@{$apph->get_relationships({parent_acc=>$node->acc})});
		%{$info}->{$name}->{'acc'} = $node->acc;
		%{$info}->{$name}->{'name'} = $node->name;
		my $count = $apph->get_product_count({term=>$node});
		%{$info}->{$name}->{'all'} = $count;
	    }
	    
	    if ($is_selected) {
		if ($self->__is_in($ni->term->acc, $graph->focus_nodes)) {
		    foreach my $node (@{$graph->get_child_terms($ni->term->acc)}) {
			my $name = $node->name;
			%{$info}->{$name}->{'is_leaf'} = scalar(@{$apph->get_relationships({parent_acc=>$node->acc})});
			%{$info}->{$name}->{'acc'} = $node->acc;
			%{$info}->{$name}->{'name'} = $node->name;
			if (!$self->__is_in($node->acc, $graph->focus_nodes)) {
			    %{$info}->{$name}->{'all'} = 
				$apph->get_deep_product_count({term=>$node});
			} else {
			    my $count = $apph->get_product_count({term=>$node});
			    %{$info}->{$name}->{'all'} = $count;
			}
		    }
		}
	    }
	}
	
	
	if ($session->get_param('format') eq 'text') {
	    my $writer = $self->{'writer'};
	    my $query = $session->get_param('query');
	    my $query_term = $graph->get_term($query);
	    my $n_total_products = $query_term->n_deep_products;
	    $writer->characters('!Gene Products Annotated below '.$query_term->name."\n");
	    $writer->out("all ".$query_term->name."\t");
	    $writer->out("$n_total_products\t");
	    $writer->out("100.0\n");
	    foreach my $entry (sort by_n_results (keys %{$info})) {
		my $n_products = $info->{$entry}->{'all'};
		$writer->out($info->{$entry}->{'name'});
		$writer->out("\t");
		$writer->out($n_products);
		$writer->out("\t");
		$writer->out(substr $n_products/$n_total_products*100, 0, 4);	
		$writer->out("\n");
	    }
	} else {
	    my $relative_image_dir = $session->get_param('tmp_image_dir_relative_to_docroot') || "tmp_images";
	    my $html_dir = $session->get_param('html_dir') || "../docs";
	    
	    my $image_dir = "$html_dir/$relative_image_dir";
	    
	    my $query = $session->get_param('query');
	    my $query_term = $graph->get_term($query);
	    my $n_total_products = $query_term->n_deep_products;
	    
	    my $writer = $self->{'writer'};
	    $writer->startTag('h2');
	    $writer->characters('Gene Products Annotated below '.$query_term->name);
	    $writer->endTag('h2');
	    $writer->startTable();
	    
	    @data = ([], []);
	    foreach my $key (keys %{$info}) {
		push @{@data->[0]}, $info->{$key}->{'name'};
		push @{@data->[1]}, $info->{$key}->{'all'};	
	    }
	    
	    
	    eval {
		my  $pie = GD::Graph::pie->new(400, 400);
		
		my $title = $query." : ".$query_term->name;
		
		$pie->set( 
			   title=>$title,
			   suppress_angle=>5,
			   start_angle=>30
			   );
		
		my $gd = $pie->plot(\@data);
		my $random_number = int(rand(10000));
		my $image_file = "$image_dir/$query.$random_number.sum.gif";
		
		open(IMG, ">$image_file") or die $!;
		binmode IMG;
		print IMG $gd->png;
		close IMG;
		
		`chmod a+r $image_file`;
		my $image_dir_rel_to_cgi = $session->get_param('tmp_image_dir') || "../tmp_images";
		$writer->emptyTag('img',
				  'src'=>"$image_dir_rel_to_cgi/$query.$random_number.sum.gif");
	    };
	    $writer->startTag('br');
	    $writer->startTag('br');
	    $writer->startTable;
	    $writer->startTag('b');
	    $writer->out('Term Name:');
	    $writer->endTag('b');
	    $writer->startCell('th');
	    $writer->out('Total:');
	    $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
	    $writer->startCell('th');
	    $writer->out('% of All '.$query_term->name.": ");
	    $writer->out('&nbsp;&nbsp;&nbsp;&nbsp;');
	    $writer->startRow();
	    $writer->startTag('b');
	    $writer->out('All '.$query_term->name);
	    $writer->endTag('b');
	    $writer->startCell();
	    $writer->startTag('b');
	    $writer->out($n_total_products);
	    $writer->endTag('b');
	    $writer->startCell();
	    $writer->startTag('b');
	    $writer->out('100.0');
	    $writer->endTag('b');
	    
	    foreach my $entry (sort by_n_results (keys %{$info})) {
		$writer->startRow();
		my $n_products = $info->{$entry}->{'all'};
		$writer->out($info->{$entry}->{'name'});
		$writer->startCell();
		$writer->out($n_products);
		$writer->startCell();
		$writer->out(substr $n_products/$n_total_products*100, 0, 4);
	    }
	    
	    $writer->endTable();
	    $writer->endTable();
	    sub by_n_results {
		$info->{$b}->{'all'} <=> $info->{$a}->{'all'};
	    };
	    my $href_args = $session->get_session_settings_urlstring(['session_id',
								 'action',
								 'view',
								 'query'
								 ]);
	    my $href = "go.cgi?$href_args&format=text";
	    $writer->startTag('p');
	    $writer->startTag('a',
			      'href'=>$href);
	    $writer->characters('Get Text Version');
	    $writer->endTag('a');
	    $writer->endTag('p');
	}
    } elsif ($session->get_param('query')) {
	my $info = $session->get_data();
	my @data = ([], []);
	my $relative_image_dir = $session->get_param('tmp_image_dir_relative_to_docroot') || "tmp_images";
	my $html_dir = $session->get_param('html_dir') || "../docs";
	my $image_dir = "$html_dir/$relative_image_dir";
	my $writer = $self->{'writer'};
	
	$writer->startTag('h2');
	$writer->characters('Summary of Curated Gene Associations per Term');
	$writer->endTag('h2');
	$writer->startTable();
	
	@data = ([], []);
	foreach my $term (sort no_case keys %{$info}) {
	    if ($term ne 'label') {
		push @{@data->[0]}, $term;
		push @{@data->[1]}, %{$info}->{$term}->{'all'};	
	    }
	}
	my $db = $session->get_param('species_db');
	
	my $graph = GD::Graph::pie->new(500, 500);
	my $label = GO::CGI::NameMunger->get_human_name(-database=>$db) || 'All Databases';
	$label .= ' : ';
	$label .= $info->{'label'};
	$graph->set( 
		     title=>$label,
		     suppress_angle=>5,
		     start_angle=>165
		     );
	
	my $gd = $graph->plot(\@data);
	my $query = $session->get_param('query');
	my $s1 = substr($query, 0, 1);
	my $s2 = substr($query, 0, 2);
	my $image_file = "$image_dir/$s1/$s2/$query.$db.gif";
	eval {
	    `mkdir "$image_dir/$s1"`;
	    `mkdir "$image_dir/$s1/$s2"`;
	    open(IMG, ">$image_file") or die $!;
	    binmode IMG;
	    print IMG $gd->png;
	    close IMG;
	};
	
	`chmod a+r $image_file`;
	
	my $image_dir_rel_to_cgi = $session->get_param('tmp_image_dir') || "../tmp_images";
	$writer->emptyTag('img',
			  'src'=>"$image_dir_rel_to_cgi/$s1/$s2/$query.$db.gif");
	$writer->startTag('br');
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id', 'species_db']);
	my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
	foreach my $child_term (sort no_case keys (%{$info})) {
	    if ($child_term ne 'label') {
		if (%{$info}->{$child_term}->{'is_leaf'} != 0 &&
		    %{$info}->{$child_term}->{'all'} != 0
	   ) {
		    $writer->startTag('a',
				      'href'=>'go.cgi?view=summary&query='.$info->{$child_term}->{'acc'}.$href_pass_alongs);
		}
		$writer->out($child_term);
		if (%{$info}->{$child_term}->{'is_leaf'} != 0 &&
		    %{$info}->{$child_term}->{'all'} != 0) {
		    $writer->endTag('a');
		}
		$writer->out(' : ');
		my $url = 'go.cgi?view=details&search_constraint=terms&query='.$info->{$child_term}->{'acc'}.$href_pass_alongs;
		$writer->startTag('a',
				  'href'=>'javascript:NewWindow(\''.$url.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
		$writer->out($info->{$child_term}->{'all'});	
		
		$writer->endTag('a');
		$writer->startTag('br');
	    }
	}
	$writer->endTable();
	
  } else {
    
    my $info = $session->get_data();
    my @data = ([], []);
    
    my $relative_image_dir = $session->get_param('tmp_image_dir_relative_to_docroot') || "tmp_images";
    my $html_dir = $session->get_param('html_dir') || "../docs";
    
    my $image_dir = "$html_dir/$relative_image_dir";
    
    my $writer = $self->{'writer'};
    $writer->startTag('h2');
    $writer->characters('Summary of Curated Gene Associations per Ontology');
    $writer->endTag('h2');
    $writer->startTable();
    
    foreach my $ont (keys %{$info}) {
      @data = ([], []);
      foreach my $db ( sort no_case keys %{$info->{$ont}}) {
	if ($db ne 'total' && $db ne 'name') {
	  push @{@data->[0]}, GO::CGI::NameMunger->get_human_name(-database=>$db);
	  push @{@data->[1]}, %{$info->{$ont}->{$db}}->{'all'};	
	}
      }
      
    my  $graph = GD::Graph::pie->new(300, 300);
      
      my $title = $info->{$ont}->{'name'};

      $graph->set( 
		  title=>$title,
		  suppress_angle=>5,
		  start_angle=>180
		 );
      
      my $gd = $graph->plot(\@data);
      
      my $image_file = "$image_dir/$ont.sum.gif";
      open(IMG, ">$image_file") or die $!;
      binmode IMG;
      print IMG $gd->png;
      close IMG;
      
      `chmod a+r $image_file`;
      my $image_dir_rel_to_cgi = $session->get_param('tmp_image_dir') || "../tmp_images";
      $writer->emptyTag('img',
			'src'=>"$image_dir_rel_to_cgi/$ont.sum.gif");
      $writer->startTag('br');
      my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id']);
      my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
      foreach my $db ( sort keys %{$info->{$ont}}) {
	if ($db ne 'total' && $db ne 'name') {
	  if (%{$info->{$ont}->{$db}}->{'all'} != 0) {
	    $writer->startTag('a',
			      'href'=>"go.cgi?view=summary&query=$ont&species_db=$db$href_pass_alongs");
	  }
	  $writer->out(GO::CGI::NameMunger->get_human_name(-database=>$db));
	  if (%{$info->{$ont}->{$db}}->{'all'} != 0) {
	    $writer->endTag('a');
	  }
	  $writer->out(' : ');
	  $writer->out(%{$info->{$ont}->{$db}}->{'all'});	
	  $writer->startTag('br');
	}
      }
      $writer->startTag('b');
      $writer->startTag('a',
			'href'=>"go.cgi?view=summary&query=$ont$href_pass_alongs");
      $writer->out('Total');
      $writer->endTag('a');
      $writer->out(' : ');
      $writer->out(%{$info->{$ont}->{'total'}}->{'all'});
      $writer->endTag('b');
      $writer->startTag('br');
      $writer->startCell;
    }
    $writer->endTable();
  }
}

sub start_popup_link {
  my $self = shift;
  my ($session, $url) =
    rearrange([qw(session url)], @_);

  my $writer = $self->{'writer'};
  my $window_name = $session->get_param('CHILD_WINDOW') || 'Details';
  $writer->startTag('a',
		    'href'=>'javascript:NewWindow(\''.$url.'\', \''.$window_name.'\', \'550\', \'650\', \'custom\', \'front\');');
}

sub no_case {
  lc($a) cmp lc($b);
}

sub __is_in {
    my $self = shift;
    my ($acc, $array) = @_;

    foreach my $node(@$array) {
	if ($acc eq $node->acc) {
	    return 1;
	}
    }
    return 0;
}

sub __is_inside {
    my $self = shift;
    my ($acc, $array) = @_;
    foreach my $node(@$array) {
	if ($acc eq $node) {
	    return 1;
	}
    }
    return 0;
}

sub __is_in_numerical_list {
    my $self = shift;
    my ($acc, $array) = @_;

    foreach my $node(@$array) {
	if (int($acc) == int($node)) {
	    return 1;
	}
    }
    return 0;
}

sub finish_job {
#    my $job = shift;
#    while ($job->state ne 'FIN') {
#	sleep 1;
#	$job->nudge;
#	if ($job->state eq 'FAIL') {
#	  last;
#	}
#    }
}


sub __strip_accession {
  my $self = shift;
  my $acc = shift;
  
  $acc =~ s/^\s*(.*?)\s*$/$1/;
  $acc =~ s/^GO:?//;
  $acc =~ s/^0*//;
}

sub __strip_accession_list {
  my $self = shift;
  my $acc_list = shift;

  my @new_accs;
  foreach my $acc(@$acc_list) {
    $acc =~ s/^\s*(.*?)\s*$/$1/;
    $acc =~ s/^GO:?//;
    $acc =~ s/^0*//;
    push @new_accs, $acc;
  }
  return @new_accs;
}

sub drawErrorMessage {
  my $self = shift;
  my ($session, $error_type) =
    rearrange([qw(session error_type)], @_);
  my $writer = $self->{'writer'};

  my $error_code = $session->get_param($error_type);
  $writer->startTag('h2');
  $writer->characters('Warning:');
  $writer->endTag('h2');
  if ($error_code eq 'upfile_and_seq') {
    $writer->characters('You have pasted in a sequence and a filename.  The ');
    $writer->characters('sequence file will be used as the query sequence.');
  } elsif ($error_code eq 'too_many_seqs') {
    $writer->characters('You have entered more than one sequence. Only ');
    $writer->characters('one will be used.');
  } elsif ($error_code eq 'aa_seq_too_long') {
    $writer->characters('The sequence you have entered is too ');
    $writer->characters("long. It has been truncated to ".$session->get_param('max_seq_length')." amino acids.");
  } elsif ($error_code eq 'seq_too_long') {
    $writer->characters('The sequence you have entered is too ');
    $writer->characters("long. The longest allowable sequence is ".$session->get_param('max_seq_length')." residues.");
  } elsif ($error_code eq 'bad_seq') {
    $writer->characters('Input is not a valid sequence.  Please go back and try again.');
  } elsif ($error_code eq 'bad_seq_id') {
    $writer->characters('The sequence ID you have entered is not in the GO database.  Please go back and try again.');
  } elsif ($error_code eq 'no_input') {
    $writer->characters('You have entered neither a sequence or sequence ID.  Please go back and try again.');
  } elsif ($error_code eq 'job_still_running') {
    my $job_link = "go.cgi?action=get_job_by_id&view=blast&session_id=".$session->get_param('session_id');
    $writer->out("You have a previously submitted job that is still running.<br>  You must wait for that job to finish before you will be allowed to submit a new one.<p>  <a href=$job_link >Retreive the results of the running job.</a><p>  Please be patient.");
  } elsif ($error_code eq 'job_failed') {
    $writer->out('Sorry, there was a problem with this job.  Please go back and try again.');
  }
}

sub AUTOLOAD {
  my $self = shift;
  my $program = our $AUTOLOAD;
  $program =~ s/.*:://;
  $self->{'writer'}->$program(@_);
}


1;



