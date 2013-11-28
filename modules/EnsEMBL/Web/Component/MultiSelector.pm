=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# $Id$

package EnsEMBL::Web::Component::MultiSelector;

use strict;

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
  
  return sprintf(
    '<div class="other_tool"><p><a class="config modal_link%s" href="%s"%s>%s</a></p></div>',
    $self->hub->param("$self->{'url_param'}1") ? '' : ' pulse',
    $self->ajax_url('ajax'),
    $self->{'rel'} ? qq( rel="$self->{'rel'}") : '',
    $self->{'link_text'}
  );
}

sub content_ajax {
  my $self         = shift;
  my $hub          = $self->hub;
  my %all          = %{$self->{'all_options'}};       # Set in child content_ajax function - complete list of options in the form { URL param value => display label }
  my %included     = %{$self->{'included_options'}};  # Set in child content_ajax function - List of options currently set in URL in the form { url param value => order } where order is 1, 2, 3 etc.
  my $url          = $self->{'url'} || $hub->url({ function => undef, align => $hub->param('align') }, 1);
  my $extra_inputs = join '', map sprintf('<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_})), sort keys %{$url->[1]};
  my $include_list = join '', map sprintf('<li class="%s"><span class="switch"></span><span>%s</span></li>', $_, $all{$_}), sort { $included{$a} <=> $included{$b} } keys %included;
  my $exclude_list = join '', map sprintf('<li class="%s"><span class="switch"></span><span>%s</span></li>', $_, $all{$_}), sort { $all{$a} cmp $all{$b} } grep !$included{$_}, keys %all;
  my $select_by    = join '', map sprintf('<option value="%s">%s</option>', @$_), @{$self->{'select_by'} || []};
     $select_by    = qq{<div class="select_by"><h2>Select by type:</h2><select><option value="">----------------------------------------</option>$select_by</select></div>} if $select_by;
  my $content      = sprintf('
    <div class="content">
      <form action="%s" method="get" class="hidden">%s</form>
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
    <div class="multi_selector_hint info">
      <h3>Tip</h3>
      <div class="error-pad">
        <p>Click on the plus and minus buttons to select or deselect options.</p>
        <p>Selected options can be reordered by dragging them to a different position in the list</p>
      </div>
    </div>
  };
  
  return $self->jsonify({
    content   => $content,
    panelType => $self->{'panel_type'},
    activeTab => $self->{'rel'},
    wrapper   => qq{<div class="modal_wrapper"><div class="panel"></div></div>},
    nav       => "$select_by$hint",
    params    => { urlParam => $self->{'url_param'} },
  });
}

1;
