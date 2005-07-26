=head1 SYNOPSIS

package GO::CGI::HTML

=head2  Usage

use FileHandle;
use GO::CGI::Query;
use GO::CGI::Session;
use CGI 'param';

my $q = new CGI;

my $session = new GO::CGI::Session(-q=>$q);

$session->cleanQueryValues();

my $params = $session->get_param_hash;

my $data = GO::CGI::Query->do_query(-session=>$session);
$session->set_data($data);

require GO::CGI::HTML;
my $out = new FileHandle(">-");
$session->set_output($out);

GO::CGI::HTML->draw_tree(-session=>$session);

=cut

package GO::CGI::HTML;

use GO::IO::HTML;
use GO::Utils qw(rearrange);


=head2 drawTree

    Arguments  - GO::CGI::Session;

Returns - formatted GO HTML browser page with tree view and query top-bar

=cut


sub drawMain {
  my $self = shift;
  my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  
  my $title;
  if (!$session->get_param('title')) {
    $title = $self->_get_page_title($session);
  } else {
    $title = $session->get_param('title') || 'AmiGO!  Your friend in the Gene Ontology.';
  }
  

  my $gen = new GO::IO::HTML(-output=>$out);


  $gen->htmlHeader;
  $gen->startHtml();
  $gen->startTag('head');
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters($title);
  $gen->endTag('title');
  $gen->endTag('head');
  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawPopupJscript();
  $gen->drawCheckAllJscript;
  $gen->drawParentOpenJscript();

  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  if ($session->get_param('view') eq 'blast') {
    $gen->drawGostHeader(-session=>$session);
  } elsif ($session->get_param('advanced_query') ne 'yes') {
    $gen->startTable();
    $gen->drawSimpleQueryInterface(-session=>$session);
    $gen->startCell();
    $gen->drawQuickSpeciesSelector(-session=>$session);
    $gen->endTable();
  } else {
    $gen->drawAdvancedQueryInterface(-session=>$session);
  }
  $gen->endTitlebar;

  $gen->startContent(-bgcolor=>'white',
		     -nowrap=>'nowrap');
  if ($session->get_param('view') eq 'query') {
    if ($session->get_param('search_constraint') eq 'gp') {
      $gen->drawGeneProductList(-session=>$session);
    } else {
      $gen->drawTermList(-session=>$session);
    }
  } elsif ($session->get_param('view') eq 'blast') {
    if ($session->get_param('action') eq 'blast') {
      $gen->drawBlastQuery(-session=>$session);
#    } elsif ($session->get_param('job')) {
#      $gen->drawBlastResults(-session=>$session);
    } elsif ($session->get_param('action') eq 'get_job_by_id') {
      $gen->drawBlastResults(-session=>$session);
    } else {
      $gen->drawBlastForm(-session=>$session);
    }
  } elsif ($session->get_param('view') eq 'summary' &&
	   $session->get_param('query')) {
    $gen->drawSummaryPage(-session=>$session);
  }  elsif ($session->get_param('view') eq 'summary') {
    $gen->writeSummaryPage(-session=>$session);
  } else {
    if ($session->get_param('graph_view') eq 'tree') {
      $session->bootstrap_tree_view();
    }
    $gen->drawNodeGraph(-session=>$session);
    $gen->startTag('font',
		   'size'=>'-1');
    $gen->startTag('p');
    $gen->drawXmlLink(-session=>$session,
		      -text=>'Get this tree as RDF XML.');
    $gen->startTag('p');
    $gen->drawBookmarkLink(-session=>$session,
		      -text=>'Get a bookmarkable url of this tree.');
    $gen->startTag('p');
    $gen->endTag('font');
    
  }
  
  $gen->drawFooter(-session=>$session);
  $gen->endContent;
  $gen->endHtml();
}

=head2 drawDetails

    Arguments  - GO::CGI::Session;

Returns - formatted GO HTML browser page with dag view and
          expanded term view with association list and table summary.

=cut

sub drawDetails {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";

  my $title;
  if (!$session->get_param('title')) {
    $title = $self->_get_page_title($session);
  } else {
    $title = $session->get_param('title') || 'AmiGO!  Your friend in the Gene Ontology.';
  }

  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters($title);
  $gen->endTag('title');

  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawCheckAllJscript;
  $gen->drawParentOpenJscript;
  
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $gen->startTag('table');
  $gen->startTag('tr');
  $gen->startTag('td');
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);
  $gen->endTag('td');
  $gen->startTag('td',
		'valign'=>'top');
  $gen->startTag('font',
		 'size'=>'-1'
		);
  if ($session->get_param('show_blast') eq 'yes') {
    $gen->startTag('a',
		   'href'=>'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']));
    $gen->characters('GOst Search');
    $gen->endTag('a');
    $gen->startTag('br');
  }
  $gen->drawXmlLink(-session=>$session, 
		    -text=>'Get this GO term as RDF XML.');
  $gen->lastJobLink(-session=>$session);
  $gen->endTag('td');
  $gen->endTag('tr');
  $gen->endTag('table');
  $gen->endTitlebar;
  $gen->startContent(-bgcolor=>'white');
  
  if ($session->get_data) {
    if (scalar(@{$session->get_data->get_all_nodes}) == 0) {
      $gen->characters('Sorry, no terms match your query.');
    }  elsif (scalar(@{$session->get_data->focus_nodes}) == 1) {
      $gen->startTag('table',
		     'cellspacing'=>'0');
      $gen->startTag('tr');
      $gen->startTag('td',
		     'colspan'=>'2');
      $gen->drawTermNameAndDescription(-term=>@{$session->get_data->focus_nodes}->[0], -session=>$session);
      $gen->endTag('td');
      $gen->startTag('td');
      $gen->endTag('td');
      $gen->endTag('tr');
      ##  Title and Control Widget for Dagview.
      $gen->startTag('tr');
      $gen->startTag('th',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'nowrap'=>'',
		     'width'=>'200',
		     'align'=>'left'
		    );

      if ($session->get_param('show_gp_dag') ne 'no') {
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									'query',
									 'view',
									]);
	$gen->startTag('a',
		       'href'=>"go.cgi?show_gp_dag=no$href_pass_alongs"
		      );
	my $image_dir = $session->get_param('image_dir') || '../images';
	$gen->emptyTag('img',
		       'border'=>'0',
		       'src'=>"$image_dir/ominus.png");
	$gen->endTag('a');
      } else {
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									'query',
									 'view',
									]);
	$gen->startTag('a',
		       'href'=>"go.cgi?show_gp_dag=yes$href_pass_alongs"
		      );
	my $image_dir = $session->get_param('image_dir') || '../images';
	$gen->emptyTag('img',
		       'border'=>'0',
		       'src'=>"$image_dir/plus.png");
	$gen->endTag('a');
      }
      $gen->characters('Term Lineage ');
      $gen->endTag('th');
      $gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'310',
		    'nowrap'=>'');
      my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									'query',
								       'view'
									]);
      $gen->startTag('a',
		     'href'=>"go.cgi?action=dotty&search_constraint=term$href_pass_alongs"
		    );
      $gen->characters('Graph view.');
      $gen->endTag('a');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->startTag('td');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->endTag('tr');
      ##  Dagview
      $gen->startTag('tr');
      $gen->startTag('td',
		     'align'=>'left',
		     'colspan'=>'3',
		     'nowrap'=>'');
      if ($session->get_param('show_gp_dag') ne 'no') {
	$gen->drawNodeGraph(-session=>$session, -view=>'dag');
      }
      $gen->endTag('td');
      $gen->endTag('tr');
      ##  Title and Control Widget for xref's
      $gen->startTag('tr');
      $gen->startTag('th',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'200',
		     'nowrap'=>'yes',
		     'align'=>'left');
      if ($session->get_param('show_gp_xrefs') ne 'no') {
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									 'query',
									 'view',
									]);
	$gen->startTag('a',
		       'href'=>"go.cgi?show_gp_xrefs=no$href_pass_alongs"
		      );
	my $image_dir = $session->get_param('image_dir') || '../images';
	$gen->emptyTag('img',
		       'border'=>'0',
		       'src'=>"$image_dir/ominus.png");
	$gen->endTag('a');
      } else {
	my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									'query',
									 'view',
									]);
	$gen->startTag('a',
		       'href'=>"go.cgi?show_gp_xrefs=yes$href_pass_alongs"
		      );
	my $image_dir = $session->get_param('image_dir') || '../images';
	$gen->emptyTag('img',
		       'border'=>'0',
		       'src'=>"$image_dir/plus.png");
	$gen->endTag('a');
      }



      $gen->characters('External References');
      $gen->endTag('th');
      $gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'310');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->startTag('td');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->endTag('tr');
      ##   Xref's
      $gen->startTag('tr');
      $gen->startTag('td',
		     'colspan'=>'3',
		     'nowrap'=>'');
      if ($session->get_param('show_gp_xrefs') ne 'no') {
	$gen->drawTermXrefList(-session=>$session,
			       -xref_list=>@{$session->get_data->focus_nodes}->[0]->dbxref_list);
      }
      $gen->endTag('td');
      $gen->endTag('tr');

      if ($session->get_param('show_gp_options')) {

	##  Title and Control Widget for Gene Associations.
	$gen->startTag('tr');
	$gen->startTag('td',
		       'colspan'=>'2',
		       'bgcolor'=>'9fb7ea',
		       'valign'=>'top',
		       'align'=>'left',
		       'nowrap'=>'',
		       'width'=>'310');
	$gen->startTable('cellpadding'=>'2',
			 'valign'=>'top');
	if ($session->get_param('show_gp_gps') ne 'no') {
	  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									   'query',
									   'view',
									  ]);
	  $gen->startTag('a',
			 'href'=>"go.cgi?show_gp_gps=no$href_pass_alongs"
			);
	  my $image_dir = $session->get_param('image_dir') || '../images';
	  $gen->emptyTag('img',
			 'border'=>'0',
			 'src'=>"$image_dir/ominus.png");
	  $gen->endTag('a');
	} else {
	  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									   'query',
									   'view',
									  ]);
	  $gen->startTag('a',
			 'href'=>"go.cgi?show_gp_gps=yes$href_pass_alongs"
			);
	  my $image_dir = $session->get_param('image_dir') || '../images';
	  $gen->emptyTag('img',
			 'border'=>'0',
			 'src'=>"$image_dir/plus.png");
	  $gen->endTag('a');
	}
	$gen->startTag('b');
	$gen->characters('Associated Genes');
	$gen->endTag('b');
	if ($session->get_param('show_gp_gps') ne 'no') {
	  my $page_num = $session->get_param('association_page') || 1;
	  $gen->startTag('br');
	  $gen->startTag('br');
	  my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
									   'query',
									   'view',
									  ]);

	  $gen->startTag('br');
	  $gen->startTag('br');
	  $gen->startTag('br');
	  if ($page_num eq 'all') {
	    $gen->characters(' Page 1');
	  } else {
	    $gen->characters(' Page '.$page_num);
	  }
	  $gen->startCell();
	  $gen->startCell();
	  $gen->drawGeneAssociationFilterWidget(-session=>$session);
	  $gen->endTable();
	  $gen->endTag('td');
	  $gen->startTag('td',
			 'colspan'=>'1',
			 'bgcolor'=>'9fb7ea',
			 'nowrap'=>'',
			 'align'=>'left',
			 'width'=>'310');
	  $gen->endTag('td');
	  $gen->startTag('td');
	  $gen->startTag('br');
	  $gen->endTag('td');
	  $gen->endTag('tr');
	  ##  Gene Associations.
	  $gen->startTag('tr');
	  $gen->startTag('td',
			 'nowrap'=>'',
			 'colspan'=>'3');
	  my $apph = $session->apph;
	  $gen->startTag('form',
			 'action'=>'go.cgi', name=>'term_details', method=>'post');
	  $self->_make_form_hiddens(-session=>$session, -fields=>['session_id'], -gen=>$gen);
	  $gen->startTag('input', 
			 'type'=>'hidden',
			 'name'=>'view',
			 'value'=>'details'
			);
	  $gen->startTag('input', 
			 'type'=>'hidden',
			 'name'=>'search_constraint',
			 'value'=>'gp'
			);
	  my $tl = $apph->get_terms_with_associations({acc=>@{$session->get_data->focus_nodes}->[0]->acc});
	  if ($session->get_param('gp_view') eq 'detailed') {
	    $gen->drawGeneProductDetails(-session=>$session, -term_list=>$tl);
	  } else {
	    $gen->drawGeneAssociationList(-term_list=>$tl, -session=>$session);
	  }
	  $gen->endTag('td');
	  $gen->endTag('tr');
	  $gen->startTag('tr');
	  $gen->startTag('td',
			 'nowrap'=>'');
	  if ($session->get_param('gp_view') ne 'detailed') {
	    
	    $gen->__draw_gene_product_select_widget(-session=>$session,
						    -form=>'term_details',
						    -field=>'gp');
	  }
	  $gen->endTag('form');
	  $gen->endTag('td');
	  $gen->endTag('tr');
	}
	$gen->endTag('table');
      } else {
	$gen->endTag('tr');
	$gen->endTag('table');
      }
      
    } else {
        
	$gen->startTag('table',
		       'cellspacing'=>'0');
	##  Dagview
	$gen->startTag('tr');
	$gen->startTag('td',
		       'align'=>'left',
		       'colspan'=>'3',
		       'nowrap'=>'');
	$gen->drawNodeGraph(-session=>$session, -view=>'dag');
	$gen->startTag('br');
	$gen->endTag('td');
	$gen->endTag('tr');
	
	$gen->startTag('form',
		       'action'=>'go.cgi', name=>'term_details');
	$self->_make_form_hiddens(-session=>$session, -fields=>['session_id'], -gen=>$gen);
	$gen->startTag('input', 
		       'type'=>'hidden',
		       'name'=>'view',
		     'value'=>'details'
		    );
      $gen->startTag('input', 
		     'type'=>'hidden',
		     'name'=>'search_constraint',
		     'value'=>'gp'
		    );
      
      foreach my $term(@{$session->get_data->focus_nodes}) {
	$gen->startTag('td',
		       'colspan'=>'2',
		      );
	$gen->drawTermNameAndDescription(-term=>$term, -color=>'9fb7ea');
	$gen->endTag('td');
	$gen->startTag('td');
	$gen->endTag('td');
	$gen->endTag('tr');
	##  Title and Control Widget for xref's
	$gen->startTag('tr');
	$gen->startTag('th',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'200',
		     'nowrap'=>'yes',
		     'align'=>'left');
	$gen->characters('References');
	$gen->endTag('th');
	$gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'310');
	$gen->startTag('br');
	$gen->endTag('td');
	$gen->startTag('td');
	$gen->startTag('br');
	$gen->endTag('td');
	$gen->endTag('tr');
	##   Xref's
	$gen->startTag('tr');
	$gen->startTag('td',
		     'colspan'=>'3',
		     'nowrap'=>'');
	$gen->drawTermXrefList(-session=>$session,
			     -xref_list=>$term->dbxref_list);
	$gen->endTag('td');
	$gen->endTag('tr');
	##  Title and Control Widget for Gene Associations.
	$gen->startTag('tr');
	$gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'valign'=>'top',
		     'align'=>'left',
		     'nowrap'=>'');
	$gen->startTag('b');
	$gen->characters('Associated Genes');
	$gen->endTag('b');
	my $page_num = $session->get_param('association_page') || 1;
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	$gen->startTag('br');
	if ($page_num eq 'all') {
	  $gen->characters(' Page 1');
	} else {
	  $gen->characters(' Page '.$page_num);
	}
	$gen->endTag('td');
	$gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'nowrap'=>'',
		     'align'=>'left',
		     'width'=>'310');
	$gen->drawGeneAssociationFilterWidget(-session=>$session);
	$gen->endTag('td');
	$gen->startTag('td');
	$gen->startTag('br');
	$gen->endTag('td');
	$gen->endTag('tr');
	##  Gene Associations.
	$gen->startTag('tr');
	$gen->startTag('td',
		     'nowrap'=>'',
		     'colspan'=>'3');
	my $apph = $session->apph;
	my $tl = $apph->get_terms_with_associations({acc=>$term->acc});
	if ($session->get_param('gp_view') eq 'detailed') {
	  $gen->drawGeneProductDetails(-session=>$session, -term_list=>$tl);
	} else {
	  $gen->drawGeneAssociationList(-term_list=>$tl, -session=>$session);
	}
	$gen->startTag('hr');
	$gen->endTag('td');
	$gen->endTag('tr');
      }
      $gen->startTag('tr');
      $gen->startTag('td', 'nowrap'=>'');
	if ($session->get_param('gp_view') ne 'detailed') {
	  
	  $gen->__draw_gene_product_select_widget(-session=>$session,
						  -form=>'term_details',
						  -field=>'gp');     
	}
      $gen->endTag('td');
      $gen->endTag('tr');
      $gen->endTag('table');
    }
  } else {
    $gen->characters('Sorry, no terms matched your query.'); 
  }  
  $gen->drawFooter(-session=>$session);
  $gen->endContent;
  
    
  $gen->endHtml;
  
}


sub __drawPopupLogo {
    my $self = shift;
    my ($session, $gen) = 
	rearrange([qw(session gen)], @_);

    my $out = $session->{'out'};
    my $image_dir = $session->get_param('image_dir') || "../images";
    my $logo = $session->get_param('logo') || "GOthumbnail.gif";
    $logo = "$image_dir/".$logo;
    my $session_id = $session->get_param('session_id');
    $gen->startTag('a', href=>"javascript:ChangeParentDocument('go.cgi?session_id=$session_id&search_constraint=terms')");
    $gen->emptyTag('img',
		'src'=>$logo,
		   border=>0);
    $gen->endTag('a');
}
	

=head2 drawImagoDetails

    Arguments  - GO::CGI::Session;

Returns - formatted GO HTML browser page with dag view and
          expanded term view with association list and table summary.

=cut

sub drawImagoDetails {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";

  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters('ImaGO!');
  $gen->endTag('title');

  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawCheckAllJscript;
  $gen->drawParentOpenJscript;
  
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $gen->startTag('table');
  $gen->startTag('tr');
  $gen->startTag('td');
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);

  $gen->endTag('td');
  $gen->startTag('td',
		'valign'=>'bottom');
  $gen->endTag('td');
  $gen->endTag('tr');
  $gen->endTag('table');
  $gen->endTitlebar;
  $gen->startContent(-bgcolor=>'white');
  if ($session->get_data) {
    if (scalar(@{$session->get_data->get_all_nodes}) == 0) {
      $gen->characters('Sorry, no terms match your query.');
    }  elsif (scalar(@{$session->get_data->focus_nodes}) == 1) {
     $gen->startTag('table',
                     'cellspacing'=>'0');
      $gen->startTag('tr');
      $gen->startTag('td',
                     'colspan'=>'2');
      $gen->drawTermNameAndDescription(-term=>@{$session->get_data->focus_nodes}->[0], -session=>$session);
      $gen->endTag('td');
      $gen->startTag('td');
      $gen->endTag('td');
      $gen->endTag('tr');
      ##  Title and Control Widget for Dagview.
      $gen->startTag('tr');
      $gen->startTag('th',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'nowrap'=>'',
		     'width'=>'200',
		     'align'=>'left'
		    );

      $gen->characters('Term Lineage ');
      $gen->endTag('th');
      $gen->startTag('td',
		     'colspan'=>'1',
		     'bgcolor'=>'9fb7ea',
		     'width'=>'310');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->startTag('td');
      $gen->startTag('br');
      $gen->endTag('td');
      $gen->endTag('tr');
      ##  Dagview
      $gen->startTag('tr');
      $gen->startTag('td',
		     'align'=>'left',
		     'colspan'=>'3',
		     'nowrap'=>'');
      if ($session->get_param('show_gp_dag') ne 'no') {
	$gen->drawNodeGraph(-session=>$session, -view=>'dag', -link_to=>'imago');
      }
      $gen->endTag('td');
      $gen->endTag('tr');
      $gen->endTag('table');
    }
    $gen->endTag('td');
    $gen->endTag('tr');
## GP     Headers
    $gen->startTag('tr');
      $gen->startTag('td',
                     'colspan'=>'2',
                     'bgcolor'=>'9fb7ea',
                     'valign'=>'top',
                     'align'=>'left',
                     'nowrap'=>'',
		     'width'=>'310');
      $gen->startTable('cellpadding'=>'2',
		       'valign'=>'top');
    if ($session->get_param('show_gp_gps') ne 'no') {
        my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
                                                                         'query',
                                                                         'view',
									 ]);
        $gen->startTag('a',
                       'href'=>"go.cgi?show_gp_gps=no$href_pass_alongs"
		       );
        my $image_dir = $session->get_param('image_dir') || '../images';
        $gen->emptyTag('img',
                       'border'=>'0',
                       'src'=>"$image_dir/ominus.png");
        $gen->endTag('a');
    } else {
        my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
                                                                        'query',
                                                                         'view',
									 ]);
        $gen->startTag('a',
                       'href'=>"go.cgi?show_gp_gps=yes$href_pass_alongs"
		       );
        my $image_dir = $session->get_param('image_dir') || '../images';
        $gen->emptyTag('img',
                       'border'=>'0',
                       'src'=>"$image_dir/plus.png");
        $gen->endTag('a');
    }
    $gen->startTag('b');
    $gen->characters('Associated Genes');
    $gen->endTag('b');
    if ($session->get_param('show_gp_gps') ne 'no') {
        my $page_num = $session->get_param('association_page') || 1;
        my $href_pass_alongs = $session->get_session_settings_urlstring(['session_id',
                                                                        'query',
                                                                         'view',
									 ]);
        $gen->startTag('br');

        if ($page_num eq 'all') {
	    $gen->characters(' Page 1');
        } else {
	    $gen->characters(' Page '.$page_num);
        }
        $gen->startTag('br');
        $gen->startTag('br');
        $gen->endTag('td');
        $gen->startTag('td');
        $gen->startTag('br');
        $gen->endTag('tr');
        $gen->startTag('br');
        $gen->endTag('tr');
	$gen->endTag('table');
	##  Gene Associations.
	$gen->startTag('tr');
        $gen->startTag('td',
                       'nowrap'=>'',
                       'colspan'=>'3');
	my $apph = $session->apph;
        $gen->startTag('form',
                       'action'=>'go.cgi', name=>'term_details');
	$self->_make_form_hiddens(-session=>$session, -fields=>['session_id'], -gen=>$gen);
        $gen->startTag('input',
                       'type'=>'hidden',
                       'name'=>'view',
                       'value'=>'details'
		      );
        $gen->startTag('input',
                       'type'=>'hidden',
                       'name'=>'search_constraint',
                       'value'=>'gp'
		      );
	my $tl = $apph->get_terms_with_associations({acc=>@{$session->get_data->focus_nodes}->[0]->acc});
	if ($session->get_param('gp_view') eq 'detailed') {
	  $gen->drawGeneProductDetails(-session=>$session, -term_list=>$tl);
	} else {
	  $gen->drawImagoGeneAssociationList(-term_list=>$tl, -session=>$session);
	}
	$gen->endTag('td');
	$gen->endTag('tr');
	$gen->startTag('tr');
        $gen->startTag('td',
                       'nowrap'=>'');
	if ($session->get_param('gp_view') ne 'detailed') {
#does not make any sense in ImaGO
#          $gen->__draw_gene_product_select_widget(-session=>$session,
#                                                  -form=>'term_details',
#                                                  -field=>'gp');
	}
	$gen->endTag('form');
	$gen->endTag('td');
	$gen->endTag('tr');
      }
    $gen->endTag('table');
  } else {
    $gen->characters('Sorry, no terms matched your query.'); 
  }  
  $gen->endContent;
  
    
  $gen->startFooter(-align=>'center',-bgcolor=>'white' );
  $gen->characters('');
  $gen->endFooter;
  $gen->endHtml;
  
}


=head2 drawDotty

    Arguments  - GO::CGI::Session;

Returns - GraphViz view of a go tree.

=cut

sub drawDotty {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);
  
  require "GO/Dotty/Dotty.pm";
  
  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";
  
  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters('AmiGO!  Dag view.');
  $gen->endTag('title');

  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawCheckAllJscript;
  $gen->drawParentOpenJscript;
  
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $gen->startTag('table');
  $gen->startTag('tr');
  $gen->startTag('td');
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);
  $gen->endTag('td');
  $gen->startTag('td',
		'valign'=>'bottom');
  $gen->startTag('font',
		 'size'=>'-1'
		);
  if ($session->get_param('show_blast') eq 'yes') {
    $gen->startTag('a',
		   'href'=>'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']));
    $gen->characters('GOst Search');
    $gen->endTag('a');
    $gen->startTag('br');
  }
  $gen->drawXmlLink(-session=>$session, 
		    -text=>'Get this GO term as RDF XML.');
  $gen->endTag('td');
  $gen->endTag('tr');
  $gen->endTag('table');
  $gen->endTitlebar;
  $gen->startContent(-bgcolor=>'white');

  

  my $graphviz = GO::Dotty::Dotty::go_graph_to_graphviz( $data , {rankdir=>1});
  #  GO::Dotty::Dotty::graphviz_to_dotty( $graphviz );
  
  $session_id = $session->get_param('session_id');
  $file_name = $session->get_param('query').".png";
  my $html_dir = $session->get_param('html_dir') || '../docs';
  my $tmp_image_dir = $session->get_param('tmp_image_dir_relative_to_docroot') || 'tmp_images';
  if (! open("$html_dir/$tmp_image_dir/$session_id")) {
    `mkdir $html_dir/$tmp_image_dir/$session_id`;
    `chmod a+rw $html_dir/$tmp_image_dir/$session_id`;
  }

  use FileHandle;
  $fh = new FileHandle "> $html_dir/$tmp_image_dir/$session_id/$file_name";  

  print $fh $graphviz->as_png;
  $fh->close;
  `chmod a+rw $html_dir/$tmp_image_dir/$session_id/$file_name`;
  my $rel_tmp_images = $session->get_param('tmp_image_dir') || '../docs';
  $gen->startTag('img',
		 'src'=>"$rel_tmp_images/$session_id/$file_name");
  $gen->endTag('img');
  $gen->endContent;
  
    
  $gen->startFooter(-align=>'center',-bgcolor=>'white' );
  $gen->characters('');
  $gen->endFooter;
  $gen->endHtml;
}

=head2 drawTextSummary

    Arguments  - GO::CGI::Session;

=cut

sub drawTextSummary {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);
  
  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $gen = new GO::IO::HTML(-output=>$out);

  $gen->drawSummaryPage(-session=>$session);
  
}

=head2 drawSummary

    Arguments  - GO::CGI::Session;

=cut

sub drawSummary {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);
  
  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";
  
  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters('AmiGO!  Summary Page.');
  $gen->endTag('title');

  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawCheckAllJscript;
  $gen->drawParentOpenJscript;
  
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $gen->startTag('table');
  $gen->startTag('tr');
  $gen->startTag('td');
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);
  $gen->endTag('td');
  $gen->startTag('td',
		'valign'=>'bottom');
  $gen->endTag('td');
  $gen->endTag('tr');
  $gen->endTag('table');
  $gen->endTitlebar;
  $gen->startContent(-bgcolor=>'white');

  $gen->drawSummaryPage(-session=>$session);

  $gen->drawFooter(-session=>$session);
  $gen->endContent;    
  $gen->endHtml;
}


sub _make_form_hiddens {
  my $self = shift;
  my ($session, $fields, $gen) =
    rearrange([qw(session fields gen)], @_);

  my $param_hash = $session->get_param_hash;
  foreach my $param (keys %$param_hash) {
    if ($self->__is_inside($param, $fields)) {
      foreach my $value (split("\0", %$param_hash->{$param})) {
        $gen->emptyTag('input',
                          'type'=>'hidden',
                          'name'=>$param,
                          'value'=>$value
                         );
      }
    }
  }
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


=head2 drawGPDetails

    Arguments  - GO::CGI::Session;

Returns - Formatted HTML page with detailed
info about a Gene Product.

=cut

sub drawGPDetails {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);

  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";

  my $title;
  if (!$session->get_param('title')) {
    $title = $self->_get_page_title($session);
  } else {
    $title = $session->get_param('title') || 'AmiGO!  Your friend in the Gene Ontology.';
  }
  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'http://www.geneontology.org'});
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startTag('title');
  $gen->characters($title);
  $gen->endTag('title');

  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  $gen->drawParentOpenJscript;
  $gen->drawCheckAllJscript;
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $gen->startTag('table');
  $gen->startTag('tr');
  $gen->startTag('td');
  
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);

  $gen->endTag('td');
  $gen->startTag('td',
		'valign'=>'bottom');
  $gen->startTag('font',
		 'size'=>'-1'
		);
  if ($session->get_param('show_blast') eq 'yes') {
    $gen->startTag('a',
		   'href'=>'go.cgi?view=blast'.$session->get_session_settings_urlstring(['session_id']));
    $gen->characters('GOst Search');
    $gen->endTag('a');
    $gen->startTag('br');
  }
  $gen->drawXmlLink(-session=>$session, 
		    -text=>'Get this GO Gene Product as RDF XML.');
  $gen->endTag('td');
  $gen->endTag('tr');
  $gen->endTag('table');
  $gen->endTitlebar;
  
  $gen->startContent(-bgcolor=>'white');
  
  if ($session->get_data) {
      #if (scalar(@{$session->get_data->get_all_nodes}) == 0) {
#	  $gen->characters('Sorry, no terms match your query.');
#      } else {
	  $gen->drawGeneProductDetails(-session=>$session);
#  }
  } else {
      $gen->characters('Sorry, no terms matched your query.'); 
  }  

  $gen->drawFooter(-session=>$session);
  $gen->endContent;
  $gen->endHtml;
  
}


=head2 drawList

    Arguments  - GO::CGI::Session;

Returns - formatted HTML page with a list
of terms and/or gene products.

=cut

sub drawList {



}


=head2 drawDefs

    Arguments  - GO::CGI::Session;

Returns - formatted HTML page with a definition from
  GO::CGI::definitions

=cut

sub drawDefs {
  my $self = shift;
    my ($session) = 
      rearrange([qw(session)], @_);

  require GO::CGI::Definitions;

  my $out = $session->{'out'};
  my $data = $session->{'data'};
  my $params = $session->get_param_hash;
  my $image_dir = $session->get_param('image_dir') || "../images";

  my $gen = new GO::IO::HTML(-output=>$out);
  
  $gen->htmlHeader;
  $gen->startHtml();
  $gen->head(-rdf=>{'dc:Creator'=>'bradmars@yahoo.com'});
  $gen->startBody(-bgcolor=>'white',  -link_color=>'00008B');
  
  
  $gen->startTitlebar(-bgcolor=>'9fb7ea', -align=>'left');
  $self->__drawPopupLogo(-session=>$session,
			 -gen=>$gen);
  $gen->endTitlebar;
  
  $gen->startContent(-bgcolor=>'white');
  if ($session->get_param('def') eq 'ev_codes') {
    $gen->out(GO::CGI::Definitions->get_def(-word=>$session->get_param('def')));
  } else {
    $gen->startTag('ul');
    foreach my $def (@{GO::CGI::Definitions->get_def(-word=>$session->get_param('def'))}) {
      $gen->startTag('li');
      $gen->characters($def);
      $gen->endTag('li');
    }
    $gen->endTag('ul');
  }
  $gen->endContent;
  

  $gen->startFooter(-align=>'center',-bgcolor=>'white' );
  $gen->characters('');
  $gen->endFooter;
  $gen->endHtml;
  
}

sub _get_page_title {
  my $self = shift;
  my $session = shift;
  
  if ($session->get_param('view') eq 'details' && 
      $session->get_param('search_constraints') eq 'gp') {
    my $term = $session->get_param('query');
    return "AmiGO : $term details";
  } elsif ($session->get_param('view') eq 'details') {
    my $term = $session->get_param('query');
    return "AmiGO : $term details";
  } elsif ($session->get_param('view') eq 'query') {
    my $term = $session->get_param('query');
    return "AmiGO : Query for $term";
  } elsif ($session->get_param('action')) {
    return "AmiGO : Tree View";
  } else {
    return "AmiGO!  Your friend in the Gene Ontology.";
  }
}

1;
