package EnsEMBL::Web::Component::MultiSelector;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  
  $self->cacheable(0);
  $self->ajaxable(0);
  
  $self->{'panel_type'} = 'MultiSelector'; # Default value - can be overridden in child _init function. Determines javascript Ensembl.panel type
  $self->{'url_param'}  = ''; # This MUST be implemented in the child _init function - it is the name of the parameter you want for the URL, eg if you want to add parameters s1, s2, s3..., $self->{'url_param'} = 's'
}

sub content {
  my $self = shift;
  my $url  = $self->ajax_url('ajax');
  
  return qq{<div class="other-tool"><p><a class="config modal_link" href="$url">$self->{'link_text'}</a></p></div>};
}

sub content_ajax {
  my $self     = shift;
  my $hub      = $self->hub;
  my %all      = %{$self->{'all_options'}};       # Set in child content_ajax function - complete list of options in the form { URL param value => display label }
  my %included = %{$self->{'included_options'}};  # Set in child content_ajax function - List of options currently set in URL in the form { url param value => order } where order is 1, 2, 3 etc.
  my $url      = $self->{'url'} || $hub->url({ function => undef, align => $hub->param('align') }, 1);
  my ($include_list, $exclude_list, $extra_inputs);
  
  $extra_inputs .= sprintf '<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_}) for sort keys %{$url->[1]};
  $include_list .= sprintf '<li class="%s"><span>%s</span><span class="switch"></span></li>', $_, $all{$_} for sort { $included{$a} <=> $included{$b} } keys %included;
  $exclude_list .= sprintf '<li class="%s"><span>%s</span><span class="switch"></span></li>', $_, $all{$_} for sort { $all{$a} cmp $all{$b} } grep !$included{$_}, keys %all;
  
  my $content = sprintf('
    <div class="content">
      <form action="%s" method="get">%s</form>
      <div class="multi_selector_list">
        <h2>%s</h2>
        <ul class="included">
          %s
        </ul>
      </div>
      <div class="multi_selector_list">
        <h2>%s</h2>
        <ul class="excluded">
          %s
        </ul>
      </div>
      <p class="invisible">.</p>
    </div>',
    $url->[0],
    $extra_inputs,
    $self->{'included_header'}, # Set in child _init function
    $include_list,
    $self->{'excluded_header'}, # Set in child _init function
    $exclude_list,
  );
  
  my $hint = qq{
    <div class="multi_selector_hint">
      <h4>Tip</h4>
      <p>Click on the plus and minus buttons to select or deselect options.</p>
      <p>Selected options can be reordered by dragging them to a different position in the list</p>
    </div>
  };
  
  
  return $self->jsonify({
    content   => qq{<div class="panel modal_wrapper">$content</div>},
    panelType => $self->{'panel_type'},
    nav       => $hint,
    params    => { urlParam => $self->{'url_param'} }
  });
}

1;
