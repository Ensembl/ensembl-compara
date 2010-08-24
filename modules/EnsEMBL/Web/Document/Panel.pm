package EnsEMBL::Web::Document::Panel;

use strict;

use HTML::Entities qw(encode_entities);
use HTTP::Request;

use EnsEMBL::Web::Document::Renderer::Assembler;
use EnsEMBL::Web::Document::Renderer::String;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  
  my $self = {
    _renderer       => undef,
    components      => {},
    component_order => [],
    disable_ajax    => 0,
    @_
  };
  
  bless $self, $class;
  return $self;
}

sub renderer :lvalue  { $_[0]->{'_renderer'}; }
sub clear_components  { $_[0]{'components'} = {}; $_[0]->{'component_order'} = []; }
sub components        { return @{$_[0]{'component_order'}}; }
sub component         { return $_[0]->{'components'}->{$_[1]}; } # Given a component code, returns the component itself
sub params            { return $_[0]->{'params'}; }
sub status            { return $_[0]->{'status'}; }
sub code              { return $_[0]->{'code'};   }
sub print             { shift->renderer->print(@_);  }
sub printf            { shift->renderer->printf(@_); }
sub timer_push        { $_[0]->{'timer'} && $_[0]->{'timer'}->push($_[1], 3 + $_[2]); }
sub _is_ajax_request  { return $_[0]->renderer->can('r') && $_[0]->renderer->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; }
sub ajax_is_available { return 1; }

sub caption {
  my $self = shift;
  $self->{'caption'} = shift if (@_);
  return $self->{'caption'};
}

sub _error {
  my ($self, $caption, $message) = @_;
  
  $self->print("<h4>$caption</h4>$message");
}

sub parse {
  my $self   = shift;
  my $string = shift;
  $string =~ s/\[\[object->(\w+)\]\]/$self->{'object'}->$1/eg;
  return $string;
}

=head2 Panel options.

There are five functions which set, clear and read the options for the panel

=over 4

=item C<$panel-E<gt>clear_option( $key )>

resets the option C<$key>

=item C<$panel-E<gt>add_option( $key, $val )>

sets the value of option C<$key> to C<$val>

=item C<$panel-E<gt>option( $key )>

returns the value of option C<$key>

=item C<$panel-E<gt>clear_options>

resest the options list

=item C<$panel-E<gt>options>

returns an array of option keys.

=back

=cut

sub clear_options { $_[0]{'_options'} = {};            }
sub clear_option  { delete $_[0]->{'_options'}{$_[1]}; }
sub add_option    { $_[0]{'_options'}{$_[1]} = $_[2];  }
sub option        { return $_[0]{'_options'}{$_[1]};   }
sub options       { return keys %{$_[0]{'_options'}};  }

=head2 Panel components.

There are a number of functions which set, clear, modify the list of 
components which make up the panel.

=over 4

=item C<$panel-E<gt>add_components(       $new_key, $function_name, [...] )>

Adds one or more components to the end of the component list

=item C<$panel-E<gt>remove_component(    $key )>

Removes the function called by the component named C<$key>

=item C<$panel-E<gt>replace_component(    $key,     $function_name )>

Replaces the function called by the component named C<$key> with a new function
named C<$function_name>

=item C<$panel-E<gt>prepend_to_component( $key,     $function_name )>

Extends a component, by adding another function call to the start of the list
keyed by name C<$key>. When the page is rendered each function for the component
will be called in turn (until one returns 0)

=item C<$panel-E<gt>add_to_component(     $key,     $function_name )>

Extends a component, by adding another function call to the end of the list
keyed by name C<$key>. When the page is rendered each function for the component
will be called in turn (until one returns 0)

=item C<$panel-E<gt>add_component_before( $key,     $new_key, $function_name )>

Adds a new component to the component list before the one
named C<$key>, and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_after(  $key,     $new_key, $function_name )>

Adds a new component to the component list after the one
named C<$key>, and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_first(  $new_key, $function_name )>

Adds a new component to the start of the component list and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component_last(   $new_key, $function_name )>

Adds a new component to the end of the component list and gives it the name C<$new_key>

=item C<$panel-E<gt>add_component(        $new_key, $function_name )>

Adds a new component to the end of the component list and gives it the name C<$new_key>

=back 

=cut

sub add_components {
  my $self = shift;
  
  while (my ($code, $function) = splice(@_, 0, 2)) {
    if (exists $self->{'components'}{$code}) {
      push @{$self->{'components'}{$code}}, $function;
    } else {
      push @{$self->{'component_order'}}, $code;
      $self->{'components'}{$code} = [ $function ];
    }
  }
}

sub replace_component {
  my ($self, $code, $function, $flag) = @_;
  
  if ($self->{'components'}{$code}) {
    $self->{'components'}{$code} = [ $function ];
  } elsif ($flag ne 'no') {
    $self->add_component_last($code, $function);
  }
}

sub prepend_to_component {
  my ($self, $code, $function) = @_;
  return $self->add_component_first($code, $function) unless exists $self->{'components'}{$code};
  unshift @{$self->{'components'}{$code}}, $function;
}

sub add_to_component {
  my ($self, $code, $function) = @_;
  return $self->add_component_last($code, $function) unless exists $self->{'components'}{$code};
  push @{$self->{'components'}{$code}}, $function;
}

sub add_component_before {
  my ($self, $oldcode, $code, $function) = @_;
  
  return $self->prepend_to_component($code, $function) if exists $self->{'components'}{$code};
  return $self->add_component_first($code, $function) unless exists $self->{'components'}{$oldcode};
  
  my $i = 0;
  
  foreach (@{$self->{'component_order'}}) {
    if ($_ eq $oldcode) {
      splice @{$self->{'component_order'}}, $i, 0, $code;
      $self->{'components'}{$code} = [ $function ];
      return;
    }
    
    $i++;
  }
}

sub add_component_first {
  my ($self, $code, $function) = @_;
  return $self->prepend_to_component($code, $function) if exists $self->{'components'}{$code};
  unshift @{$self->{'component_order'}}, $code;
  $self->{'components'}{$code} = [ $function ];
}

sub add_component { my $self = shift; $self->add_component_last( @_ ); }

sub add_component_last {
  my ($self, $code, $function) = @_;
  return $self->add_to_component($code, $function) if exists $self->{'components'}{$code};
  push @{$self->{'component_order'}}, $code;
  $self->{'components'}{$code} = [ $function ];
}

sub add_component_after {
  my ($self, $oldcode, $code, $function) = @_;
  
  return $self->add_to_component($code, $function) if exists $self->{'components'}{$code};
  return $self->add_component_first($code, $function) unless exists $self->{'components'}{$oldcode};

  my $i = 0;
  
  foreach (@{$self->{'component_order'}}) {
    if ($_ eq $oldcode) {
      splice @{$self->{'component_order'}}, $i+1, 0, $code;
      $self->{'components'}{$code} = [ $function ];
      return;
    }
    
    $i++;
  }
  
  $self->{'components'}{$code} = [ $function ];
}

sub remove_component {
  my ($self, $code) = @_;
  
  my $i = 0;
  
  foreach (@{$self->{'component_order'}}) {
    if ($_ eq $code) {
      splice @{$self->{'component_order'}}, $i, 1;
      delete $self->{'components'}{$code};
      return;
    }
    
    $i++;
  }
}

sub render_Text {
  my $self = shift;
  $self->{'disable_ajax'} = 1;
  $self->content_Text;
}

sub render_TextGz { $_[0]->render_Text; }
sub render_DAS    { $_[0]->render_XML;  }
sub render_XML    { $_[0]->content;     }
sub render_Excel  { $_[0]->content;     }

sub content_Text { 
  my $self = shift;
  
  my $temp_renderer = $self->renderer;
  
  $self->renderer = new EnsEMBL::Web::Document::Renderer::String;
  $self->content;
  
  my $value = $self->renderer->content;
  
  $self->renderer = $temp_renderer;
  $self->renderer->print($value)
}

sub render {
  my ($self, $first) = @_;
  
  return $self->renderer->print($self->{'raw'}) if exists $self->{'raw'};
  
  my $hub        = $self->{'hub'};
  my $status     = $hub ? $hub->param($self->{'status'}) : undef;
  my $panel_type = $self->renderer->{'_modal_dialog_'} ? 'ModalContent' : 'Content';
  my $html       = qq{<div class="panel js_panel"><input type="hidden" class="panel_type" value="$panel_type" />};
  my $counts     = {};

  if (!$self->{'omit_header'}) {
    if ((exists $self->{'previous'} || exists $self->{'next'}) && $hub && $hub->type ne 'Search') {
      my @buttons = (
        [ 'previous', 'left',  '&laquo;&nbsp;%s' ],
        [ 'next',     'right', '%s&nbsp;&raquo;' ]
      );
      
      $html .= '<div class="nav-heading">';
      
      foreach (@buttons) {
        my $label = $_->[0];
        my $button_text = exists $self->{$label} && !$self->{$label}->{'external'} ? $self->{$label}->{'concise'} || $self->{$label}->{'caption'} : undef;
        
        $html .= qq{
          <div class="$_->[1]-button print_hide">};
        
        if ($button_text) {
          my $url = $self->{$label}->{'url'} || $hub->url({ action => $self->{$label}->{'code'}, function => undef });
          
          $html .= sprintf qq{<a href="%s">$_->[2]</a>}, encode_entities($url), encode_entities($button_text);
        } else {
          $html .= '<span>&nbsp;</span>'; # Do not remove this span it breaks IE7 if only a &nbsp;
        }
        
        $html .= '</div>';
      }
      
      $html .= $self->_caption_with_helplink if exists $self->{'caption'};
      $html .= '
      <p class="invisible">.</p></div>';
    } elsif (exists $self->{'caption'}) {
      $html .= $self->_caption_with_helplink;
    }
  }
  
  $self->renderer->print($html) unless $self->{'json'};
  
  if ($status ne 'off') {
    my $temp_renderer = $self->renderer;
    
    $self->renderer = new EnsEMBL::Web::Document::Renderer::Assembler(
      r              => $temp_renderer->r,
      cache          => $temp_renderer->cache,
      session        => $hub ? $hub->session : undef,
      _modal_dialog_ => $temp_renderer->{'_modal_dialog_'}
    );
    
    $self->_render_content;
    $self->renderer->close;

    my $content = $self->renderer->content;
    
    return qq{$content<p class="invisible">.</p>} if $self->{'json'};
    
    $self->renderer = $temp_renderer;
    $self->renderer->print($content);
  }
  
  $self->renderer->print('
  <p class="invisible">.</p></div>');
}

sub _caption_with_helplink {
  my $self = shift;
  my $id   = $self->{'help'};
  my $html = '<h2 class="caption">';
  $html   .= sprintf ' <a href="/Help/View?id=%s" class="popup help-header constant" title="Click for Help">', encode_entities($id) if $id;
  $html   .= $self->{'raw_caption'} ? $self->{'caption'} : encode_entities($self->{'caption'});
  $html   .= ' <img src="/i/help-button.png" style="width:40px;height:20px;padding-left:4px;vertical-align:middle" alt="(e?)" class="print_hide" /></a>' if $id;
  $html   .= '</h2>';
  
  return $html; 
}

sub _render_content {
  my $self = shift;
  
  $self->renderer->print('
    <div class="content">'
   );
      
  $self->content;
  
  my $caption = exists $self->{'caption'} ? encode_entities($self->parse($self->{'caption'})) : '';
  
  if ($self->{'link'}) {
    $self->renderer->printf('
      <div class="more"><a href="%s">more about %s ...</a></div>', $self->{'link'}, $caption
    );
  }
  
  $self->renderer->print('
    </div>'
  );
}

sub content {
  my ($self) = @_;
  
  $self->print($self->{'content'}) if $self->{'content'};
  
  my $model = $self->{'model'};
  my $hub   = $self->{'hub'};
  
  return unless $model;
  
  $self->das_content if $self->{'components'}->{'das_features'};
  
  foreach my $entry (map @{$self->{'components'}->{$_} || []}, $self->components) {
    my ($module_name, $function_name) = split /\//, $entry;
    my $component;
    
    if ($self->dynamic_use($module_name)) {
      eval {
        $component = $module_name->new($model);
      };
      
      if ($@) {
        $self->component_failure($@, $entry, $module_name);
        next;
      }
    } else {
      $self->component_failure($self->dynamic_use_failure($module_name), $entry, $module_name);
      next;
    }
    
    if (!$self->{'disable_ajax'} && $component->ajaxable && !$self->_is_ajax_request) {
      my $url   = $component->ajax_url($function_name);
      my $class = 'initial_panel' . ($component->has_image ? ' image_panel' : '');
      
      # Check if ajax enabled
      if ($ENSEMBL_WEB_REGISTRY->check_ajax) {
        # Safari requires a unique name on inputs when using browser-cached content (eq when the user presses the back button)
        # $panel_name is the memory location of the current object, so unique for each panel.
        # Without this, ajax panels don't load, or load the wrong content.
        my ($panel_name) = $self =~ /\((.+)\)$/;
        
        $self->printf(qq{<div class="ajax $class"><input type="hidden" class="ajax_load" name="$panel_name" value="%s" /></div>}, encode_entities($url));
      } elsif ($self->renderer->isa('EnsEMBL::Web::Document::Renderer::Assembler')) {
        # if ajax disabled - we get all content by parallel requests to ourself
        $self->print(qq{<div class="$class">}, HTTP::Request->new('GET', $hub->species_defs->ENSEMBL_BASE_URL . $url), '</div>');
      }
    } else {
      my $content;
      
      eval {
        my $func = $self->_is_ajax_request ? lc $hub->function : $function_name;
        $func    = "content_$func" if $func;
        $content = $func && $component->can($func) ? $component->$func : $component->content;
      };
      
      if ($@) {
        $self->component_failure($@, $entry, $module_name);
        next;
      }
      
      if ($content) {
        if ($self->_is_ajax_request) {
          my $id         = $hub->function eq 'sub_slice' ? '' : $component->id;
          my $panel_type = $self->renderer->{'_modal_dialog_'} || $content =~ /panel_type/ ? '' : '<input type="hidden" class="panel_type" value="Content" />';
          
          # Only add the wrapper if $content is html, and the update_panel parameter isn't present
          $content = qq{<div class="js_panel" id="$id">$panel_type$content</div>} if !$hub->param('update_panel') && $content =~ /^\s*<.+>\s*$/s;
        } else {
          my $caption = $component->caption;
          $self->printf('<h2>%s</h2>', encode_entities($caption)) if $caption;
        }
        
        $self->print($content);
      }
      
      $self->timer_push("Component $module_name succeeded");
    }
  }
}

sub das_content {
  my $self  = shift;
  my $model = $self->{'model'};
  
  foreach my $function_name (@{$self->{'components'}->{'das_features'}}) {
    my $result;
    (my $module_name = $function_name) =~ s/::\w+$//;
    
    if ($self->dynamic_use($module_name)) {          
      no strict 'refs';
      
      eval {
        $result = &$function_name($self, $model);
      };
      
      $self->component_failure($@, 'das_features', $function_name) if $@;
    } else {
      warn "Component $function_name (compile failure)";
      
      $self->_error(
        qq{Compile error in component "<strong>das_features</strong>"},
        qq{<p>Function <strong>$function_name</strong> not executed as unable to use module <strong>$module_name</strong> due to syntax error.</p>} . $self->_format_error($self->dynamic_use_failure($module_name))
      );
    }
    
    last if $result;
  }
  
  delete $self->{'components'}->{'das_features'};
}

sub component_failure {
  my ($self, $error, $component, $module_name) = @_;
  
  warn $error;
  
  $self->_error(
    qq{Runtime Error in component "<strong>$component</strong> [content]"},
    qq{<p>Function <strong>$module_name</strong> fails to execute due to the following error:</p>} . $self->_format_error($error)
  );
  
  $self->timer_push("Component $module_name (runtime failure [content])");
}

1;
