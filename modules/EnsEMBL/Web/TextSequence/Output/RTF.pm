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

package EnsEMBL::Web::TextSequence::Output::RTF;

use strict;
use warnings;

use base qw(EnsEMBL::Web::TextSequence::Output);

use HTML::Entities qw(decode_entities);

use EnsEMBL::Web::TextSequence::ClassToStyle::RTF;
use EnsEMBL::Web::TextSequence::Layout::RTF;

sub make_c2s {
  return EnsEMBL::Web::TextSequence::ClassToStyle::RTF->new($_[0]->view);
}

sub _unhtml {
  my ($self,$data) = @_;

  $data ||= '';
  $data =~ s/<.*?>//g;
  $data = decode_entities($data);
  return $data;
}

sub add_line {
  my ($self,$line,$markup,$config) = @_;

  my @letters;

  foreach my $m (@$markup) {
    my @classes = split(' ',$m->{'class'}||'');
    my $style = $self->c2s->convert_class_to_style(\@classes,$config) || '';
    my $letter = $self->_unhtml($m->{'letter'})||' ';
    if($style =~ s/\0//g) { $letter = lc($letter); }
    push @letters,[$style,$letter];
  }

  $line->seq->output->add_line({
    line => \@letters,
    length => scalar @letters,
    pre => $self->_unhtml($line->pre),
    post => $self->_unhtml($line->post),
    adid => $line->line_num
  });
}

sub format_letters {
  my ($self,$letters,$config) = @_;

  return [] unless $letters;
  my $n = $config->{'display_width'};
  $n -= @$letters;
  if($n>0) {
    push @$letters,['',' ' x $n];
  }
  return $letters;
}

sub make_layout {
  my ($self,$config) = @_; 

  return EnsEMBL::Web::TextSequence::Layout::RTF->new([
    { control => '{\pard\fs18\f0' },
    { key => 'pre' },
    {   
      if => 'number',
      then => [
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'},
          room => 1 },
        { key => 'start', width => $config->{'padding'}{'number'} },
        { post => ' ' },
      ]   
    },  
    {   
      key => 'letters', width => $config->{'display_width'},
    },  
    {   
      if => 'number',
      then => [
        { post => ' ' },
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'end', width => $config->{'padding'}{'number'} },
      ]   
    },  
    { control => '\par}' },
    { if => 'vskip', then => [ { control => '{\pard\fs18\f0\par}' }] },
  ]); 
}

sub make_post_layout {
  my ($self,$config,$layout) = @_; 

  return EnsEMBL::Web::TextSequence::Layout::RTF->new([
    { if => 'post', then => [
      { control => '{\pard\fs18\f0' },
      { key => 'post' },
      { control => '\par}' },
    ]}
  ],$layout); 
}

sub build_output {
  my ($self,$config,$line_numbers,$multi,$id) = @_;

  my $layout = $self->make_layout($config);
  $self->format_lines($layout,$config,$line_numbers,$multi);
  $layout->value->control('{\pard\fs18\f0 \par}');
  $layout = $self->make_post_layout($config,$layout);
  return $self->format_lines($layout,$config,$line_numbers,$multi);
}

1;
