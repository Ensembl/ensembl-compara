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

package EnsEMBL::Web::Component;

### Parent module for page components that output HTML content
###
### Note: should only contain functionality that is generic enough to be used 
### in any component. If you have an output method that needs to be shared
### between components descended from different object types, put it into 
### EnsEMBL::Web::Component::Shared, which has been set up for this usage

use strict;

use base qw(EnsEMBL::Web::Root);

use Digest::MD5 qw(md5_hex);

use HTML::Entities  qw(encode_entities);
use Text::Wrap      qw(wrap);
use List::MoreUtils qw(uniq);

use EnsEMBL::Draw::DrawableContainer;
use EnsEMBL::Draw::VDrawableContainer;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Utils::FormatText qw(helptip glossary_helptip get_glossary_entry);
use EnsEMBL::Web::Document::Image::GD;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Document::TwoCol;
use EnsEMBL::Web::Object::ImageExport;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Form::ModalForm;

sub new {
  my ($class, $hub, $builder, $renderer, $key) = @_;

  my $id = [split /::/, $class]->[-1];

  my $self = {
    hub           => $hub,
    builder       => $builder,
    renderer      => $renderer,
    id            => $id,
    component_key => $key,
    object        => undef,
    cacheable     => 0,
    mcacheable    => 1,
    ajaxable      => 0,
    configurable  => 0,
    has_image     => 0,
    format        => undef,
    html_format   => undef,
  };
  
  bless $self, $class;

  if ($hub) {
    $self->{'viewconfig'}{$hub->type} = $hub->get_viewconfig({
      'component' => $id,
      'type'      => $self->viewconfig_type || $hub->type,
      'cache'     => 1
    });
    $hub->set_cookie("toggle_$_", 'open') for grep $_, $hub->param('expand');
  }
  
  $self->_init;
  
  return $self;
}

sub viewconfig_type { return undef; }

sub buttons {
  ## Returns a list of hashrefs, each containing info about the component context buttons (keys: url, caption, class, modal, toggle, disabled, group, nav_image)
}

sub button_style {
  ## Optional configuration of button style if using buttons method. Returns hashref.
  return {};
}

sub coltab {
  my ($self, $text, $colour, $title) = @_;

  return sprintf(qq(<div class="coltab"><span class="coltab-tab" style="background-color:%s;">&nbsp;</span><div class="coltab-text">%s</div></div>), $colour, helptip($text, $title));
}

sub param {
  my $self  = shift;
  my $hub   = $self->hub;

  my $hub_vc = delete $hub->{'viewconfig'}; # TMP - while viewconfig is 'cached' in hub's viewconfig key for the current component

  if (@_) {
    my @vals = $hub->param(@_);
    $hub->{'viewconfig'} = $hub_vc; # TMP - just putting it back
    return wantarray ? @vals : $vals[0] if @vals;

    if (my $view_config = $self->viewconfig) {
      if (@_ > 1) {
        my @caller = caller;
        #warn sprintf "DEPRECATED: To set view_config param, use view_config->set method at %s line %s.\n", $caller[1], $caller[2];
        $view_config->set(@_);
      }
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }

    return wantarray ? () : undef;

  } else {
    my @params = $hub->param;
    $hub->{'viewconfig'} = $hub_vc; # TMP - just putting it back

    my $view_config = $self->viewconfig;

    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates

    return keys %params;
  }
}

#################### ACCESSORS ###############################

sub component_key :AccessorMutator;
sub id            :AccessorMutator;
sub cacheable     :AccessorMutator;
sub mcacheable    :AccessorMutator; ## temporary method only (hr5)
sub ajaxable      :AccessorMutator;
sub configurable  :AccessorMutator;
sub has_image     :AccessorMutator;
sub builder       :Accessor;
sub hub           :Accessor;
sub renderer      :Accessor;

sub viewconfig {
  ## @getter
  ## @return EnsEMBL::Web::ViewConfig::[type]
  my ($self, $type) = @_;

  my $hub = $self->hub;

  $type ||= $hub->type;

  unless ($self->{'viewconfig'}{$type}) {
    $self->{'viewconfig'}{$type} = $hub->get_viewconfig({
      'component' => $self->id,
      'type'      => $type,
      'cache'     => $type eq $hub->type
    });
  }
  return $self->{'viewconfig'}{$type};
}

sub dom {
  ## @getter
  ## @return EnsEMBL::Web::DOM
  my $self = shift;
  unless ($self->{'dom'}) {
    $self->{'dom'} = EnsEMBL::Web::DOM->new;
  }
  return $self->{'dom'}; 
}

sub object {
  ## @accessor
  ## @param EnsEMBL::Web::Object subclass instance if setting
  ## @return EnsEMBL::Web::Object::[type]
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'} || $self->builder && $self->builder->object;
}

sub format {
  ## @accessor
  ## @return String (output file format)
  my $self = shift;
  ## TODO Shouldn't hub param override an already set value?
  $self->{'format'} ||= $self->hub->param('_format') || 'HTML';
  $self->{'html_format'} = 1 if $self->{'format'} eq 'HTML';
  return $self->{'format'};
}

sub html_format {
  ## @accessor
  ## @return Boolean
  my $self = shift;
  return $self->{'html_format'} ||= $self->format eq 'HTML';
}

########### END OF ACCESSORS ###################

sub make_twocol {
  my ($self, $order) = @_;

  my $data    = $self->get_data;
  my $twocol  = $self->new_twocol;

  foreach (@$order) {
    my $field = $data->{$_};
    next unless $field->{'content'};
    my $content = $field->{'raw'} == 1 ? $self->_wrap_content($field->{'content'}) : $field->{'content'};
    $twocol->add_row($field->{'label'}, $content);
  }

  return $twocol->render;
}

sub _wrap_content {
  my ($self, $content) = @_;
  return "<p><pre>$content</pre></p>";
}

sub get_content {
  my ($self, $function) = @_;
  my $cache = $self->mcacheable && $self->ajaxable && $self->renderer && !$self->renderer->{'_modal_dialog_'} ? $self->hub->cache : undef;
  my $content;
  
  if ($cache) {
    $self->set_cache_params;
    $content = $cache->get($ENV{'CACHE_KEY'});
  }

  if (!$content) {
    if($function && $self->can($function)) {
      $content = $self->$function;
      if ($function =~ /pan_compara/) {
        $content = $self->header.$self->content_buttons.$content;
      }
    } else {
      $content = $self->content; # Force sequence-point before buttons call.
      $content = $self->header.$self->content_buttons.$content;
    }
    if ($cache && $content && $self->mcacheable) { # content method call can change mcacheable value
      $self->set_cache_key;
      $cache->set($ENV{'CACHE_KEY'}, $content, 60*60*24*7, values %{$ENV{'CACHE_TAGS'}});
    }
  }
  
  return $content;
}

sub content_buttons {
  my $self = shift;

  my $style = $self->button_style;
  # Group the buttons, if requested
  my (@groups,@nav);
  foreach my $b ($self->buttons) {
    if($b->{'nav_image'}) {
      # "Variation style" pictoral nav buttons
      push @nav,$b;
    } else {
      # Blue rectangles
      if(!@groups or !$b->{'group'} or
            $groups[-1]->[0]{'group'} ne $b->{'group'}) {
        push @groups,[];
      }
      push @{$groups[-1]},$b;
    }
  }
  # Create the variation type buttons
  my $nav_html = '';
  foreach my $b (@nav) {
    $nav_html .= qq(
      <a href="$b->{'url'}" class="$b->{'nav_image'} _ht"
         title="$b->{'title'}" alt="$b->{'title'}">
        $b->{'caption'}
      </a>
    );
  }
  # Create the blue-rectangle buttons
  my $blue_html = '';  

  foreach my $g (@groups) {
    my $group = '';
    my $all_disabled = 1;
    foreach my $b (@$g) {
      my @classes = $b->{'class'} || ();
      push @classes, 'modal_link'   if $b->{'modal'};
      push @classes, 'disabled'     if $b->{'disabled'};
      push @classes, 'togglebutton' if $b->{'toggle'};
      push @classes, 'off'          if $b->{'toggle'} and $b->{'toggle'} eq 'off';
      $all_disabled = 0 unless $b->{'disabled'};
      if ($b->{'disabled'}) {
        $group .= sprintf('<div class="%s">%s</div>',
            join(' ',@classes), $b->{'caption'});
      }
      else {      
        $group .= sprintf('<a href="%s" class="%s" rel="%s">%s</a>',
            $b->{'url'}, join(' ',@classes),$b->{'rel'},$b->{'caption'});
      }
    }
    if(@$g>1) {
      my $class = "group";
      $class .= " disabled" if $all_disabled;
      $blue_html .= qq(<div class="$class">$group</div>);
    } else {
      $blue_html .= $group;
    }
  }
  return '' unless $blue_html or $nav_html;
  my $class = $style->{'class'} || '';
  $blue_html = qq(
    <div class="component-tools tool_buttons $class">$blue_html</div>
  ) if $blue_html;
  $nav_html = qq(
    <div class="component-navs nav_buttons $class">$nav_html</div>
  ) if $nav_html;

  return $nav_html.$blue_html;
}

sub set_cache_params {
  my $self        = shift;
  my $hub         = $self->hub;  
  my $view_config = $self->viewconfig;
  my $key;
  
  # FIXME: check cacheable flag
  if ($self->has_image) {
    my $width = sprintf 'IMAGE_WIDTH[%s]', $self->image_width;
    $ENV{'CACHE_TAGS'}{'image_width'} = $width;
    $ENV{'CACHE_KEY'} .= "::$width";
  }
  
  $hub->get_imageconfig($view_config->image_config_type) if $view_config && $view_config->image_config_type; # sets user_data cache tag
  
  $key = $self->set_cache_key;
  
  if (!$key) {
    $ENV{'CACHE_KEY'} =~ s/::(SESSION|USER)\[\w+\]//g;
    delete $ENV{'CACHE_TAGS'}{$_} for qw(session user);
  }
}

sub set_cache_key {
  my $self = shift;
  my $hub  = $self->hub;
  my $key  = join '::', map $ENV{'CACHE_TAGS'}{$_} || (), qw(view_config image_config user_data);
  my $page = sprintf '::PAGE[%s]', md5_hex(join '/', grep $_, $hub->action, $hub->function);
    
  if ($key) {
    $key = sprintf '::COMPONENT[%s]', md5_hex($key);
    
    if ($ENV{'CACHE_KEY'} =~ /::COMPONENT\[\w+\]/) {
      $ENV{'CACHE_KEY'} =~ s/::COMPONENT\[\w+\]/$key/;
    } else {
      $ENV{'CACHE_KEY'} .= $key;
    }
  }
  
  if ($ENV{'CACHE_KEY'} =~ /::PAGE\[\w+\]/) {
    $ENV{'CACHE_KEY'} =~ s/::PAGE\[\w+\]/$page/;
  } else {
    $ENV{'CACHE_KEY'} .= $page;
  }
  
  return $key;
}

sub html_encode {
  shift;
  return encode_entities(@_);
}

sub join_with_and {
  ## Joins an array of strings with commas and an 'and' before the last element
  ## ie. returns 'a, b, c and d' for qw(a b c d)
  ## @params List of strings to be joined
  shift;
  return join(' and ', reverse (pop @_, join(', ', @_) || ()));
}

sub join_with_or {
  ## Joins an array of strings with commas and an 'or' before the last element
  ## ie. returns 'a, b, c or d' for qw(a b c d)
  ## @params List of strings to be joined
  shift;
  return join(' or ', reverse (pop @_, join(', ', @_) || ()));
}

sub wrap_in_p_tag {
  ## Wraps an HTML string in <p> if allowed
  ## @param HTML (or text)
  ## @param Flag if on, will do an html encoding the text
  my ($self, $text, $do_encode) = @_;

  return sprintf '<p>%s</p>', encode_entities($text) if $do_encode;
  return $text if $text =~ /^[\s\t\n]*\<(p|div|table|form|pre|ul)(\s|\>)/;
  return "<p>$text</p>";
}

sub append_s_to_plural {
  ## Appends an 's' to the string in case the flag is on
  my ($self, $string, $flag) = @_;
  return $flag ? "${string}s" : $string;
}

sub error_panel {
  ## Returns html for a standard error box (with red header)
  ## @params Heading, error description, width of the box (defaults to image width)
  return shift->_info_panel('error', @_);
}

sub warning_panel {
  ## Returns html for a standard warning box
  ## @params Heading, warning description, width of the box (defaults to image width)
  return shift->_info_panel('warning', @_);
}

sub info_panel {
  ## Returns html for a standard info box (with grey header)
  ## @params Heading, description text, width of the box (defaults to image width)
  return shift->_info_panel('info', @_);
}

sub hint_panel {
  ## Returns html for a standard info box, but hideable with JS
  ## @params Heading, description text, width of the box (defaults to image width)
  my ($self, $id, $caption, $desc, $width) = @_;
  return if grep $_ eq $id, split /:/, $self->hub->get_cookie_value('ENSEMBL_HINTS');
  return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id);
}

sub sidebar_panel {
  ## Similar to an info panel, but smaller and floats right rather than filling the page
  ## @params Heading, description text, width of the box (defaults to 50%)
  my ($self, $caption, $desc, $width) = @_;
  $width ||= '50%';
  return $self->_info_panel('sidebar', $caption, $desc, $width);
}

sub site_name   { return $SiteDefs::SITE_NAME || $SiteDefs::ENSEMBL_SITETYPE; }
sub image_width { return shift->hub->image_width; }
sub caption     { return undef; }
sub header      { return undef; }
sub _init       { return; }

## TODO - remove these four method once above four methods are used instead of these
sub _error   { return shift->_info_panel('error',   @_);  } # Fatal error message. Couldn't perform action
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal
sub _info    { return shift->_info_panel('info',    @_ ); } # Extra information 
sub _hint    {                                              # Extra information, hideable
  my ($self, $id, $caption, $desc, $width) = @_;
  return if grep $_ eq $id, split /:/, $self->hub->get_cookie_value('ENSEMBL_HINTS');
  return $self->_info_panel('hint hint_flag', $caption, $desc, $width, $id);
} 

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
 
  return '' unless $self->html_format;

  if(ref($desc) eq 'ARRAY') {
    return '' unless @$desc;
    if(@$desc>1) {
      $desc = "<ul>".join("",map "<li>$_</li>",@$desc)."</ul>";
    } else {
      $desc = $desc->[0];
    }
  }
  if(ref($caption) eq 'ARRAY') {
    if(@$caption > 1) {
      my $last = pop @$caption;
      $caption = join(", ",uniq(@$caption))." and $last";
    } elsif(@$caption) {
      $caption = $caption->[0];
    } else {
      $caption = '';
    }
  }
  return sprintf(
    '<div%s style="width:%s" class="%s%s"><h3>%s</h3><div class="message-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $width ? ' fixed_width' : '',
    $caption || '&nbsp;', 
    $self->wrap_in_p_tag($desc)
  );
}

sub is_strain   { 
## TODO - remove this when all components call method on hub directly
  my $self = shift;
  return $self->hub->is_strain(shift);
}

sub config_msg {
  my $self = shift;
  my $url  = $self->hub->url({
    species   => $self->hub->species,
    type      => 'Config',
    action    => $self->hub->type,
    function  => 'ExternalData',
    config    => '_page'
 });
  
  return qq{<p>Click <a href="$url" class="modal_link">"Configure this page"</a> to change the sources of external annotations that are available in the External Data menu.</p>};
}

sub ajax_url {
  my $self        = shift;
  my $hub         = $self->hub;
  my $function    = shift;
     $function    = join "/", grep $_, $hub->function, $function && $self->can("content_$function") ? $function : '', $self->component_key;
  my $params      = shift || {};
  my $controller  = shift || 'Component';

  return $self->hub->url($controller, { function => $function, %$params }, undef, !$params->{'__clear'});
}

sub EC_URL {
  my ($self, $string) = @_;
  
  my $url_string = $string;
     $url_string =~ s/-/\?/g;
  
  return $self->hub->get_ExtURL_link("EC $string", 'EC_PATHWAY', $url_string);
}

sub modal_form {
  ## Creates a modal-friendly form for user interactions
  ## Params Name (Id attribute) for form
  ## Params Action attribute
  ## Params HashRef with keys as accepted by Web::Form::ModalForm constructor
  my ($self, $name, $action, $options) = @_;

  my $hub               = $self->hub;
  my $params            = {};
  $params->{'action'}   = $params->{'next'} = $action;
  $params->{'current'}  = $hub->action;
  $params->{'name'}     = $name;
  $params->{$_}         = $options->{$_} for qw(class method label no_button buttons_on_top buttons_align skip_validation enctype);
  $params->{'enctype'}  = 'multipart/form-data' if !$self->renderer->{'_modal_dialog_'} && ($params->{'method'} || '') =~ /post/i;

  return EnsEMBL::Web::Form::ModalForm->new($params);
}

sub new_image {
  my $self        = shift;
  my $hub         = $self->hub;
  my %formats     = EnsEMBL::Web::Constants::IMAGE_EXPORT_FORMATS;
  my $export      = $hub->param('export');
  my $id          = $self->id;
  my $config_type = $self->viewconfig ? $self->viewconfig->image_config_type : undef;
  my (@image_configs, $image_config);

  if (ref $_[0] eq 'ARRAY') {
    my %image_config_types;
    
    for (grep $_->isa('EnsEMBL::Web::ImageConfig'), @{$_[0]}) {
      $image_config_types{$_->{'type'}} = 1;
      push @image_configs, $_;
    }
    
    $image_config = $_[0][1];
  } else {
    @image_configs = ($_[1]);
    $image_config  = $_[1];
  }
  
  if ($export) {
    # Set text export on image config
    $image_config->set_parameter('text_export', $export) if $formats{$export}{'extn'} eq 'txt';
  }
  
  $_->set_parameter('component', $id) for grep $_->type eq $config_type, @image_configs;
 
  my $image = EnsEMBL::Web::Document::Image::GD->new($hub, $self, \@image_configs);
  $image->drawable_container = EnsEMBL::Draw::DrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my @image_config = $_[1];
  
  my $image = EnsEMBL::Web::Document::Image::GD->new($self->hub, $self, \@image_config);
  $image->drawable_container = EnsEMBL::Draw::VDrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_karyotype_image {
  my ($self, $image_config) = @_;  
  my $image = EnsEMBL::Web::Document::Image::GD->new($self->hub, $self, $image_config ? [ $image_config ] : undef);
  $image->{'object'} = $self->object;
  
  return $image;
}

sub new_table {
  my $self     = shift;
  my $hub      = $self->hub;
  my $table    = EnsEMBL::Web::Document::Table->new(@_);
  my $filename = $hub->filename($self->object);
  my $options  = $_[2];
  $self->{'_table_count'}++ if $options->{'exportable'};
  
  $table->hub($hub);
  $table->format     = $self->format;
  $table->filename   = join '-', $self->id, $filename;
  $table->code       = $self->id . '::' . ($options->{'id'} || $self->{'_table_count'});
  
  return $table;
}

sub new_twocol {
  ## Creates and returns a new EnsEMBL::Web::Document::TwoCol.
  shift;
  return EnsEMBL::Web::Document::TwoCol->new(@_);
}

sub new_form {
  ## Creates and returns a new Form object.
  ## @param   HashRef as accepted by Form->new with a variation in action key
  ##  - action: Can be a string as need by Form->new, or a hashref as accepted by hub->url
  ## @return  EnsEMBL::Web::Form object
  my ($self, $params) = @_;
  $params->{'dom'}    = $self->dom;
  $params->{'action'} = ref $params->{'action'} ? $self->hub->url($params->{'action'}) : $params->{'action'} if $params->{'action'};
  $params->{'format'} = $self->format;
  return EnsEMBL::Web::Form->new($params);
}

sub _export_image {
  my ($self, $image) = @_;
  my $hub = $self->hub;
  
  $image->{'export'} = 'iexport';

  my @export = split(/-/,$hub->param('export'));
  my $format = (shift @export)||'';
  my %params = @export;
  my $scale = abs($params{'s'}) || 1;
  my $contrast = abs($params{'c'}) || 1;

  my %formats = EnsEMBL::Web::Constants::IMAGE_EXPORT_FORMATS;
  
  if ($formats{$format}) {
    $image->drawable_container->{'config'}->set_parameter('sf',$scale);
    $image->drawable_container->{'config'}->set_parameter('contrast',$contrast);
    
    ## Note: write to disk, because download doesn't work with memcached
    if ($hub->type eq 'ImageExport') {
      ## User download
      my $file = $image->render($format, ['IO']);
      $hub->param('file', $file);
    }
    else {
      ## Output image by itself, e.g. for external services
      (my $comp = ref $self) =~ s/[^\w\.]+/_/g;
      my $filename = sprintf '%s_%s_%s.%s', $comp, $hub->filename($self->object), $scale, $formats{$format}{'extn'};
      ## Remove any hyphens, because they break the download
      $filename =~ s/[-]//g;
      $hub->param('filename', $filename);
      my $path = $image->render($format, ['IO']);
      $hub->param('file', $path);
      $hub->param('format', $format);
      EnsEMBL::Web::Object::ImageExport::handle_download($self);
    }

    return 1;
  }
  
  return 0;
}

sub toggleable_table {
  my ($self, $title, $id, $table, $open, $extra_html, $for_render) = @_;
  my @state = $open ? qw(show open) : qw(hide closed);
  
  $table->add_option('class', $state[0]);
  $table->add_option('toggleable', 1);
  $table->add_option('id', "${id}_table");
  
  return sprintf('
    <div class="toggleable_table" id="%s_anchor">
      %s
      <h2><a rel="%s_table" class="toggle _slide_toggle %s" href="#%s_table">%s</a></h2>
      %s
    </div>',
    $id, $extra_html, $id, $state[1], $id, $title, $table->render(@{$for_render||[]})
  ); 
}

sub ajax_add {
  my ($self, $url, $rel, $open) = @_;
  
  return sprintf('
    <a href="%s" class="ajax_add toggle _no_export %s" rel="%s_table">
      <span class="closed">Show</span><span class="open">Hide</span>
      <input type="hidden" class="url" value="%s" />
    </a>', $url, $open ? 'open' : 'closed', $rel, $url
  );
}

# Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
# data structures etc... 
# output looks like:
#
#  ###########################
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  # TEXT. TEXT. TEXT. TEXT. #
#  # TEXT. TEXT. TEXT. TEXT. #
#  #                         #
#  ###########################
sub _warn_block {
  my $self        = shift;
  my $width       = 128;
  my $border_char = '#';
  my $template    = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line        = $border_char x $width;
  
  warn "\n";
  warn "$line\n";
  
  $Text::Wrap::columns = $width-4;
  
  foreach my $l (@_) {
    my $lines = wrap('','', $l);
    
    warn sprintf $template;
    warn sprintf $template, $_ for split /\n/, $lines;
  }
  
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}

sub trim_large_string {
  my $self        = shift;
  my $string      = shift;
  my $cell_prefix = shift;
  my $truncator   = shift;
  my $options     = shift || {};
  
  unless(ref($truncator)) {
    my $len = $truncator || 25;
    $truncator = sub {
      local $_ = $self->strip_HTML(shift);
      return $_ if(length $_ < $len);      
      return substr($_,0,$len)."...";
    };
  }
  my $truncated = $truncator->($string);

  # Allow ... on wrapping summaries unless explicitly prohibited
  my @summary_classes = ('toggle_summary');
  push @summary_classes,'summary_trunc' unless($options->{'no-summary-trunc'});
  
  # Don't truncate very short strings
  my $short = $options->{'short'} || 5;
  $short = undef if($options->{'short'} == 0);
  $truncated = undef if(length($truncated)<$short);
  
  return $string unless defined $truncated;
  return sprintf(qq(
    <div class="height_wrap">
      <div class="toggle_div">
        <span class="%s">%s</span>
        <span class="cell_detail">%s</span>
      </div>
    </div>),
      join(" ",@summary_classes),$truncated,$string);  
}

sub view_config :Deprecated('Use viewconfig') { shift->viewconfig(@_) }

1;
