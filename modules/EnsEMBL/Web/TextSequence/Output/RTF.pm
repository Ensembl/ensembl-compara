package EnsEMBL::Web::TextSequence::Output::RTF;

use strict;
use warnings;

use base qw(EnsEMBL::Web::TextSequence::Output);

use HTML::Entities qw(decode_entities);

use EnsEMBL::Web::TextSequence::ClassToStyle::RTF;
use EnsEMBL::Web::TextSequence::Layout::RTF;

sub new {
  my $proto = shift;

  my $self = $proto->SUPER::new(@_);
  $self->c2s(EnsEMBL::Web::TextSequence::ClassToStyle::RTF->new);
  return $self;
}

sub _unhtml {
  my ($self,$data) = @_;

  $data =~ s/<.*?>//g;
  $data = decode_entities($data);
  return $data;
}

sub add_line {
  my ($self,$line,$markup,$config) = @_;

  my @letters;

  foreach my $m (@$markup) {
    my @classes = split(' ',$m->{'class'}||'');
    my $style = $self->c2s->convert_class_to_style(\@classes,$config);
    my $letter = $self->_unhtml($m->{'letter'})||' ';
    if($style =~ s/\0//g) { $letter = lc($letter); }
    push @letters,[$style||'',$letter];
  }

  push @{$self->{'data'}[$line->seq->id]},{
    line => \@letters,
    length => scalar @letters,
    pre => $self->_unhtml($line->pre),
    post => $self->_unhtml($line->post),
    adid => $line->line_num
  };
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
      if => 'number_left', 
      then => [
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'start', width => $config->{'padding'}{'number'} },
        { post => ' ' },
      ]   
    },  
    {   
      key => 'letters', width => $config->{'display_width'},
    },  
    {   
      if => 'number_right',
      then => [
        { post => ' ' },
        { key => 'h_space' },
        { key => 'label', width => $config->{'padding'}{'pre_number'} },
        { key => 'start', width => $config->{'padding'}{'number'} },
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
