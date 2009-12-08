package EnsEMBL::Web::Document::Panel::Fragment;

use strict;
use warnings;

use URI::Escape qw(uri_escape uri_unescape);

use base qw(EnsEMBL::Web::Document::Panel);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self->{'html'} = undef;
  $self->{'asynchronous_components'} = [];
  return $self;
}

sub asynchronously_load {
  my ($self, @names) = @_;
  foreach my $name (@names) {
    push @{ $self->{'asynchronous_components'} }, $name;
  }
}

sub render {
  my $self = shift;
  my $html = "";
  $html .= $self->html_header;
  $html .= $self->placeholder;
  $html .= $self->html_footer;
  $self->renderer->print( $html );
}

sub html_header {
  my $self = shift;
  my $html = "<div class='panel'>\n";
  $html .= "<h2>";
  $html .= $self->html_collapse_expand_control;
  $html .= "<b id='" . $self->code . "_title'>";
  $html .= $self->caption;
  $html .= $self->html_loading_status;
  $html .= "</b>";
  $html .= "</h2>";
  return $html;
}

sub placeholder {
  my $self = shift;
  my $html = "";
  my $class = "fragment";
  my $config_options = {};
  if ($self->panel_is_closed) {
    $class = "";
  }
  if ($self->is_all_asynchronous) {
    $html .= "<div style='display: block;'>";
    $html .= "All asynchronous";
    $html .= "</div>";
  } else {
    $html .= "<div style='display: block;'>";
    my $width = $self->{'object'}->param('image_width');
    unless ($self->panel_is_closed) {
      foreach my $name (@{ $self->static_components }) {
        my $command = $self->{components}{$name}->[0];
        (my $class = $command ) =~s/::[^:]+$//;
        $self->dynamic_use($class); 
        no strict 'refs';
        my $result = &$command($self, $self->{'object'});
        use strict 'refs';
	if ($result) {
	  foreach my $key (keys %{ $result->{'config'} }) {
	     if ($result->{'config'}->{$key}) {
	       $config_options->{$key} = $result->{'config'}->{$key};
	     }
	  }
	}
        $html .= uri_unescape($self->html);
      }
      $html .= "</div>";
      $html .= "<div id='" . $self->code . "_update' style='width: " . $width . "px; text-align: center; margin: 0 auto;'>";
      $html .= "<div style='background: #efefef; border-top: 1px solid #666; padding: 10px;'>";
      $html .= "Loading...";
      $html .= "</div>\n";
    }
    $html .= "</div>\n";
  }
  $html .= "<div class='$class' style='display: none;' id='" . $self->code . "_json'>";
  $html .= $self->json($config_options);
  $html .= "</div>\n";
  return $html;
}

sub is_all_asynchronous {
  my $self = shift;
  my $found = 1;
  foreach my $key (@{ $self->{component_order} }) {
    if ($self->is_asynchronous($key)) {
      $found = 0;
    }
  }
  return $found;
}

sub static_components {
  my $self = shift;
  my @components = (); 

  foreach my $key (@{ $self->{component_order} }) {
    unless ($self->is_asynchronous($key)) {
      push @components, $key;
    }
  }

  return \@components;
}

sub is_asynchronous {
  my ($self, $name) = @_;
  my $found = 0;
  foreach my $component (@{ $self->{'asynchronous_components'} }) {
    if ($name eq $component) {
      $found = 1;
    } 
  }
  return $found;
}


sub panel_is_closed {
  my $self = shift;
  my $status = $self->{'object'} ? $self->{'object'}->param($self->{'status'}) : undef;
  my $open = $status ne 'off' ? 'off' : 'on';
  if ($open eq 'on') {
    return 1;
  }
  return 0;
}

sub json {
  my ($self, $config_options) = @_; 
  my $json = sprintf( "{ fragment: { code: '%s', species: '%s', title: '%s', id: '%s', params: [ %s ], components: [ %s ], options: [ %s ], config_options: [ %s ] }}",
    $self->code, $ENV{'ENSEMBL_SPECIES'}, $self->caption, $self->code,
    $self->json_params, $self->json_components, $self->json_options($self->{'_options'}), $self->json_options($config_options)
  );
  return $json;
}

sub html {
  my ($self, $value) = @_;
  if ($value) {
    $self->{'html'} = $value;
  }
  return $self->{'html'}; 
}

sub add_html {
  my ($self, $value) = @_;
  $self->html($self->html . $value);
}

sub print {
  my ($self, $render) = @_;
  $render = $self->escape($render);
  $self->html($render);
}

sub escape_quotes {
  my ($self, $string) = @_;
  $string =~ s/'/&quote;/g;
  return $string;
}

sub json_params {
  my $self = shift;
  my $json = "";
  foreach my $key ( %{ $self->params }) {
    if ($self->params->{$key}) {
      $json .= "{ $key: '" . $self->params->{$key} . "' }, ";
    }
  }
  return $json;
}

sub json_components {
  my $self = shift;
  my $json = "";
  foreach my $key (@{ $self->{component_order} }) {
    if ($self->is_asynchronous($key)) {
      $json .= "{ $key: '" . $self->{components}{$key}->[0] . "' }, ";
    }
  }
  return $json;
}

sub json_options {
  my ($self, $options) = @_;
  my $json = "";
  foreach my $key ( keys %{ $options } ) {
    if (!ref($options->{$key}) && $options->{$key}) {
      $json .= "{ $key: '" . $options->{ $key } . "' }, ";
    }
  }
  return $json;
}

sub html_loading_status {
  my $self = shift;
  my $html = "";
  if ($self->status) {
    #$html .= " (" . $self->status . ")";
    $html .= $self->loading_animation; 
  }
  return $html;
}

sub loading_animation {
  my $self = shift;
  my $html = "";
  if (!$self->panel_is_closed) {
    $html .= sprintf ' <img src="/img/ajax-loader.gif" width="16" height="16" alt="(%s)" />', $self->status;
  }
  return $html;
}

sub html_collapse_expand_control {
  my $self = shift;
  my $status = $self->{'object'} ? $self->{'object'}->param($self->{'status'}) : undef;
  my $URL = sprintf '/%s/%s?%s=%s', $self->{'object'}->species, $self->{'object'}->script, $self->{'status'}, $status ne 'off' ? 'off' : 'on';
  foreach my $K (keys %{$self->{'params'}||{}} ) {
    $URL .= sprintf ';%s=%s', uri_escape( $K ), uri_escape( $self->{'params'}{$K} );
  }

  my $html = "";
  if ($status eq 'off') {
    $html .= qq(<a class="print_hide" href=") . $URL . qq(" title="expand panel"><img src="/img/dd_menus/plus-box.gif" width="16" height="16" alt="+" /></a> );
  } else {
    $html .= qq(<a class="print_hide" href=") . $URL . qq(" title="collapse panel"><img src="/img/dd_menus/min-box.gif" width="16" height="16" alt="-" /></a> );
  }
  return $html;
}

sub html_footer {
  my $self = shift;
  my $html = "</div>\n";
  return $html;
}

1;
