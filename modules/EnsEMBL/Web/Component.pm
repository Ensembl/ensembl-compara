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

package EnsEMBL::Web::Component;

### Parent module for page components that output HTML content
###
### Note: should only contain functionality that is generic enough to be used 
### in any component. If you have an output method that needs to be shared
### between components descended from different object types, put it into 
### EnsEMBL::Web::Component::Shared, which has been set up for this usage

use strict;

use base qw(EnsEMBL::Web::Root Exporter);

use Digest::MD5 qw(md5_hex);

our @EXPORT_OK = qw(cache cache_print);
our @EXPORT    = @EXPORT_OK;

use HTML::Entities  qw(encode_entities);
use Text::Wrap      qw(wrap);
use List::MoreUtils qw(uniq);

use EnsEMBL::Draw::DrawableContainer;
use EnsEMBL::Draw::VDrawableContainer;

use EnsEMBL::Web::Document::Image::GD;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Document::TwoCol;
use EnsEMBL::Web::Constants;
use EnsEMBL::Web::DOM;
use EnsEMBL::Web::Form;
use EnsEMBL::Web::Form::ModalForm;
use EnsEMBL::Web::RegObj;

sub new {
  my $class = shift;
  my $hub   = shift;
  my $id    = [split /::/, $class]->[-1];
  
  my $self = {
    hub           => $hub,
    builder       => shift,
    renderer      => shift,
    id            => $id,
    object        => undef,
    cacheable     => 0,
    mcacheable    => 1,
    ajaxable      => 0,
    configurable  => 0,
    has_image     => 0,
    format        => undef,
    html_format   => undef,
  };
  
  if ($hub) { 
    $self->{'view_config'} = $hub->get_viewconfig($id, $hub->type, 'cache');
    $hub->set_cookie("toggle_$_", 'open') for grep $_, $hub->param('expand');
  }
  
  bless $self, $class;
  
  $self->_init;
  
  return $self;
}

sub buttons {
  ## Returns a list of hashrefs, each containing info about the component context buttons (keys: url, caption, class, modal, toggle, disabled, group, nav_image)
}

sub button_style {
  ## Optional configuration of button style if using buttons method. Returns hashref.
  return {};
}

#################### ACCESSORS ###############################

sub id {
  ## @accessor
  ## @return String (last element of package namespace)
  my ($self, $id) = @_;
  $self->{'id'} = $id if @_>1;
  return $self->{'id'};
}

sub builder {
  ## @getter
  ## @return EnsEMBL::Web::Builder
  my $self = shift;
  return $self->{'builder'};
}

sub hub {
  ## @getter
  ## @return EnsEMBL::Web::Hub
  my $self = shift;
  return $self->{'hub'};
}

sub renderer {
  ## @getter
  ## @return EnsEMBL::Web::Renderer
  my $self = shift;
  return $self->{'renderer'};
}

sub view_config { 
  ## @getter
  ## @return EnsEMBL::Web::ViewConfig::[type]
  my ($self, $type) = @_;
  unless ($self->{'view_config'}) {
    $self->{'view_config'} = $self->hub->get_viewconfig($self->id, $type);
  }
  return $self->{'view_config'};
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
  ## Included for backwards compatibility
  ## @return EnsEMBL::Web::Object::[type]
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->builder ? $self->builder->object : $self->{'object'};
}

sub cacheable {
  ## @accessor
  ## @return Boolean
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub mcacheable {
  ## temporary method only - will be replaced in 77 (hr5) - use cacheable method instead
  ## @accessor
  ## @return Boolean
  my $self = shift;
  $self->{'mcacheable'} = shift if @_;
  return $self->{'mcacheable'};
}

sub ajaxable {
  ## @accessor
  ## @return Boolean
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  ## @accessor
  ## @return Boolean
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub has_image {
  ## @accessor
  ## @return Boolean
  my $self = shift;
  $self->{'has_image'} = shift if @_;
  return $self->{'has_image'};
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
  my $cache = $self->mcacheable && $self->ajaxable && !$self->renderer->{'_modal_dialog_'} ? $self->hub->cache : undef;
  my $content;
  
  if ($cache) {
    $self->set_cache_params;
    $content = $cache->get($ENV{'CACHE_KEY'});
  }

  if (!$content) {
    if($function && $self->can($function)) {
      $content = $self->$function;
    } else {
      $content = $self->content; # Force sequence-point before buttons call.
      $content = $self->content_buttons.$content;
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
  my $view_config = $self->view_config;
  my $key;
  
  # FIXME: check cacheable flag
  if ($self->has_image) {
    my $width = sprintf 'IMAGE_WIDTH[%s]', $self->image_width;
    $ENV{'CACHE_TAGS'}{'image_width'} = $width;
    $ENV{'CACHE_KEY'} .= "::$width";
  }
  
  $hub->get_imageconfig($view_config->image_config) if $view_config && $view_config->image_config; # sets user_data cache tag
  
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


sub cache_print {
  my ($cache, $string_ref) = @_;
  $cache->print($$string_ref) if $string_ref;
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

sub helptip {
  ## Returns a dotted underlined element with given text and hover helptip
  ## @param Display html
  ## @param Tip html
  my ($self, $display_html, $tip_html) = @_;
  return $tip_html ? sprintf('<span class="ht _ht"><span class="_ht_tip hidden">%s</span>%s</span>', encode_entities($tip_html), $display_html) : $display_html;
}

sub glossary_helptip {
  ## Creates a dotted underlined element that has a mouseover glossary helptip (helptip text fetched from glossary table of help db)
  ## @param Display html
  ## @param Entry to match the glossary key to fetch help tip html (if not provided, use the display html as glossary key)
  my ($self, $display_html, $entry) = @_;

  $entry  ||= $display_html;
  $entry    = $self->get_glossary_entry($entry);

  return $self->helptip($display_html, $entry);
}

sub get_glossary_entry {
  ## Gets glossary value for a given entry
  ## @param Entry key to lookup against the glossary
  ## @return Glossary description (possibly HTML)
  my ($self, $entry) = @_;

  return $self->hub->glossary_lookup->{$entry} // '';
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

sub site_name   { return $SiteDefs::SITE_NAME || $SiteDefs::ENSEMBL_SITETYPE; }
sub image_width { return shift->hub->param('image_width') || $ENV{'ENSEMBL_IMAGE_WIDTH'}; }
sub caption     { return undef; }
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
  my $self     = shift;
  my $function = shift;
  my $params   = shift || {};
  my (undef, $plugin, undef, $type, @module) = split '::', ref $self;

  my $module   = sprintf '%s%s', join('__', @module), $function && $self->can("content_$function") ? "/$function" : '';

  return $self->hub->url('Component', { type => $type, action => $plugin, function => $module, %$params }, undef, !$params->{'__clear'});
}

sub EC_URL {
  my ($self, $string) = @_;
  
  my $url_string = $string;
     $url_string =~ s/-/\?/g;
  
  return $self->hub->get_ExtURL_link("EC $string", 'EC_PATHWAY', $url_string);
}

sub modal_form {
  ## Creates a modal-friendly form with hidden elements to automatically pass to handle wizard buttons
  ## Params Name (Id attribute) for form
  ## Params Action attribute
  ## Params HashRef with keys as accepted by Web::Form::ModalForm constructor
  my ($self, $name, $action, $options) = @_;

  my $hub               = $self->hub;
  my $params            = {};
  $params->{'action'}   = $params->{'next'} = $action;
  $params->{'current'}  = $hub->action;
  $params->{'name'}     = $name;
  $params->{$_}         = $options->{$_} for qw(class method wizard label no_back_button no_button buttons_on_top buttons_align skip_validation enctype);
  $params->{'enctype'}  = 'multipart/form-data' if !$self->renderer->{'_modal_dialog_'};

  if ($options->{'wizard'}) {
    my $species = $hub->type eq 'UserData' ? $hub->data_species : $hub->species;
    
    $params->{'action'}  = $hub->species_path($species) if $species;
    $params->{'action'} .= sprintf '/%s/Wizard', $hub->type;
    my @tracks = $hub->param('_backtrack');
    $params->{'backtrack'} = \@tracks if scalar @tracks; 
  }

  return EnsEMBL::Web::Form::ModalForm->new($params);
}

sub new_image {
  my $self        = shift;
  my $hub         = $self->hub;
  my %formats     = EnsEMBL::Web::Constants::EXPORT_FORMATS;
  my $export      = $hub->param('export');
  my $id          = $self->id;
  my $config_type = $self->view_config ? $self->view_config->image_config : undef;
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
  
  $_->set_parameter('component', $id) for grep $_->{'type'} eq $config_type, @image_configs;
 
  my $image = EnsEMBL::Web::Document::Image::GD->new($hub, $self->id, \@image_configs);
  $image->drawable_container = EnsEMBL::Draw::DrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_vimage {
  my $self  = shift;
  my @image_config = $_[1];
  
  my $image = EnsEMBL::Web::Document::Image::GD->new($self->hub, $self->id, \@image_config);
  $image->drawable_container = EnsEMBL::Draw::VDrawableContainer->new(@_) if $self->html_format;
  
  return $image;
}

sub new_karyotype_image {
  my ($self, $image_config) = @_;  
  my $image = EnsEMBL::Web::Document::Image::GD->new($self->hub, $self->id, $image_config ? [ $image_config ] : undef);
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
  
  $table->session    = $hub->session;
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
  my ($self, $image, $flag) = @_;
  my $hub = $self->hub;
  
  $image->{'export'} = 'iexport' . ($flag ? " $flag" : '');

  my ($format, $scale) = $hub->param('export') ? split /-/, $hub->param('export'), 2 : ('', 1);
  $scale eq 1 if $scale <= 0;
  
  my %formats = EnsEMBL::Web::Constants::EXPORT_FORMATS;
  
  if ($formats{$format}) {
    $image->drawable_container->{'config'}->set_parameter('sf',$scale);
    (my $comp = ref $self) =~ s/[^\w\.]+/_/g;
    my $filename = sprintf '%s-%s-%s.%s', $comp, $hub->filename($self->object), $scale, $formats{$format}{'extn'};
    
    if ($hub->param('download')) {
      $hub->input->header(-type => $formats{$format}{'mime'}, -attachment => $filename);
    } else {
      $hub->input->header(-type => $formats{$format}{'mime'}, -inline => $filename);
    }

    if ($formats{$format}{'extn'} eq 'txt') {
      print $image->drawable_container->{'export'};
      return 1;
    }

    $image->render($format);
    return 1;
  }
  
  return 0;
}

sub toggleable_table {
  my ($self, $title, $id, $table, $open, $extra_html) = @_;
  my @state = $open ? qw(show open) : qw(hide closed);
  
  $table->add_option('class', $state[0]);
  $table->add_option('toggleable', 1);
  $table->add_option('id', "${id}_table");
  
  return sprintf('
    <div class="toggleable_table">
      %s
      <h2><a rel="%s_table" class="toggle _slide_toggle %s" href="#%s_table">%s</a></h2>
      %s
    </div>',
    $extra_html, $id, $state[1], $id, $title, $table->render
  ); 
}

sub ajax_add {
  my ($self, $url, $rel, $open) = @_;
  
  return sprintf('
    <a href="%s" class="ajax_add toggle %s" rel="%s_table">
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
        <span class="toggle_img"/>
      </div>
    </div>),
      join(" ",@summary_classes),$truncated,$string);  
}

1;
