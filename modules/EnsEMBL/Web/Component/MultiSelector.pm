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

package EnsEMBL::Web::Component::MultiSelector;

use strict;

use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(uniq);

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

sub _content_li {
  my ($self,$class,$content) = @_;
  return qq(
    <li class="$class">
      <span class="switch"></span>
      <span>$content</span>
    </li>);
}

sub content_ajax {
  my $self         = shift;
  my $hub          = $self->hub;
  my %all          = %{$self->{'all_options'}};       # Set in child content_ajax function - complete list of options in the form { URL param value => display label }
  my %included     = %{$self->{'included_options'}};  # Set in child content_ajax function - List of options currently set in URL in the form { url param value => order } where order is 1, 2, 3 etc.
  my @all_categories = @{$self->{'categories'}||[]};
  my $url          = $self->{'url'} || $hub->url({ function => undef, align => $hub->get_alignment_id }, 1);
  my $extra_inputs = join '', map sprintf('<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_})), sort keys %{$url->[1]};
  my $select_by    = join '', map sprintf('<option value="%s">%s</option>', @$_), @{$self->{'select_by'} || []};
     $select_by    = qq{<div class="select_by"><h2>Select by biotype:</h2><select>$select_by</select></div>} if $select_by;
  my ($exclude_html,$include_html);

  foreach my $category ((@all_categories,undef)) {
    # The data
    my ($include_list,$exclude_list,@all);
    @all = sort { ($included{$a} <=> $included{$b}) || ($all{$a} cmp $all{$b}) } keys %all;
    foreach my $key (@all) {
      if(defined $category) {
        my $my_category = ($self->{'category_map'}||{})->{$key};
        $my_category ||= $self->{'default_category'};
        if($my_category) {
          next unless $my_category eq $category;
        } else {
          next;
        }
      } else {
        next if $self->{'category_map'}{$key} || $self->{'default_category'};
      }

      my $fragment = $self->_content_li($key,$all{$key});
      if($included{$key}) {
        $include_list .= $fragment;
      } else {
        $exclude_list .= $fragment;
      }
    }

    # The heading
    my $include_title = $self->{'included_header'};
    my $exclude_title = $self->{'excluded_header'};
    my $category_heading = ($self->{'category_titles'}||{})->{$category} || $category;
    $category_heading = '' unless defined $category_heading;
    $exclude_title =~ s/\{category\}/$category_heading/g;
    $include_title =~ s/\{category\}/$category_heading/g;

    # Do it
    my $catdata = $category||'';
    next unless $exclude_list or $include_list or $category;
    $exclude_html .= qq(
      <div class="panel_title">
        <h2>$exclude_title <span class="count unselected" title="Total Unselected">0</span> </h2>
      </div>
      <ul class="excluded" data-category="$catdata">
        $exclude_list
      </ul>
    );
    $include_html .= qq(
      <div class="panel_title">
        <h2>$include_title <span class="count selected" title="Total Selected">0</span> </h2>
      </div>
      <ul class="included" data-category="$catdata">
        $include_list
      </ul>
    );
  }

  my $hint = qq{
    <div class="multi_selector_hint info">
      <h3>Tip</h3>
      <div class="error-pad">
        <p>Click on the plus and minus buttons to select or deselect options.
        Selected options can be reordered by dragging them to a different position in the list</p>
      </div>
    </div>
  };
 
  my $content      = sprintf('
    <div class="content">
      <div class="select_by_group_div">
        %s
        %s
      </div>
      <form action="%s" method="get" class="hidden">%s</form>
      <div class="multi_selector_list _unselected_species">
        %s
      </div>
      <div class="multi_selector_list _selected_species">
        %s
      </div>
      <p class="invisible">.</p>
    </div>',
    $select_by,
    $hint,
    $url->[0],
    $extra_inputs,
    $exclude_html,
    $include_html
  );
  
  my $param_mode = $self->{'param_mode'};
  $param_mode ||= 'multi';
 
  return $self->jsonify({
    content   => $content,
    panelType => $self->{'panel_type'},
    activeTab => $self->{'rel'},
    wrapper   => qq{<div class="modal_wrapper"><div class="panel"></div></div>},
    # nav       => "$select_by$hint",
    params    => { urlParam => $self->{'url_param'}, paramMode => $param_mode },
  });
}

1;
