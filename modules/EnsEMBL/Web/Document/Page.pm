# $Id$

package EnsEMBL::Web::Document::Page;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Renderer::Excel;
use EnsEMBL::Web::Document::Renderer::GzFile;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  
  my $format = $data->{'outputtype'};
  $format    = $data->{'input'}->param('_format') if $data->{'input'} && $data->{'input'}->param('_format');

  my $defaults = {
    doc_type         => 'HTML',
    doc_type_version => '4.01 Trans',
    encoding         => 'ISO-8859-1',
    language         => 'en-gb'
  };
  
   my $document_types = {
    none => { none => '' },
    HTML => {
      '2.0'         => '"-//IETF//DTD HTML 2.0 Level 2//EN"',
      '3.0'         => '"-//IETF//DTD HTML 3.0//EN"',
      '3.2'         => '"-//W3C//DTD HTML 3.2 Final//EN"',
      '4.01 Strict' => '"-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd"',
      '4.01 Trans'  => '"-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"',
      '4.01 Frame'  => '"-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd"'
    },
    XHTML => {
      '1.0 Strict' => '"-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"',
      '1.0 Trans'  => '"-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"',
      '1.0 Frame'  => '"-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"',
      '1.1'        => '"-//W3C//DTD XHTML 1.1//EN"'
    },
    XML => {
      'DASGFF'             => '"http://www.biodas.org/dtd/dasgff.dtd"',
      'DASDSN'             => '"http://www.biodas.org/dtd/dasdsn.dtd"',
      'DASEP'              => '"http://www.biodas.org/dtd/dasep.dtd"',
      'DASDNA'             => '"http://www.biodas.org/dtd/dasdna.dtd"',
      'DASSEQUENCE'        => '"http://www.biodas.org/dtd/dassequence.dtd"',
      'DASSTYLE'           => '"http://www.biodas.org/dtd/dasstyle.dtd"',
      'DASTYPES'           => '"http://www.biodas.org/dtd/dastypes.dtd"',
      'rss version="0.91"' => '"http://my.netscape.com/publish/formats/rss-0.91.dtd"',
      'rss version="2.0"'  => '"http://www.silmaril.ie/software/rss2.dtd"',
      'xhtml'              => '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"'
    }
  };
  
  my $self = {
    body_attr        => {},
    doc_type         => $defaults->{'doc_type'},
    doc_type_version => $defaults->{'doc_type_version'},
    encoding         => $defaults->{'encoding'},
    language         => $defaults->{'language'},
    format           => $format || $defaults->{'doc_type'},
    head_order       => [],
    body_order       => [],
    %$data,
    document_types   => $document_types
  };
  
  $self->{$_} = $defaults->{$_} for grep { $data->{$_} && !exists $document_types->{$data->{$_}} } qw(doc_type doc_type_version);
 
  bless $self, $class;
  return $self;
}

sub head_order     :lvalue { $_[0]{'head_order'}           }
sub body_order     :lvalue { $_[0]{'body_order'}           }
sub renderer       :lvalue { $_[0]{'renderer'}             }
sub species_defs           { return $_[0]{'species_defs'}; }
sub printf                 { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print                  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }
sub timer_push             { $_[0]->{'timer'} && $_[0]->{'timer'}->push($_[1], 1); }

sub set_doc_type {
  my ($self, $type, $version) = @_;
  
  return unless exists $self->{'document_types'}->{$type}->{$version};
  
  $self->{'doc_type'} = $type;
  $self->{'doc_type_version'} = $version;
}

sub doc_type {
  my $self = shift;
  
  return '' if $self->{'doc_type'} eq 'none';
  
  my $doctype = $self->{'doc_type'} eq 'XML' ? "$self->{'doc_type_version'} SYSTEM" : 'html PUBLIC';
  
  return "<!DOCTYPE $doctype $self->{'document_types'}->{$self->{'doc_type'}}->{$self->{'doc_type_version'}}>\n";
}

sub html_tag {
  my $self = shift;
  return sprintf qq{<html %slang="%s">\n}, $self->{'doc_type'} eq 'XHTML' ? 'xmlns="http://www.w3.org/1999/xhtml" xml:' : '', $self->{'language'};
}

# AJAX-friendly redirect, for use in control panel
sub ajax_redirect {
  my ($self, $url) = @_;
  
  my $r         = $self->renderer->{'r'};
  my $back      = $self->{'input'}->param('wizard_back');
  my @backtrack = map $url =~ /_backtrack=$_\b/ ? () : $_, $self->{'input'}->param('_backtrack');
  
  $url .= ($url =~ /\?/ ? ';' : '?') . '_backtrack=' . join ';_backtrack=', @backtrack if scalar @backtrack;
  $url .= ($url =~ /\?/ ? ';' : '?') . "wizard_back=$back" if $back;
  
  if ($self->renderer->{'_modal_dialog_'}) {
    if (!$self->{'ajax_redirect_url'}) {
      $self->{'ajax_redirect_url'} = $url;
      
      $r->content_type('text/plain');
      print qq({"redirectURL":"$url"});
    }
  } else {
    $r->headers_out->set('Location' => $url);
    $r->err_headers_out->set('Location' => $url);
    $r->status(Apache2::Const::REDIRECT);
  }
}

sub body_elements { my $self = shift; return map $_->[0], @{$self->{'body_order'}}; }
sub head_elements { my $self = shift; return map $_->[0], @{$self->{'head_order'}}; }

sub add_body_elements       { shift->add_elements('body_order', @_);       }
sub add_body_element        { shift->add_element('body_order', @_);        }
sub add_body_element_first  { shift->add_element_first('body_order', @_);  }
sub add_body_element_last   { shift->add_element_last('body_order', @_);   }
sub add_body_element_before { shift->add_element_before('body_order', @_); }
sub add_body_element_after  { shift->add_element_after('body_order', @_);  }
sub remove_body_element     { shift->remove_element('body_order', @_);     }
sub replace_body_element    { shift->replace_element('body_order', @_);    }

sub add_head_elements       { shift->add_elements('head_order', @_);       }
sub add_head_element        { shift->add_element('head_order', @_);        }
sub add_head_element_first  { shift->add_element_first('head_order', @_);  }
sub add_head_element_last   { shift->add_element_last('head_order', @_);   }
sub add_head_element_before { shift->add_element_before('head_order', @_); }
sub add_head_element_after  { shift->add_element_after('head_order', @_);  }
sub remove_head_element     { shift->remove_element('head_order', @_);     }
sub replace_head_element    { shift->replace_element('head_order', @_);    }

sub add_element { shift->add_elements(@_); }

sub add_elements {
  my $self = shift;
  my $key  = shift;
  
  while (my @element = splice @_, 0, 2) {
    push @{$self->{$key}}, \@element;
  }
}

sub add_element_first {
  my ($self, $key, $code, $function) = @_;
  unshift @{$self->{$key}}, [ $code, $function ];
}

sub add_element_last {
  my ($self, $key, $code, $function) = @_;
  push @{$self->{$key}}, [ $code, $function ];
}

sub add_element_before {
  my ($self, $key, $oldcode, $code, $function) = @_;
  my $elements = $self->{$key};
  
  for (my $i = 0; $i < @$elements; $i++) {
    if ($elements->[$i]->[0] eq $oldcode) {
      splice @$elements, $i, 0, [ $code, $function ];
      last;
    }
  }
}

sub add_element_after {
  my ($self, $key, $oldcode, $code, $function) = @_;
  my $elements = $self->{$key};
  
  for (my $i = 0; $i < @$elements; $i++) {
    if ($elements->[$i]->[0] eq $oldcode){
      splice @$elements, $i+1, 0, [ $code, $function ];
      last;
    }
  }
}

sub remove_element {
  my ($self, $key, $code) = @_;
  my $elements = $self->{$key};
  
  for (my $i = 0; $i < @$elements; $i++) {
    if ($elements->[$i]->[0] eq $code) {
      splice @$elements, $i, 1;
      last;
    }
  }
}

sub replace_element {
  my ($self, $key, $code, $function) = @_;
  my $elements = $self->{$key};
  
  for (my $i = 0; $i < @$elements; $i++) {
    if ($elements->[$i]->[0] eq $code) {
      $elements->[$i]->[1] = $function;
      last;
    }
  }
}

sub _init {
  my $self = shift;
  
  foreach my $entry (@{$self->{'head_order'}}, @{$self->{'body_order'}}) {
    my ($element, $classname) = @$entry; # example: $entry = [ 'content', 'EnsEMBL::Web::Document::HTML::Content' ]
    
    next unless $self->dynamic_use($classname); 
    
    my $html_module;
    
    eval { 
      $html_module = $classname->new($self->{'timer'}); # Construct the module
      $html_module->{'species_defs'} = $self->species_defs;
      $html_module->{'_renderer'}    = $self->renderer;
    };
    
    if ($@) {
      warn $@;
      next;
    }
    
    $self->{$element} = $html_module;
    
    no strict 'refs';
    my $method_name = ref($self) . "::$element";
    *$method_name = sub :lvalue { $_[0]->{$element} }; # Make the element name into function call on Document::Page.
  }
}

sub initialize {
  my $self = shift;
  my $method = '_initialize_' . ($self->{'format'});
  $self->$method;
}

sub clear_body_attr {
  my ($self, $key) = @_;
  delete $self->{'body_attr'}{$key};
}

sub add_body_attr {
  my ($self, $key, $value) = @_;
  $self->{'body_attr'}{lc $key} .= $value;
}

sub include_navigation {
  my $self = shift;
  $self->{'_has_navigation'} = shift if @_;
  return $self->{'_has_navigation'};
}

sub render {
  my $self = shift;
  my $format = $self->{'format'};
  my $r = $self->renderer->{'r'};
  
  if ($format eq 'Text') { 
    $r->content_type('text/plain'); 
    $self->render_Text;
  } elsif ($format eq 'DAS') { 
    $self->{'subtype'} = $self->{'subtype'};
    $r->content_type('text/xml');
    $self->render_DAS;
  } elsif ($format eq 'XML') { 
    $r->content_type('text/xml');
    $self->render_XML;
  } elsif ($format eq 'Excel') { 
    $r->content_type('application/x-msexcel');
    $r->headers_out->add('Content-Disposition' => 'attachment; filename=ensembl.xls');
    $self->render_Excel;
  } elsif ($format eq 'TextGz') { 
    $r->content_type('application/octet-stream');
    $r->headers_out->add('Content-Disposition' => 'attachment; filename=ensembl.txt.gz');
    $self->render_TextGz;
  } else {
    $r->content_type('text/html; charset=utf-8');
    $self->render_HTML(@_);
  }
}

sub render_start { shift->render_HTML('start'); }
sub render_end   { shift->render_HTML('end');   }

sub _render_head_and_body_tag {
  my $self = shift;
  
  $self->print(qq{<?xml version="1.0" encoding="utf-8"?>\n}) if $self->{'doc_type'} eq 'XHTML';  
  $self->print($self->doc_type, $self->html_tag, "<head>\n");
  
  foreach my $element (@{$self->{'head_order'}}) {
    my $attr = $element->[0];
    $self->$attr->render;
    $self->timer_push("Rendered $attr");
  }
  
  $self->print("</head>\n<body");
  
  foreach (keys %{$self->{'body_attr'}}) {
    next unless $self->{'body_attr'}{$_};
    $self->printf(' %s="%s"', $_ , encode_entities($self->{'body_attr'}{$_}));
  }
  
  $self->print('>');
}

sub render_HTML {
  ### Main page printing function
  
  my $self = shift;
  my $flag = shift;
  
  # If this is an AJAX request then we will not render the page wrapper
  if ($self->renderer->{'_modal_dialog_'}) {
    my %json = map %{$self->$_->get_json}, qw(global_context local_context content);
    $self->print($self->jsonify(\%json));
    return;
  } elsif ($self->renderer->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
    $self->content->render; # Render content only for components
    return;
  }
  
  # This is a full page
  
  my $html;
  my $footer_id = 'wide-footer';
  
  if ($flag ne 'end') {
    my $nav;
    
    if ($self->include_navigation) {
      $nav = '
      <div id="nav" class="print_hide js_panel">
        [[local_context]]
        [[local_tools]]
        [[acknowledgements]]
        <p class="invisible">.</p>
      </div>';
      
      $footer_id = 'footer';
    }
    
    $self->_render_head_and_body_tag;
    
    $html .= qq{
    <table class="mh" summary="layout table">
      <tr>
        <td id="mh_lo">[[logo]]</td>
        <td id="mh_search">[[search_box]]</td>
      </tr>
    </table>
    <table class="mh" summary="layout table">
      <tr>
        <td id="mh_bc">[[breadcrumbs]]</td>
        <td id="mh_lnk">[[tools]]</td>
      </tr>
    </table>
    <table class="mh print_hide" summary="layout table">
      <tr>
        <td>[[global_context]]</td>
      </tr>
    </table>
    <div style="position: relative">
      $nav
      <div id="main">
        <!-- Start of real content --> 
    };
  }
  
  $html .= '[[message]]';
  $html .= '[[content]]' unless $flag;
      
  if ($flag ne 'start') {
    my $species_path     = $self->species_defs->species_path;
    my $core_params      = $self->{'hub'} ? $self->{'hub'}->core_params : {};
    my $core_params_html = join '', map qq{<input type="hidden" name="$_" value="$core_params->{$_}" />}, keys %$core_params;
    
    $html .= qq{
        <!-- End of real content -->
      </div>
      <div id="$footer_id">[[copyright]][[footerlinks]]</div>
    </div>
    <form id="core_params">
      $core_params_html
    </form>
    <input type="hidden" id="species_path" name="species_path" value="$species_path" />
    [[body_javascript]]
    };
  }
  
  $html .= '[[modal_context]]';
  
  if ($self->can('panel_type') && $self->panel_type) {
    $html = sprintf('
      <div class="js_panel">
        %s
        %s
      </div>',
      $self->panel_type,
      $html
    );
  }
  
  $self->timer_push('template generated');
  
  while ($html =~ s/(.*?)\[\[([\w:]+)\]\]//sm) {
    my ($start, $page_element) = ($1, $2);
    
    $self->print($start);
    
    eval { 
      $self->$page_element->render if $self->can($page_element); 
    };
    
    $self->printf('%s - %s', $page_element, $@) if $@;
  }
  
  $self->print($html);
  $self->print("\n</body>\n</html>") unless $flag eq 'start';
}

sub render_DAS {
  my $self = shift;
  my $r = $self->renderer->{'r'};
  
  $self->{'subtype'} = 'das'; # Possibly should come from somewhere higher up 
  
  if ($r) {
    $r->headers_out->add('X-Das-Status'  => '200');
    $r->headers_out->add('X-Das-Version' => 'DAS/1.5');
  }
  
  $self->{'xsl'} = "/das/$self->{'subtype'}.xsl" if $self->{'subtype'};
  $self->render_XML;
}

sub render_XML {
  my $self = shift;

  $self->print(qq{<?xml version="1.0" standalone="no"?>\n});
  $self->print(qq{<?xml-stylesheet type="text/xsl" href="$self->{'xsl'}"?>\n}) if $self->{'xsl'};
  $self->print($self->doc_type);
  $self->print("\<$self->{'doc_type_version'}\>\n");

  foreach my $element (@{$self->{'body_order'}}) {
    my $attr = $element->[0];
    $self->$attr->render;
  }
  
  $self->print("\<\/$self->{'doc_type_version'}\>\n");

}

sub render_Excel {
  my $self = shift;

  # Switch in the Excel file renderer
  # requires the filehandle from the current renderer (works with Renderer::Apache and Renderer::File)
  my $renderer = new EnsEMBL::Web::Document::Renderer::Excel($self->renderer->fh);
  
  foreach my $element (@{$self->{'body_order'}}) {
    my $attr = $element->[0];
    $self->$attr->{'_renderer'} = $renderer;
    $self->$attr->render;
  }
  
  $renderer->close;
}

sub render_Text {
  my $self = shift;
  
  foreach my $element (@{$self->{'body_order'}}) {
    my $attr = $element->[0];
    $self->$attr->render;
  }
}

sub render_TextGz {
  my $self = shift;
  
  my $renderer = new EnsEMBL::Web::Document::Renderer::GzFile($self->species_defs->ENSEMBL_TMP_DIR . '/' . $self->temp_file_name . '.gz');
 
  foreach my $element (@{$self->{'body_order'}}) {
    my $attr = $element->[0];
    $self->$attr->{'_renderer'} = $renderer;
    $self->$attr->render;
  }
  
  $renderer->close;
  $self->renderer->print($renderer->raw_content);
  
  unlink $renderer->{'filename'};
}

sub add_error_panels { 
  my ($self, $problems) = @_;
  
  if (scalar @$problems) {
    $self->{'format'} = 'HTML';
    $self->set_doc_type('HTML', '4.01 Trans');
  }
  
  foreach my $problem (sort { $b->isFatal <=> $a->isFatal } @$problems) {
    next if $problem->isRedirect;
    next if !$problem->isFatal && $self->{'show_fatal_only'};
    
    my $desc = $problem->description;
    
    $desc = "<p>$desc</p>" unless $desc =~ /<p/;
    
    my @eg; # Find an example for the page
    my $view = uc $ENV{'ENSEMBL_SCRIPT'};
    my $ini_examples = $self->species_defs->SEARCH_LINKS;

    foreach (map { $_ =~/^$view(\d)_TEXT/ ? [$1, $_] : () } keys %$ini_examples) {
      my $url = $ini_examples->{"$view$_->[0]_URL"};
      
      push @eg, qq{ <a href="$url">$ini_examples->{$_->[1]}</a>};
    }

    my $eg_html = join ', ', @eg;
    $eg_html = '<p>Try an example: $eg_html or use the search box.</p>' if $eg_html;

    $self->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'caption' => $problem->name,
        'content' => qq{
          $desc
          $eg_html
          <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="popup">contact our HelpDesk team</a>.</p>
        }
      )
    );
  }
}

1;
