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

package EnsEMBL::Web::Document::Element::Content;

use strict;

use EnsEMBL::Web::Document::Panel;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    panels => [],
    form   => ''
  });
}

sub first         :lvalue { $_[0]->{'first'};         }
sub form          :lvalue { $_[0]->{'form'};          }
sub filter_module :lvalue { $_[0]->{'filter_module'}; }
sub filter_code   :lvalue { $_[0]->{'filter_code'};   }

sub add_panel_first { $_[1]->renderer = $_[0]->renderer; unshift @{$_[0]{'panels'}}, $_[1]; }
sub add_panel       { $_[1]->renderer = $_[0]->renderer; push    @{$_[0]{'panels'}}, $_[1]; }

sub add_panel_after {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    $counter++;
    last if $_->{'code'} eq $code;
  }
  
  splice @{$self->{'panels'}}, $counter, 0, $panel;
}

sub add_panel_before {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  
  splice @{$self->{'panels'}}, $counter, 0, $panel;
}

sub replace_panel {
  my ($self, $panel, $code) = @_;
  
  $panel->renderer = $self->renderer;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    last if $_->{'code'} eq $code;
    $counter++;
  }
  
  splice @{$self->{'panels'}}, $counter, 1, $panel;
}

sub remove_panel {
  my ($self, $code) = @_;
  
  my $counter = 0;
  
  foreach (@{$self->{'panels'}}) {
    if ($_->{'code'} eq $code) {
      splice @{$self->{'panels'}}, $counter, 1;
      return;
    }
    
    $counter++;
  }
}

# Lists the codes for each panel in this page content
sub panels {
  my $self = shift;
  return map $_->{'code'}, @{$self->{'panels'} || []};
}

sub panel {
  my ($self, $code) = @_;
  
  foreach (@{$self->{'panels'}}) {
    return $_ if $code eq $_->{'code'};
  }
  
  return undef;
}

sub content {
  my $self = shift;
  
  my $content = $self->{'form'} || '';
  
  # Include any access warning at top of page
  if ($self->filter_module) {
    my $class = 'EnsEMBL::Web::Filter::' . $self->filter_module;
    my $html;
    
    if ($class && $self->dynamic_use($class)) {
      my $filter = $class->new({hub => $self->hub});
      
      $html .= '<div class="panel print_hide">';
      $html .= sprintf '<div class="error filter-error"><h3>Error</h3><div class="error-pad"><p>%s</p></div></div>', $filter->error_message($self->filter_code);
      $html .= '</div>';
      
      $content .= $html;
    }
  }

  foreach my $panel (@{$self->{'panels'}}) {
    $content .= $panel->content;
  }
  $content .= '</form>' if $self->{'form'};
  
  return $content;
}

sub get_json {
  my $self = shift;
  my ($filter, $content);
  
  # Include any access warning at top of page
  if ($self->filter_module) {
    my $class = 'EnsEMBL::Web::Filter::' . $self->filter_module;
    
    if ($class && $self->dynamic_use($class)) {
      $filter   = $class->new({hub => $self->hub});
      $content .= sprintf "<div class='error filter-error print_hide'><h3>Error</h3><div class='error-pad'><p>%s</p></div></div>", $filter->error_message($self->filter_code);
    }
  }
  
  $content .= sprintf '<div class="content">%s</div>', $_->component_content for @{$self->{'panels'}};
  $content  = "$self->{'form'}$content</form>" if $self->{'form'};
  $content  = qq{<div class="panel">$content</div>} if @{$self->{'panels'}} == 1;
  
  return {
    wrapper   => '<div class="modal_wrapper"></div>',
    content   => $content,
    panelType => $content =~ /[^a-z]+panel_type/ ? '' : 'ModalContent'
  };
}

sub init {
  my $self       = shift;
  my $controller = shift;

  if ($controller->request eq 'ssi') {
    my $page = $controller->page;
    my $html = $controller->content =~ /<body.*?>(.*?)<\/body>/sm ? $1 : $controller->content;
    my $id   = $controller->isa('EnsEMBL::Web::Controller::Doxygen') ? 'doxygen' : 'static';
    my ($panel_content, $hr);
    
    if ($page->include_navigation) {
      $panel_content .= qq{<div id="content"><div id="$id">$html</div></div>};
    } elsif ($ENV{'SCRIPT_NAME'} eq '/blog.html') {
      $panel_content = $html;
    } else {
      $panel_content = qq{\n<div id="$id">$html</div>};
    }
    
    $self->add_panel(EnsEMBL::Web::Document::Panel->new(raw => $panel_content, hub => $self->hub));
  } else {
    my $input  = $self->{'input'};
    my $hub    = $controller->hub;
    my $errors = $controller->errors;
    
    if ($hub->has_a_problem || scalar @$errors) {
      my $page = $controller->page;
      $page->{'format'} = 'HTML';
      $page->set_doc_type('HTML', '4.01 Trans');
      $self->add_error_panels([ map @$_, values %{$hub->problem} ]);
      $self->add_panel_first($_) for reverse @$errors;
      
      return if $hub->has_fatal_problem;
    }
    
    $self->filter_module = $input ? $input->param('filter_module') : undef;
    $self->filter_code   = $input ? $input->param('filter_code')   : undef;
    
    if ($controller->page_type eq 'Component') {
      $self->ajax_content($controller);
    } else {
      $self->content_panel($controller);
    }
  }
}

sub content_panel {
  my $self       = shift;
  my $controller = shift;
  my $node       = $controller->node;
  
  return unless $node;
  
  my $hub           = $controller->hub;
  my $object        = $controller->object;
  my $configuration = $controller->configuration;
  
  $self->{'availability'} = $object ? $object->availability : {};
  
  my %params = (
    object      => $object,
    code        => 'main',
    caption     => $node->data->{'full_caption'} || $node->data->{'concise'} || $node->data->{'caption'},
    omit_header => $controller->page_type eq 'Popup' ? 1 : 0,
    help        => { $hub->species_defs->multiX('ENSEMBL_HELP') }->{join '/', map $hub->$_ || (), qw(type action function)},
  );
  
  my $panel          = $self->new_panel('Navigation', $controller, %params);
  my @all_components = @{$node->data->{'components'}};
  my @components     = qw(__urgent_messages EnsEMBL::Web::Component::Messages::Urgent);
  
  for (my $i = 0; $i < $#all_components; $i += 2) {
    push @components, $all_components[$i], $all_components[$i + 1] unless $all_components[$i] eq 'summary';
  }
 
  push @components, qw(__other_messages EnsEMBL::Web::Component::Messages::Other);
 
  $panel->add_components(@components);
  $self->add_panel($panel);
}

sub ajax_content {
  my $self       = shift;
  my $controller = shift;
  my $panel      = $self->new_panel('Ajax', $controller, code => 'ajax_panel');
 
  $panel->add_component($controller->component_code, $controller->component);
  
  $controller->r->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
  $self->add_panel($panel);
}

sub add_error_panels { 
  my ($self, $problems) = @_;
  
  my $view         = uc $self->hub->script;
  my $ini_examples = $self->species_defs->SEARCH_LINKS;
  my @example      = map { /^$view(\d)_TEXT/ ? qq{ <a href="$ini_examples->{"$view${1}_URL"}">$ini_examples->{$_}</a>} : () } keys %$ini_examples; # Find an example for the page
  my $example_html = join ', ', @example;
  $example_html    = '<p>Try an example: $example_html or use the search box.</p>' if $example_html;
  
  foreach my $problem (sort { $a->isFatal <=> $b->isFatal } grep !$_->isRedirect, @$problems) {
    my $desc = $problem->description;
    # This class will stop any further ajax panel calls
    my $fatalClass = $problem->isFatal ? 'fatal' : '';
    $desc    = "<p>$desc</p>" unless $desc =~ /<p/;

    my $caption = $problem->name;
    $self->add_panel_first(
      EnsEMBL::Web::Document::Panel->new(
        hub     => $self->hub,
        content => qq{
          <div class="error left-margin right-margin $fatalClass">
            <h3>$caption</h3>
            <div class="error-pad">
              <p>$desc</p>
              $example_html
              <p>If you think this is an error, or you have any questions, please <a href="/Help/Contact" class="popup">contact our HelpDesk team</a>.</p>
            </div>
          </div>
        }
      )
    );
  }
}

1;
