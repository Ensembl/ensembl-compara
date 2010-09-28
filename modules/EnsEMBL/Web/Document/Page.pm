# $Id$

package EnsEMBL::Web::Document::Page;

use strict;

use Apache2::Const;
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
    elements         => {},
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
sub hub                    { return $_[0]->{'hub'};      }
sub elements               { return $_[0]->{'elements'}; }
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
  
  foreach my $entry (@{$self->head_order}, @{$self->body_order}) {
    my ($element, $classname) = @$entry; # example: $entry = [ 'content', 'EnsEMBL::Web::Document::HTML::Content' ]
    
    next unless $self->dynamic_use($classname); 
    
    my $doc_module;
    
    eval { 
      $doc_module = $classname->new($self->{'timer'}, $self->{'input'}); # Construct the module
      $doc_module->{'species_defs'} = $self->species_defs;
      $doc_module->{'_renderer'}    = $self->renderer;
      $doc_module->{'format'}       = $self->{'format'};
    };
    
    if ($@) {
      warn $@;
      next;
    }
    
    $self->{'elements'}->{$element} = $doc_module;
    
    no strict 'refs';
    my $method_name = ref($self) . "::$element";
    *$method_name = sub :lvalue { $_[0]->{'elements'}->{$element} }; # Make the element name into function call on Document::Page.
  }
}

sub initialize {
  my $self = shift;
  my $method = '_initialize_' . ($self->hub && $self->hub->has_fatal_problem && $self->can('_initialize_error') ? 'error' : $self->{'format'});
  $self->$method;
  $self->_init;
}

sub clear_body_attr {
  my ($self, $key) = @_;
  delete $self->{'body_attr'}{$key};
}

sub add_body_attr {
  my ($self, $key, $value) = @_;
  $self->{'body_attr'}{lc $key} .= ($self->{'body_attr'}{lc $key} ? ' ' : '') . encode_entities($value);
}

sub include_navigation {
  my $self = shift;
  $self->{'_has_navigation'} = shift if @_;
  return $self->{'_has_navigation'};
}

sub render {
  my $self = shift;
  my $func = $self->can("render_$self->{'format'}") ? "render_$self->{'format'}" : 'render_HTML';
  return $self->$func(@_);
}

sub render_start { shift->render_HTML('start'); }
sub render_end   { shift->render_HTML('end');   }

sub render_DAS {
  my $self = shift;
  my $r    = $self->renderer->r;
  
  $self->{'subtype'} = 'das'; # Possibly should come from somewhere higher up 
  
  if ($r) {
    $r->headers_out->add('X-Das-Status'  => '200');
    $r->headers_out->add('X-Das-Version' => 'DAS/1.5');
  }
  
  $self->{'xsl'} = "/das/$self->{'subtype'}.xsl" if $self->{'subtype'};
  $self->render_XML(@_);
}

sub render_XML {
  my $self     = shift;
  my $content .= qq{<?xml version="1.0" standalone="no"?>\n};
  $content    .= qq{<?xml-stylesheet type="text/xsl" href="$self->{'xsl'}"?>\n} if $self->{'xsl'};
  $content    .= $self->doc_type;
  $content    .= "\<$self->{'doc_type_version'}\>\n";
  $content    .= shift->{'content'};
  $content    .= "\<\/$self->{'doc_type_version'}\>\n";
  
  $self->renderer->r->content_type('text/xml');
  
  print $content;
}

sub render_Excel {
  my $self = shift;
  
  # Switch in the Excel file renderer.
  # Requires the filehandle from the current renderer (works with Renderer::Apache and Renderer::File)
  my $renderer = new EnsEMBL::Web::Document::Renderer::Excel($self->renderer->fh, r => $self->renderer->r);

  $renderer->print(shift->{'content'});
  $renderer->close;
}

sub render_Text {
  my $self = shift;
  $self->renderer->r->content_type('text/plain');
  print shift->{'content'};
}

sub render_TextGz {
  my $self     = shift;
  my $content  = shift->{'content'};
  my $renderer = new EnsEMBL::Web::Document::Renderer::GzFile($self->species_defs->ENSEMBL_TMP_DIR . '/' . $self->temp_file_name . '.gz');
  
  $renderer->print($content);
  $renderer->close;
  
  print $renderer->raw_content;
  unlink $renderer->{'filename'};
}

sub render_HTML {
  my ($self, $elements) = @_;
  my $renderer = $self->renderer;
  my $r        = $renderer->r;
  my $content;
  
  # If this is an AJAX request then we will not render the page wrapper
  if ($renderer->{'_modal_dialog_'}) {
    my %json = map %{$elements->{$_}}, keys %$elements;
    $content = $self->jsonify(\%json);
  } elsif ($renderer->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
    $content = $elements->{'content'}; # Render content only for components
  } else {
    $content = $self->html_template($elements);
  }
  
  $r->content_type('text/html; charset=utf-8') unless $r->content_type;
  
  print  $content;
  return $content;
}

sub html_template {
  ### Main page printing function
  
  my ($self, $elements) = @_;
  
  $self->set_doc_type('XHTML',  '1.0 Trans');
  $self->add_body_attr('id',    'ensembl-webpage');
  $self->add_body_attr('class', 'mac')     if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  $self->add_body_attr('class', 'no_tabs') unless $elements->{'global_context'};
  
  my $species_path        = $self->species_defs->species_path;
  my $species_common_name = $self->species_defs->SPECIES_COMMON_NAME;
  my $core_params         = $self->hub ? $self->hub->core_params : {};
  my $core_params_html    = join '', map qq{<input type="hidden" name="$_" value="$core_params->{$_}" />}, keys %$core_params;
  my $html_tag            = join '', $self->doc_type, $self->html_tag;
  my $head                = join "\n", map $elements->{$_->[0]} || (), @{$self->head_order};  
  my $body_attrs          = join ' ', map { sprintf '%s="%s"', $_, $self->{'body_attr'}{$_} } grep $self->{'body_attr'}{$_}, keys %{$self->{'body_attr'}};
  my $footer_id           = 'wide-footer';
  my $panel_type          = $self->can('panel_type') ? $self->panel_type : '';
  my $main_holder         = $panel_type ? qq{<div id="main_holder" class="js_panel">$panel_type} : '<div id="main_holder">';
  my $nav;
  
  if ($self->include_navigation) {
    $nav = qq{<div id="nav" class="print_hide js_panel">
          $elements->{'local_context'}
          $elements->{'local_tools'}
          $elements->{'acknowledgements'}
          <p class="invisible">.</p>
        </div>
    };
    
    $footer_id = 'footer';
  }
  
  $html_tag = qq{<?xml version="1.0" encoding="utf-8"?>\n$html_tag} if $self->{'doc_type'} eq 'XHTML';
  
  return qq{
$html_tag
<head>
  $head
</head>
<body $body_attrs>
  <div id="min_width_container">
    <div id="min_width_holder">
      <div id="masthead" class="js_panel">
        <input type="hidden" class="panel_type" value="Masthead" />
        <div class="content">
          <div class="mh print_hide">
            <span class="logo_holder">$elements->{'logo'}</span>
            <div class="tools_holder">$elements->{'tools'}</div>
            <div class="search_holder print_hide">$elements->{'search_box'}</div>
          </div>
          $elements->{'breadcrumbs'}
          <div class="tabs_holder print_hide">$elements->{'global_context'}</div>
        </div>
      </div>
      <div class="invisible"></div>
      $main_holder
        $nav
        <div id="main">
          $elements->{'message'}
          $elements->{'content'}
        </div>
        <div id="$footer_id">$elements->{'copyright'}$elements->{'footerlinks'}</div>
      </div>
    </div>
  </div>
  <form id="core_params" action="#" style="display:none">
    <fieldset>$core_params_html</fieldset>
  </form>
  <input type="hidden" id="species_path" name="species_path" value="$species_path" />
  <input type="hidden" id="species_common_name" name="species_common_name" value="$species_common_name" />
  $elements->{'modal_context'}
  $elements->{'body_javascript'}
</body>
</html>
};
}

1;
