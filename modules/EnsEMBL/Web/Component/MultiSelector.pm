package EnsEMBL::Web::Component::MultiSelector;

use strict;
use warnings;
no warnings 'uninitialized';

use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  
  my $object = $self->object;
  my $url    = $self->ajax_url('ajax') . ';no_wrap=1';
  
  return sprintf('
    <div class="autocenter navbar" style="width:%spx; text-align: left; clear: both">
      <a class="modal_link" href="%s">%s</a>
    </div>',
    $self->image_width,
    $url,
    $self->{'link_text'}
  );
}

sub content_ajax {
  my $self = shift;
  my $object = $self->object;
  
  my %all      = %{$self->{'all_options'}};
  my %included = %{$self->{'included_options'}};
  use Data::Dumper;
  warn Dumper \%all;
  warn "\n\n";
  warn Dumper \%included;
  my $params = $object->multi_params;  
  my $url = $object->_url({ function => undef, align => $object->param('align') }, 1);
  my ($include_list, $exclude_list, $extra_inputs);
  
  $extra_inputs .= sprintf '<input type="hidden" name="%s" value="%s" />', escapeHTML($_), escapeHTML($url->[1]{$_}) for sort keys %{$url->[1]};
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
    $self->{'included_header'},
    $include_list,
    $self->{'excluded_header'},
    $exclude_list,
  );
  
  $content =~ s/\n//g;
  
  return qq{{'content':'$content','panelType':'MultiSelector','wrapper':'<div class="panel modal_wrapper"></div>','nav':''}};
}

1;
