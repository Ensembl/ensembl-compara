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

package EnsEMBL::Draw::GlyphSet::_user_data;

### Module for drawing user-uploaded data that has been saved in a
### *_userdata database

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::DBSQL::DBConnection;

use base qw(EnsEMBL::Draw::GlyphSet::_alignment EnsEMBL::Draw::GlyphSet_wiggle_and_block);

sub feature_group { my ($self, $f) = @_; return $f->display_id; }
sub feature_label { my ($self, $f) = @_; return $f->hseqname;   }

sub wiggle_subtitle { return $_[0]->my_config('description'); }

sub draw_features {
  my ($self, $wiggle) = @_;
  my %data = $self->features;
  
  return 0 unless keys %data;
  
  if ($wiggle) {
    foreach my $key ($self->sort_features_by_priority(%data)) {
      my ($features, $config)     = @{$data{$key}};
      my $graph_type              = ($config->{'useScore'} && $config->{'useScore'} == 4) || ($config->{'graphType'} && $config->{'graphType'} eq 'points') ? 'points' : 'bar';
      my ($min_score, $max_score) = split ':', $config->{'viewLimits'};
      
      $min_score = $config->{'min_score'} unless $min_score;
      $max_score = $config->{'max_score'} unless $max_score;
      
      $self->draw_wiggle_plot($features, {
        min_score    => $min_score,
        max_score    => $max_score,
        score_colour => $config->{'color'},
        axis_colour  => 'black',
        graph_type   => $graph_type,
      });
    }
  }
  
  return 1;
}

sub features {
  my $self = shift;
  
  return unless $self->my_config('data_type') eq 'DnaAlignFeature';
  
  my $sub_type   = $self->my_config('sub_type');
  my $logic_name = $self->my_config('logic_name');
  my $dbs        = EnsEMBL::Web::DBSQL::DBConnection->new($self->species);
  my $dba        = $dbs->get_DBAdaptor('userdata');
  
  $self->{'_default_colour'} = $self->SUPER::my_colour($sub_type);
  
  return ($logic_name => [[]]) unless $dba;

  my $dafa          = $dba->get_adaptor('DnaAlignFeature');
  my $features      = $dafa->fetch_all_by_Slice($self->{'container'}, $logic_name);
  my $slice_adaptor = $dbs->get_DBAdaptor('core')->get_adaptor('Slice');
  
  ## Replace feature slice with one from core db, as it may be out of date
  $_->slice($slice_adaptor->fetch_by_seq_region_id($_->slice->get_seq_region_id)) for @$features;
  
  return ($logic_name => [ $features || [], $self->my_config('style') ]);
}

sub feature_title {
  my ($self, $f, $db_name) = @_;
  my @strand_name = qw(- Forward Reverse);
  my $title       = sprintf(
    '%s: %s; Start: %d; End: %d; Strand: %s',
    $self->my_config('caption'),
    $f->display_id,
    $f->seq_region_start,
    $f->seq_region_end,
    $strand_name[$f->seq_region_strand]
  );

  $title .= '; Hit start: '  . $f->hstart  if $f->hstart;
  $title .= '; Hit end: '    . $f->hend    if $f->hend;
  $title .= '; Hit strand: ' . $f->hstrand if $f->hstrand;
  $title .= '; Score: '      . $f->score   if $f->score;
  
  my %extra = $f->extra_data && ref $f->extra_data eq 'HASH' ? %{$f->extra_data} : ();
  
  foreach my $k (sort keys %extra) {
    next if $k eq '_type';
    next if $k eq 'item_colour';
    $title .= "; $k: " . join ', ', @{$extra{$k}};
  }
  
  return $title;
}

sub href {
  ### Links to /Location/Genome
  my ($self, $f) = @_;
  my $href = $self->my_config('style')->{'url'};
     $href =~ s/\$\$/$f->id/e;
  return $href;
}

sub colour_key {
  my ($self, $k) = @_;
  return $k;
}

sub my_colour {
  my ($self, $k, $v) = @_;
  my $c = $self->my_config('style')->{'color'} || $self->{'_default_colour'};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix($c, 'white', 0) : $c;
}

1;
