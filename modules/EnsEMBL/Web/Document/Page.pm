=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
use Image::Minifier qw(generate_sprites);

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

sub template           { return $_[0]->{'template'};   }
sub head_order :lvalue { $_[0]{'head_order'}           }
sub body_order :lvalue { $_[0]{'body_order'}           }
sub renderer   :lvalue { $_[0]{'renderer'}             }
sub elements           { return $_[0]->{'elements'};   }
sub hub                { return $_[0]->{'hub'};        }
sub species_defs       { return $_[0]{'species_defs'}; }
sub printf             { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print              { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

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
  my @backtrack = map $url =~ /_backtrack=$_\b/ ? () : $_, $self->{'input'}->param('_backtrack');
  
  $url .= ($url =~ /\?/ ? ';' : '?') . '_backtrack=' . join ';_backtrack=', @backtrack if scalar @backtrack;
  
  if ($self->renderer->{'_modal_dialog_'}) {
    if (!$self->{'ajax_redirect_url'}) {
      $self->{'ajax_redirect_url'} = $url;
      $redirect_type ||= 'modal';
      $modal_tab     ||= '';
      
      $r->content_type('text/plain');
      print qq({"redirectURL":"$url", "redirectType":"$redirect_type", "modalTab":"$modal_tab"});
    }
  } else {
    $self->hub->redirect($url);
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

  ## Set up HTML template if needed by "real" pages, i.e. not JSON
  # if ($self->{'format'} eq 'HTML' && !$self->renderer->{'_modal_dialog_'}) { FIXME - ENSWEB-2781
  if (($self->{'format'} eq 'HTML' || $self->{'format'} eq 'search_bot') && !$self->renderer->{'_modal_dialog_'}) {
    my $template_name   = $self->hub->template;
    if (!$template_name) {
      my @namespace   = split('::', ref $self);
      my $type        = $namespace[-1];
      $template_name  = $type eq 'Dynamic' ? 'Legacy' : "Legacy::$type";
    }

    my $template_class  = 'EnsEMBL::Web::Template::'.$template_name;

    if ($self->dynamic_use($template_class)) {
      my $template = $template_class->new({'page' => $self});
      if ($template) {
        $template->init;
        $self->{'template'} = $template;
      }
    }
  }

  ## Additional format-specific initialisation 
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
  
  my %shared;
  foreach my $entry (@{$self->head_order}, @{$self->body_order}) {
    my ($element, $classname) = @$entry; # example: $entry = [ 'content', 'EnsEMBL::Web::Document::Element::Content' ]
    
    next unless $self->dynamic_use($classname); 
    
    my $module;
    
    eval { 
      $module = $classname->new({
        input    => $self->{'input'},
        format   => $self->{'format'},
        hub      => $self->hub,
        renderer => $self->renderer,
        shared   => \%shared,
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
##### UNUSED? ###########
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
#### ONLY USED BY OLD EXPORT ########
  my $self     = shift;
  my $renderer = EnsEMBL::Web::Document::Renderer::GzFile->new($self->species_defs->ENSEMBL_TMP_DIR . '/export/' . $self->temp_file_name . '.gz');
  
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
  my $ie = $self->hub->ie_version;
  unless($ie and $ie < 8) {
    $content = generate_sprites($self->hub->species_defs,$content);
  }

  print  $content;
  return $content;
}

sub html_template {
  ### Main page printing function
  
  my ($self, $elements) = @_;
 
  my $HTML;

  ## HTML TAG AND HEADER - ALL PAGES NEED THIS! 
  $self->set_doc_type('HTML',  '5');
  $self->add_body_attr('id',    'ensembl-webpage');
  $self->add_body_attr('class', 'mac')                               if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  my $ie = $self->hub->ie_version;
  if ($ie && $ie <= 11) {
    if ($ie < 9) {
      $self->add_body_attr('class', "ie ie$ie" . ($ie < 8 ? ' ie67' : ''));
    }
    elsif ($ie eq '10') {
      $self->add_body_attr('class', "ienew ie$1");
    } else {
      $self->add_body_attr('class', "ie11");
    }
  }
  $self->add_body_attr('class', 'no_tabs')                           unless $elements->{'tabs'};
  $self->add_body_attr('class', 'static')                            if $self->isa('EnsEMBL::Web::Document::Page::Static');
  $self->add_body_attr('data-pace',$SiteDefs::PACED_MULTI||8);

  $self->modify_page_settings;

  my $body_attrs = join ' ',  map { sprintf '%s="%s"', $_, $self->{'body_attr'}{$_} } grep $self->{'body_attr'}{$_}, keys %{$self->{'body_attr'}};

  my $html_tag = join '',   $self->doc_type, $self->html_tag;

  my $head = join "\n", map $elements->{$_->[0]} || (), @{$self->head_order};
  
  $HTML = qq($html_tag
<head>
  $head
</head>
<body $body_attrs>
);

  # FIXME - ENSWEB-2781
  if ($self->{'format'} eq 'search_bot') {
    $elements->{$_} = '' for grep { !m/content|title/ } keys %$elements;
  }

  ## CONTENTS OF BODY TAG DETERMINED BY TEMPLATE MODULE
  my $template = $self->template;
  $HTML .= $template->render($elements);

  ## END OF PAGE - COMPULSORY
  $HTML .= qq(
</body>
</html>
);
  return $HTML;
}

sub modify_page_settings {}

1;
