=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::CloudMultiSelector;

use strict;

use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(uniq);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;

  $self->{'panel_type'}      = 'CloudMultiSelector';
  $self->{'url_param'}  = ''; # This MUST be implemented in the child _init function - it is the name of the parameter you want for the URL, eg if you want to add parameters s1, s2, s3..., $self->{'url_param'} = 's'
}

sub _content_li {
  my ($self,$key,$content,$on,$partial) = @_;

  my $class;
  $class .= "off" unless $on;
  $class .= "partial" if $partial;
  $class .= "heading" if $on>1;
  return qq(
    <li class="$class" data-key="$key">$content</li>);
}

sub _sort_values {
  my ($self,$values) = @_;

  my $sort_func = $self->{'sort_func'};
  $sort_func = sub { [ sort {lc $a cmp lc $b} @{$_[0]} ]; } unless $sort_func;
  return $sort_func->($values);
}

sub content_ajax {
  my $self         = shift;
  my $hub          = $self->hub;
  my %all          = %{$self->{'all_options'}};       # Set in child content_ajax function - complete list of options in the form { URL param value => display label }
  my %included     = %{$self->{'included_options'}};  # Set in child content_ajax function - List of options currently set in URL in the form { url param value => order } where order is 1, 2, 3 etc.
  my %partial      = %{$self->{'partial_options'}||{}};
  my @all_categories = @{$self->{'categories'}||[]};

  my $url          = $self->{'url'} || $hub->url({ function => undef, align => $hub->param('align') }, 1);
  my $extra_inputs = join '', map sprintf('<input type="hidden" name="%s" value="%s" />', encode_entities($_), encode_entities($url->[1]{$_})), sort keys %{$url->[1]};
  my $select_by    = join '', map sprintf('<option value="%s">%s</option>', @$_), @{$self->{'select_by'} || []};
     $select_by    = qq{<div class="select_by"><h2>Select by type:</h2><select><option value="">----------------------------------------</option>$select_by</select></div>} if $select_by;
  my @display;
  foreach my $category ((@all_categories,undef)) {
    # The data
    my %items;
    foreach my $key (keys %all) {
      if(defined $category) {
        my $my_category = ($self->{'category_map'}||{})->{$key};
        $my_category ||= $self->{'default_category'};
        if($my_category) {
          next unless $my_category eq $category; # in a cat, is it ours?
        } else {
          next; # in a cat, we don't have one
        }
      } else {
        # not in a cat
        next if ($self->{'category_map'}||{})->{$key} || $self->{'default_category'};
      }
      my $cluster = ($self->{'cluster_map'}||{})->{$key} || '';
      push @{$items{$cluster}||=[]},$key;
    }
    push @display,{
      category => $category,
      clusters => \%items
    };
  }
  my $include_html;
  foreach my $d (@display) {
    my $include_list;

    foreach my $cluster (sort { $a cmp $b } keys %{$d->{'clusters'}}) {
      my $cluster_list;
      my $heading = '';
      if($cluster) {
        $heading .= "<h4>$cluster:</h4>";
      }
      foreach my $key (@{$self->_sort_values($d->{'clusters'}{$cluster})}) {
        $cluster_list .=
          $self->_content_li($key,$all{$key},!!$included{$key},!!$partial{$key});
      }
      $include_list .= qq(<div>$heading<ul class="included">$cluster_list</ul></div>);
    }

    # The heading
    my $include_title = $self->{'included_header'};
    my $category_heading = ($self->{'category_titles'}||{})->{$d->{'category'}} || $d->{'category'};
    $category_heading = '' unless defined $category_heading;
    $include_title =~ s/\{category\}/$category_heading/g;

    # Do it
    next unless $include_list or $d->{'category'};
    $include_html .= qq(<h2>$include_title</h2>$include_list);
  }

  my $content      = sprintf('
    <div class="content">
      <form action="%s" method="get" class="hidden">%s</form>
      <div class="cloud_filter">
        <input type="text" name="cloud_filter" id="cloud_filter" tabindex="0" class="ftext" placeholder="type to filter options..."/>
        <a href="#" class="cloud_filter_clear">clear filter</a>
        <div class="cloud_all_none">
          <span class="all">ALL ON</span>
          <span class="none">ALL OFF</span>
        </div>
      </div>
      <div class="cloud_multi_selector_list">
        %s
      </div>
      <p class="invisible">.</p>
    </div>',
    $url->[0],
    $extra_inputs,
    $include_html,
  );
 
  my $partial = '';
  if(%partial) {
    $partial = qq(<div><span class="partial">PARTIAL</span></div>);
  } 
  my $hint = qq(
    <div class="cloud_flip_hint">
      <div class="cloud_flip_hint_wrap">
        <div class="info">
          <h3>tip</h3>
          <div class="error_pad">
            <div>
              <h1>click to flip</h1>
              <span class="on">ON</span>
              <span class="flip_icon"></span>
              <span class="off">OFF</span>
            </div>
            $partial
          </div>
        </div>
      </div>
    </div>
  );
 
  my $param_mode = $self->{'param_mode'};
  $param_mode ||= 'multi';
 
  return $self->jsonify({
    content   => $content,
    panelType => $self->{'panel_type'},
    activeTab => $self->{'rel'},
    wrapper   => qq{<div class="modal_wrapper"><div class="panel"></div></div>},
    nav       => "$select_by$hint",
    params    => { urlParam => $self->{'url_param'}, paramMode => $param_mode, %{$self->{'extra_params'}||{}} },
  });
}

1;
