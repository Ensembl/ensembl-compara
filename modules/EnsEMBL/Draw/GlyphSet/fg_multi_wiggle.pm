=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::fg_multi_wiggle;

### Draws peak and/or wiggle tracks for regulatory build data
### e.g. histone modifications

use strict;

use parent qw(EnsEMBL::Draw::GlyphSet::bigwig);

sub init {
  my $self = shift;

  ## Preload data
  my $config      = $self->{'config'};
  my $cell_line   = $self->my_config('cell_line');
  $self->{'data'} = $self->data_by_cell_line($config)->{$cell_line};
  use Data::Dumper; warn ">>> DATA ".Dumper($self->{'data'});

  $self->SUPER::init(@_);
}

sub data_by_cell_line {
### Lazy evaluation
  my ($self,$config) = @_;

  my $data = $config->{'data_by_cell_line'};
  $data = $data->() if ref($data) eq 'CODE';
  $config->{'data_by_cell_line'} = $data;
  return $data||{};
}

sub draw_aggregate {
  my $self = shift;
  warn "!!! DRAWING FG MULTIWIGGLE AGGREGATE";

  ## Draw the track(s)
  my $set = $self->my_config('set');

  my $args = {
              'label'     => $display_label, 
              'colours'   => $colours, 
              'is_multi'  => !!$cell_line eq 'MultiCell',
              'strand'    => -1,
              };

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    my $any_on = scalar keys %{$dataset}{'on'}};
    if ($self->dynamic_use($style_class)) {
      my $subset;
      if ($_ =~ /Feature/) {
        if ($data->{$set}{'block_features'}) {
          ## Only add the extra zmenu stuff if we're not drawing a wiggle
          $subset = $self->get_blocks($data->{$set}, $args);
        }
        else {
          self->display_error_message($cell_line, $set, 'peaks') if $any_on;
        }
      }
      else {
        if ($data->{$set}{'wiggle_features'}) {
          $subset = $self->get_wiggle($data->{$set}, $args);
        }
        else {
          self->display_error_message($cell_line, $set, 'wiggle') if $any_on;
        }
      }
      my $style = $style_class->new(\%config, $subset);
      $self->push($style->create_glyphs);
    }
  }

=pod
  ## Add extra zmenu in label column
  my $hub = $self->{'config'}->hub;
  my $cell_type_url = $hub->url('Component', {
    action   => 'Web',
    function    => 'CellTypeSelector/ajax',
    image_config => $self->{'config'}->type,
  });
  my $evidence_url = $hub->url('Component', {
    action => 'Web',
    function => 'EvidenceSelector/ajax',
    image_config => $self->{'config'}->type,
  });
  my @zmenu_links = (
    {
      text => 'Select other cell types',
      href => $cell_type_url,
      class => 'modal_link',
    },{
      text => 'Select evidence to show',
      href => $evidence_url,
      class => 'modal_link',
    },
  );

  my $zmenu_extra_content = [ map {
      qq(<a href="$_->{'href'}" class="$_->{'class'}">$_->{'text'}</a>)
  } @zmenu_links ];

  $self->_add_sublegend(undef, "More","Links", $zmenu_extra_content, $self->_offset+2);
=cut

  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  return 0;
}

sub get_blocks {
  my ($self, $dataset, $args) = @_;

  my $tracks_on = $dataset->{'on'} 
                    ? sprintf '%s/%s features turned on', map scalar keys %{$dataset->{$_} || {}}, qw(on available) 
                    : '';

  my $strand = $args->{'strand'};
  my $data = {'metadata' => {},
              'features' => {$strand => []},
              };

  foreach my $f_set (sort { $a cmp $b } keys %$dataset) {
    my @temp          = split /:/, $f_set;
    pop @temp;
    my $feature_name  = pop @temp;
    my $cell_line     = join(':',@temp);
    my $colour        = $args>{'colours'}{$feature_name};
    my $features      = $dataset->{$f_set};

    my $label = $feature_name;
    $label = "$feature_name $cell_line" if $is_multi;


    my $length     = $self->{'container'}->length;

    foreach my $f (@$features) {
      my $hash = {
                  start   => $f->start,
                  end     => $f->end,
                  colour  => $colour,
                  label   => $label,
                  };
      push @{$data->{'features'}{$strand}}, $hash; 
  }

  return $data;
}

sub get_wiggle {
  my ($self, $dataset) = @_;

}

sub _add_sublegend {

}

## Custom render methods

sub render_compact {
  my $self = shift;
  warn ">>> RENDERING PEAKS";
  $self->{'my_config'}->set('drawing_style', ['Feature::Peaks']);
  $self->{'my_config'}->set('height', 8);
  $self->_render_aggregate;
}

sub render_signal {
  my $self = shift;
  warn ">>> RENDERING SIGNAL";
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub render_signal_feature {
  my $self = shift;
  warn ">>> RENDERING PEAKS WITH SIGNAL";
  $self->{'my_config'}->set('drawing_style', ['Feature::Peaks', 'Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}


1;
