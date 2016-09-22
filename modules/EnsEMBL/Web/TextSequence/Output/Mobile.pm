=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Output::Mobile;

use strict;
use warnings;

use base qw(EnsEMBL::Web::TextSequence::Output::Web);

use JSON qw(to_json);
use List::Util qw(max);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Utils::RandomString qw(random_string);

use EnsEMBL::Web::TextSequence::Output::Web::Adorn;

sub make_layout {
  my ($self,$config) = @_;

  my $layout = EnsEMBL::Web::TextSequence::Layout::String->new([
    { key => 'pre' },
    {
      if => 'number',
      then => [
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'},
          room => 1 },
        { key => 'start', width => max($config->{'padding'}{'number'}||0,6) },
        { post => ' ' },
      ]
    },
    { 
      key => ['adid','seqclass','letters'], width => {
        letters => -$config->{'display_width'}
      },
      fmt => '<span class="adorn adorn-%s %s">%s</span>',
    },
    {
      if => 'number',
      then => [
        { post => ' ' },
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'end', width => max($config->{'padding'}{'number'}||0,6) },
      ]
    },
    { key => ['adid','post'], fmt => '<span class="ad-post-%s">%s</span>' },
    { post => "\n" },
    { if => 'vskip', then => [ { post => "\n" }] },
  ]);
  $layout->filter(sub { $_[1]->{'seqclass'} = "_seq" if $_[1]->{'principal'}; return $_[1]; });
  return $layout;
}

sub add_line {
  my ($self,$line,$markup,$config) = @_;

  my %c2s_cache; # Multi-second speed improvement from this cache
  my $letters = "";
  $self->{'adorn'}->linelen($self->view->width);
  $self->{'adorn'}->domain([qw(style title href tag letter)]);
  foreach my $m (@$markup) {
    $letters .= ($m->{'letter'}||' ');
    my $style = $c2s_cache{$m->{'class'}||''};
    unless(defined $style) {
      my @classes = split(' ',$m->{'class'}||'');
      $style = $self->c2s->convert_class_to_style(\@classes,$config);
      $c2s_cache{$m->{'class'}||''} = $style;
    }
    my $tag = $m->{'tag'}||'';
    $tag = 'span' if $tag eq 'a';
    $self->{'adorn'}->line->adorn($line->line_num,{
      'style' => ($style||''),
      'title' => ($m->{'title'}||''),
      'tag' => $tag,
      'letter' => ($m->{'new_letter'}||'')
    });
  }
  $self->{'adorn'}->line_done($line->line_num);

  $line->seq->output->add_line({
    line => $letters,
    length => length $letters,
    principal => $line->principal,
    pre => $line->pre,
    post => $line->post,
    adid => $line->line_num
  });

  $self->{'adorn'}->flourish('post',$line->line_num,$line->post) if $line->post;
}

1;
