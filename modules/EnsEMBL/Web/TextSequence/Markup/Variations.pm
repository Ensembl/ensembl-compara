package EnsEMBL::Web::TextSequence::Markup::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub markup {
  my ($self, $sequence, $markup, $config,$hub) = @_; 

  my $i   = 0;
  my ($seq, $variation);
  
  my $class = { 
    snp    => 'sn',
    insert => 'si',
    delete => 'sd'
  };  
  
  foreach my $data (@$markup) {
    $seq = $sequence->[$i]->legacy;
    
    foreach (sort { $a <=> $b } keys %{$data->{'variants'}}) {
      $variation = $data->{'variants'}{$_};
    
      $seq->[$_]{'letter'} = $variation->{'ambiguity'} if $variation->{'ambiguity'};
      $seq->[$_]{'new_letter'} = $variation->{'ambiguity'} if $variation->{'ambiguity'};
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $variation->{'alleles'} if ($config->{'title_display'}||'off') ne 'off';
      $seq->[$_]{'class'} ||= '';
      $seq->[$_]{'class'} .= ($class->{$variation->{'type'}} || $variation->{'type'}) . ' ';
      $seq->[$_]{'class'} .= 'bold ' if $variation->{'align'};
      $seq->[$_]{'class'} .= 'var '  if $variation->{'focus'};
      $seq->[$_]{'href'}   = $hub->url($variation->{'href'}) if $variation->{'href'};
      my $new_post  = join '', @{$variation->{'link_text'}} if $config->{'snp_display'} eq 'snp_link' && $variation->{'link_text'};
      $seq->[$_]{'new_post'} = $new_post if $new_post and $new_post ne $seq->[$_]{'post'};
      $seq->[$_]{'post'} = $new_post;
         
      $config->{'key'}{'variants'}{$variation->{'type'}} = 1 if $variation->{'type'} && !$variation->{'focus'};
    }   
       
    $i++;
  }
}

sub prepare {
  my ($self) = @_;

  $self->expect('variants');
}

1;
