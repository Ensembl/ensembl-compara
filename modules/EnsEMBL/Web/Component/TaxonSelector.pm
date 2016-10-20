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
  $self->{panel_type}     = 'TaxonSelector'; 
  $self->{method}         = 'get'; # get|post
  $self->{action}         = undef; # url to send data to
  $self->{extra_params}   = {}; # additional params to send     
  $self->{redirect}       = $hub->url({ function => undef }, 0, 1); # url to redirect to
  # $self->{form_action}    = $self->{'url'} || $hub->url({ function => undef, align => $hub->param('align') }, 1);
  $self->{form_action}    = $hub->referer->{uri};
  $self->{link_text}      = 'Species selector';
  $self->{finder_prompt}  = 'Start typing the name of a species...';
  $self->{data_url}       = $hub->url('Json', {
                              type => $hub->type eq 'Tools' ? 'Tools' : 'SpeciesSelector',
                              function => 'fetch_species',
                              action => $hub->param('referer_action'),
                              align => $hub->param('align') ? $hub->param('align') : ''
                            });
  $self->{caller}          = $self->{hub_action} = $hub->referer->{'ENSEMBL_ACTION'};
  $self->{multiselect}     = $self->param('multiselect');
  $self->{selection_limit} = undef;
  $self->{is_blast}        = 0,
  $self->{tip_text}        = 'Click the + and - icons to navigate the tree, click the checkboxes to select/deselect a species or collection.
                              <br />Currently selected species are listed on the right.';
  $self->{entry_node}      = undef;
}

sub content {
  return ""
}

sub content_ajax {
  my $self = shift;
  my $hub = $self->hub;
  my @default_species = $hub->param('s');
  my $urlParams = { map { ($_ => $hub->param($_)) } $hub->param };

  my %params = (
    dataUrl => $self->{data_url},
    isBlast => $self->{is_blast},
    caller  => $self->{caller},
    %$urlParams
  );


  $params{defaultKeys}    = [@default_species]       if @default_species;
  $params{entryNode}      = $self->{entry_node}      if $self->{entry_node};
  $params{selectionLimit} = $self->{selection_limit} if $self->{selection_limit};
  $params{defaultsEleId}  = $self->{defaults_ele_id} if $self->{defaults_ele_id};
  $params{multiselect}    = $self->{multiselect}     if $self->{multiselect};

  # Get default keys (default selected) for region comparison
  my $shown = [ map { $urlParams->{$_} } grep m/^s(\d+)/, keys %$urlParams ]; # get species (and parameters) already shown on the page
  push @{$params{defaultKeys}}, @$shown if scalar @$shown;

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
  # my $tip          = $self->render_tip;
  my $action       = $self->{action};
  my $method       = $self->{method};
  my $extra_params = $self->{extra_params} || {};
  # $extra_params->{redirect} = $self->{redirect} if $self->{redirect};

  my $hidden_fields;
  # foreach (keys %$extra_params) {
  #   $hidden_fields .= qq{<input type="hidden" name="$_" value="$extra_params->{$_}" />\n};
  # }
  
  my $is_cmp = ($self->{hub_action} eq 'Compara_Alignments')? 1 : 0;
  if ($is_cmp) {
    foreach (keys %{$hub->referer->{params}}) {
      if ($_ ne 'align') {
        $hidden_fields .= sprintf qq{<input type="hidden" name="%s" value="%s" />\n}, $_, $hub->referer->{params}->{$_}[0];
      }
    }    
    $action = $self->{form_action};
  }
  if ($self->{hub_action} eq 'Multi') {
    $action = $self->{form_action};
  }

  my $taxon_tree = sprintf qq {
    <div class="taxon_selector_tree %s">
      <div class="content">
        <h2> %s </h2>
        <div class="finder">
          <input type="text" autofocus class="ui-autocomplete-input inactive" title="$self->{finder_prompt}" placeholder="$self->{finder_prompt}" />
        </div>
        <ul class="ss_breadcrumbs"></ul>
        <div class="species_division_buttons"></div>
        <div class="vscroll_container">
        </div>
      </div>
    </div>
  }, 
  ($is_cmp) ? 'full-width' : '',
  ($is_cmp) ? 'Alignment Selector' : 'Species Selector';

  my $taxon_list = qq {
    <div class="taxon_selector_list">
      <div class="content">
        <h2>Selected species <span class="ss-count"></span></h2> 
        <div class="vscroll_container">
          <ul></ul>
        </div>
      </div>
    </div>    
  };

  return sprintf qq{
    <div class="content">
      <form action="$action" method="$method" class="hidden">
        $hidden_fields
      </form>
      <div class="taxon_tree_master hidden"></div>
      <div class="species_select_container">
      %s
      </div>
      <div class="ss-buttons">
        <button id="ss-reset" type="reset">Reset All</button>
        <button id="ss-cancel" type="cancel">Cancel</button>
        <button id="ss-submit" type="submit">Apply</button>
      </div>
      <div class="ss-msg"><span></span></div>
    </div>
  },
  ($self->{hub_action} eq 'Compara_Alignments') ? $taxon_tree : $taxon_tree . $taxon_list,
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
