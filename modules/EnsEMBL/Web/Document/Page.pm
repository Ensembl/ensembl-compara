=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::Page;

use strict;

use Apache2::Const;
use HTML::Entities qw(encode_entities decode_entities);
use JSON           qw(from_json);

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
    HTML => { '5' => '' },
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

sub head_order :lvalue { $_[0]{'head_order'}           }
sub body_order :lvalue { $_[0]{'body_order'}           }
sub renderer   :lvalue { $_[0]{'renderer'}             }
sub elements           { return $_[0]->{'elements'};   }
sub hub                { return $_[0]->{'hub'};        }
sub species_defs       { return $_[0]{'species_defs'}; }
sub printf             { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print              { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }
sub timer_push         { $_[0]->{'timer'} && $_[0]->{'timer'}->push($_[1], 1); }

sub set_doc_type {
  my ($self, $type, $version) = @_;
  
  return unless exists $self->{'document_types'}->{$type}->{$version};
  
  $self->{'doc_type'} = $type;
  $self->{'doc_type_version'} = $version;
}

sub doc_type {
  my $self = shift;

  return '' if $self->{'doc_type'} eq 'none';

  if ($self->{'doc_type'} eq 'XML') {
    return sprintf "<!DOCTYPE %s SYSTEM %s>\n", $self->{'doc_type_version'}, $self->{'document_types'}->{$self->{'doc_type'}}->{$self->{'doc_type_version'}};
  }
  else {
    return "<!DOCTYPE html>\n";
  }
}

sub html_tag {
  my $self = shift;
  return sprintf qq{<html lang="%s">\n}, $self->{'language'};
}

# AJAX-friendly redirect, for use in control panel
# $redirect_type can be 'page' or 'modal' (defaults to 'modal') - this determines whether the whole page or just the modal panel will be reloaded
# $modal_tab is an optional string to force the modal panel to switch to the tab with that id
sub ajax_redirect {
  my ($self, $url, $redirect_type, $modal_tab) = @_;
  
  my $r         = $self->renderer->{'r'};
  my $back      = $self->{'input'}->param('wizard_back');
  my @backtrack = map $url =~ /_backtrack=$_\b/ ? () : $_, $self->{'input'}->param('_backtrack');
  
  $url .= ($url =~ /\?/ ? ';' : '?') . '_backtrack=' . join ';_backtrack=', @backtrack if scalar @backtrack;
  $url .= ($url =~ /\?/ ? ';' : '?') . "wizard_back=$back" if $back;
  
  if ($self->renderer->{'_modal_dialog_'}) {
    if (!$self->{'ajax_redirect_url'}) {
      $self->{'ajax_redirect_url'} = $url;
      $redirect_type ||= 'modal';
      $modal_tab     ||= '';
      
      $r->content_type('text/plain');
      print qq({"redirectURL":"$url", "redirectType":"$redirect_type", "modalTab":"$modal_tab"});
    }
  } else {
    $r->headers_out->set('Location' => $url);
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

sub initialize {
  my $self   = shift;
  my $method = 'initialize_' . ($self->hub && $self->hub->has_fatal_problem && $self->can('initialize_error') ? 'error' : $self->{'format'});
  
  $self->$method;
  $self->modify_elements;
  $self->_init;
  $self->extra_configuration;
}

sub initialize_search_bot {
  my $self = shift;
  $self->add_head_elements(qw(title   EnsEMBL::Web::Document::Element::Title));
  $self->add_body_elements(qw(content EnsEMBL::Web::Document::Element::Content));
}

sub _init {
  my $self = shift;
  
  foreach my $entry (@{$self->head_order}, @{$self->body_order}) {
    my ($element, $classname) = @$entry; # example: $entry = [ 'content', 'EnsEMBL::Web::Document::Element::Content' ]
    
    next unless $self->dynamic_use($classname); 
    
    my $module;
    
    eval { 
      $module = $classname->new({
        timer    => $self->{'timer'},
        input    => $self->{'input'},
        format   => $self->{'format'},
        hub      => $self->hub,
        renderer => $self->renderer
      });
    };
    
    if ($@) {
      warn $@;
      next;
    }
    
    $self->{'elements'}->{$element} = $module;
    
    no strict 'refs';
    my $method_name = ref($self) . "::$element";
    *$method_name = sub :lvalue { $_[0]->{'elements'}->{$element} }; # Make the element name into function call on Document::Page.
  }
}

sub modify_elements     {} # Implemented in plugins: configuration before _init
sub extra_configuration {} # Implemented in plugins: configuration after  _init

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

sub clean_HTML {
  my ($self, $content) = @_;
  $content =~ s/<(div|p|h\d|br).*?>/\n/g;   # Replace the start of block elements with a new line
  $content =~ s/<(\/(div|p|h\d).*)>/\n\n/g; # Replace the end of block elements with two new lines
  $content =~ s/&nbsp;/ /g;                 # decode_entities replaces &nbsp; with chr(160), rather than chr(32), so do this regex first
  $content =~ s/^\n+//;                     # Strip leading new lines
  return decode_entities($self->strip_HTML($content));
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
  my $self    = shift;
  my $content = qq(<?xml version="1.0" standalone="no"?>\n);
  $content   .= qq(<?xml-stylesheet type="text/xsl" href="$self->{'xsl'}"?>\n) if $self->{'xsl'};
  $content   .= $self->doc_type;
  $content   .= "\<$self->{'doc_type_version'}\>\n";
  $content   .= shift->{'content'};
  $content   .= "\<\/$self->{'doc_type_version'}\>\n";
  
  $self->renderer->r->content_type('text/xml');
  
  print $content;
}

sub render_RTF   { return shift->render_file('rtf',          'rtf', @_); }
sub render_Excel { return shift->render_file('octet-string', 'csv', @_); }

sub render_file {
  my $self     = shift;
  my $hub      = $self->hub;
  my $renderer = $self->renderer;
  my $r        = $renderer->r;
  
  $r->content_type(sprintf 'application/%s', shift);
  $r->headers_out->add('Content-Disposition' => sprintf 'attachment; filename=%s.%s', $hub->param('filename'), shift);
  
  print $self->clean_HTML(shift->{'content'});
}

sub render_Text {
  my $self = shift;
  
  $self->renderer->r->content_type('text/plain');
  
  print $self->clean_HTML(shift->{'content'});
}

sub _json_html_strip {
  my ($self, $in) = @_;
  
  if ($in =~ /^(.*?)([\[{].*[\]}])(.*?)/s) {
    my ($pre, $data, $post) = ($1, $2, $3);
    return $self->strip_HTML($pre) . $data . $self->strip_HTML($post);
  } else {
    return $in;
  }
}

sub render_JSON {
  my $self = shift;
  
  $self->renderer->r->content_type('text/plain');
  
  my @content;
  
  # FIXME
  # Ok, this is properly awful. content is wrapped in HTML, which we then remove.
  # However, this can leave random strings behind, which are not JSON format,
  # so we need to check each line to see if it is a JSON, and throw away the ones which aren't.
  # A better way would be to rewrite the way we render all content so that, say, components return
  # content in the required format.

  # We want to strip outer HTML from the JSON but not any 
  # embedded HTML within the JSON. So we strip only HTML before the first { or [
  # (if any) and after the last } ], if any.

  foreach (split /\n/, $self->_json_html_strip(shift->{'content'})) {
    s/^\s+//;
    eval { from_json($_); };
    push @content, $_ unless $@;
  }
  
  if (scalar @content == 1) {
    print $content[0];
  } else {
    printf '[%s]', join ',', @content;
  }
}

sub render_TextGz {
  my $self     = shift;
  my $renderer = EnsEMBL::Web::Document::Renderer::GzFile->new($self->species_defs->ENSEMBL_TMP_DIR . '/' . $self->temp_file_name . '.gz');
  
  $renderer->print(shift->{'content'});
  $renderer->close;
  
  print  $renderer->raw_content;
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
    $json{'params'}{'url'}     = $self->hub->url({ __clear => 1 });
    $json{'params'}{'species'} = $self->hub->species;
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

sub main_class {
  my ($self) = @_;

  my $here = $ENV{'REQUEST_URI'};
  if ( ($self->isa('EnsEMBL::Web::Document::Page::Fluid') && $here !~ /\/Search\//) 
        || ($self->isa('EnsEMBL::Web::Document::Page::Dynamic') && $here =~ /\/Info\//)
        || ($self->isa('EnsEMBL::Web::Document::Page::Static') 
              && (($here =~ /Doxygen\/(\w|-)+/ && $here !~ /Doxygen\/index.html/) || $here !~ /^\/info/))
    ) {
    return 'widemain';
  }
  else {
    return 'main';
  }

}

sub html_template {
  ### Main page printing function
  
  my ($self, $elements) = @_;
  
  $self->set_doc_type('HTML',  '5');
  $self->add_body_attr('id',    'ensembl-webpage');
  $self->add_body_attr('class', 'mac')                               if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  $self->add_body_attr('class', "ie ie$1" . ($1 < 8 ? ' ie67' : '')) if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 <  9;
  $self->add_body_attr('class', "ienew ie$1")                        if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/ && $1 >= 9;
  $self->add_body_attr('class', 'no_tabs')                           unless $elements->{'tabs'};
  $self->add_body_attr('class', 'static')                            if $self->isa('EnsEMBL::Web::Document::Page::Static');
  
  my $species_path        = $self->species_defs->species_path;
  my $species_common_name = $self->species_defs->SPECIES_COMMON_NAME;
  my $max_region_length   = 1000100 * ($self->species_defs->ENSEMBL_GENOME_SIZE || 1);
  my $core_params         = $self->hub ? $self->hub->core_params : {};
  my $core_params_html    = join '',   map qq(<input type="hidden" name="$_" value="$core_params->{$_}" />), keys %$core_params;
  my $html_tag            = join '',   $self->doc_type, $self->html_tag;
  my $head                = join "\n", map $elements->{$_->[0]} || (), @{$self->head_order};  
  my $body_attrs          = join ' ',  map { sprintf '%s="%s"', $_, $self->{'body_attr'}{$_} } grep $self->{'body_attr'}{$_}, keys %{$self->{'body_attr'}};
  my $tabs                = $elements->{'tabs'} ? qq(<div class="tabs_holder print_hide">$elements->{'tabs'}</div>) : '';
  my $footer_id           = 'wide-footer';
  my $panel_type          = $self->can('panel_type') ? $self->panel_type : '';
  my $main_holder         = $panel_type ? qq(<div id="main_holder" class="js_panel">$panel_type) : '<div id="main_holder">';

  my $main_class = $self->main_class();        

  my $nav_class           = $self->isa('EnsEMBL::Web::Document::Page::Configurator') ? 'cp_nav' : 'nav';
  my $nav;
  my $icons = $self->icon_bar if $self->can('icon_bar');  

  if ($self->include_navigation) {
    $nav = qq(<div id="page_nav_wrapper">
        <div id="page_nav" class="$nav_class print_hide js_panel slide-nav floating">
          $elements->{'navigation'}
          $elements->{'tool_buttons'}
          $elements->{'acknowledgements'}
          <p class="invisible">.</p>
        </div>
      </div>
    );
    
    $footer_id = 'footer';
  }
  
  return qq($html_tag
<head>
  $head
</head>
<body $body_attrs>
  <div id="min_width_container">
    <div id="min_width_holder">
      <div id="masthead" class="js_panel">
        <input type="hidden" class="panel_type" value="Masthead" />
        <div class="logo_holder">$elements->{'logo'}</div>
        <div class="mh print_hide">
          <div class="account_holder">$elements->{'account'}</div>
          <div class="tools_holder">$elements->{'tools'}</div>
          <div class="search_holder print_hide">$elements->{'search_box'}</div>
        </div>
        $tabs
        $icons
      </div>
      $main_holder
        $nav
        <div id="$main_class">
          $elements->{'breadcrumbs'}
          $elements->{'message'}
          $elements->{'content'}
          $elements->{'mobile_nav'}
        </div>
        <div id="$footer_id">
          <div class="column-wrapper">$elements->{'copyright'}$elements->{'footerlinks'}
            <p class="invisible">.</p>
          </div>
        </div>
      </div>
    </div>
  </div>
  <form id="core_params" action="#" style="display:none">
    <fieldset>$core_params_html</fieldset>
  </form>
  <input type="hidden" id="species_path" name="species_path" value="$species_path" />
  <input type="hidden" id="species_common_name" name="species_common_name" value="$species_common_name" />
  <input type="hidden" id="max_region_length" name="max_region_length" value="$max_region_length" />
  $elements->{'modal'}
  $elements->{'body_javascript'}
</body>
</html>
);
}

1;
