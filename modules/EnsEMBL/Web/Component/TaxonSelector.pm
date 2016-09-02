=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::TaxonSelector;

# Base-class for taxon selector interface components

use strict;
use warnings;
no warnings 'uninitialized';
use base qw(EnsEMBL::Web::Component);
use HTML::Entities qw(encode_entities);

sub _init {
  my $self = shift;
  my $hub = $self->hub;
  
  $self->cacheable(0);
  $self->ajaxable(0);
  
  # these can be overridden in child
  $self->{panel_type}      = 'TaxonSelector'; 
  $self->{method}          = 'get'; # get|post
  $self->{action}          = undef; # url to send data to
  $self->{extra_params}    = {}; # additional params to send     
  $self->{redirect}        = $hub->url({ function => undef }, 0, 1); # url to redirect to                   
  
  $self->{link_text}       = 'Species selector';  
  $self->{finder_prompt}   = 'Start typing the name of a species or collection...';
  $self->{data_url}        = '/taxon_tree_data.js'; 
  $self->{selection_limit} = undef;
  $self->{is_blast}        = 0,
  $self->{tip_text}        = 'Click the + and - icons to navigate the tree, click the checkboxes to select/deselect a species or collection.
                              <br />Currently selected species are listed on the right.';
  $self->{entry_node}      = undef;     
                                     
}

sub content {
  my $self = shift;
  return '' unless $self->{link_text};
  
  my $hub = $self->hub;
  my $url = $self->ajax_url('ajax');
    
  return qq{<div class="other_tool"><p><a class="config modal_link" href="$url">$self->{link_text}</a></p></div>};
}

sub content_ajax {
  my $self = shift;
  my $hub = $self->hub;
  my @default_species = $hub->param('s');
  
  my %params = (
    dataUrl => $self->{data_url},
    isBlast => $self->{is_blast},
  );
  
  $params{defaultKeys}    = [@default_species]       if @default_species;
  $params{entryNode}      = $self->{entry_node}      if $self->{entry_node};
  $params{selectionLimit} = $self->{selection_limit} if $self->{selection_limit};
  $params{defaultsEleId}  = $self->{defaults_ele_id} if $self->{defaults_ele_id};
  
  return $self->jsonify({
    content   => $self->render_selector,
    panelType => $self->{panel_type},
    wrapper   => '<div class="panel panel_wide modal_wrapper taxon_selector"></div>',
    params    => \%params,
  });
}

sub render_selector {
  my $self         = shift;
  my $hub          = $self->hub;
  my $tip          = $self->render_tip;
  my $action       = $self->{action};
  my $method       = $self->{method};
  my $extra_params = $self->{extra_params} || {};
  
  $extra_params->{redirect} = $self->{redirect} if $self->{redirect};
  
  my $hidden_fields;
  foreach (keys %$extra_params) {
    $hidden_fields .= qq{<input type="hidden" name="$_" value="$extra_params->{$_}" />\n};
  }
  
  return qq{
    <div class="content">
      <form action="$action" method="$method" class="hidden">
        $hidden_fields
      </form>
      $tip
      <div class="taxon_selector_tree">
        <h2>Taxonomy tree</h2>
        <div class="finder">
          Find <input type="text" class="ui-autocomplete-input inactive" title="$self->{finder_prompt}" value="$self->{finder_prompt}" />
        </div>
        <div class="vscroll_container">
          <div class="loader"></div>
        </div>
      </div>
      <div class="taxon_selector_list">
        <h2>Selected species</h2>
        <div class="vscroll_container">
          <ul></ul>
        </div>
      </div>
    </div>
    <p class="invisible">.</p>
  };
}

sub render_tip {
  my $self = shift;
  
  my $tip_text = $self->{tip_text};
  if ($self->{selection_limit}) {
    $tip_text .= " You can select up to $self->{selection_limit} species.";
  }
  
  return qq{
    <div class="info">
      <h3>Tip</h3>
      <div class="error-pad">
        <p>
          $tip_text
        </p>
      </div>
    </div>
  };
}

1;
