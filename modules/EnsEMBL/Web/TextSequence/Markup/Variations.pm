package EnsEMBL::Web::TextSequence::Markup::Variations;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Markup);

sub pre_markup {
  my ($self, $sequence, $markup, $config,$hub) = @_;

  # XXX this is a hack: should be a proper method of writing each other's
  # ropes
  my ($variation_rope,$main_rope_idx,$protein_rope);
  my $var_rope_idx = -1;
  my $protein_rope_idx = -1;
  my $i = 0;
  foreach my $data (@$markup) {
    my $vr = $sequence->[$i]->relation('aux');
    $variation_rope = $vr if $vr;
    my $pr = $sequence->[$i]->relation('protein');
    $protein_rope = $pr if $pr;
    $main_rope_idx = $i if $vr;
    $i++;
  }
  $i = 0;
  foreach my $data (@$markup) {
    $var_rope_idx = $i if $variation_rope and $variation_rope == $sequence->[$i];
    $protein_rope_idx = $i if $protein_rope and $protein_rope == $sequence->[$i];
    $i++;
  }
  $i = 0;
  foreach my $data (@$markup) {
    my $seq = $sequence->[$i]->legacy;

    if($var_rope_idx!=-1 and $i==$main_rope_idx) {
      foreach (sort { $a <=> $b } keys %{$data->{'variants'}}) {
        if($data->{'variants'}{$_}{'vseq'}) {
          $markup->[$var_rope_idx]{'variants'}{$_} = {
            %{$markup->[$var_rope_idx]{'variants'}{$_}||{}},
            %{$data->{'variants'}{$_}{'vseq'}}
          };
          $sequence->[$var_rope_idx]->legacy->[$_] = $data->{'variants'}{$_}{'vseq'};
        }
      }
    }
    if($protein_rope_idx!=-1 and $i==$main_rope_idx) {
      foreach (sort { $a <=> $b } keys %{$data->{'variants'}}) {
        next unless $data->{'variants'}{$_}{'aachange'};
        $sequence->[$protein_rope_idx]->legacy->[$_]{'class'} = 'aa';
        $sequence->[$protein_rope_idx]->legacy->[$_]{'title'} .= "\n" if $markup->[$protein_rope_idx]{'title'};
        $sequence->[$protein_rope_idx]->legacy->[$_]{'title'} .= $data->{'variants'}{$_}{'aachange'};
      }
    }
    $i++;
  }
}

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

      if($variation->{'ambiguity'}) {
        my $ambiguity = $variation->{'ambiguity'};
        $ambiguity = 'N' if $config->{'variants_as_n'};
        $seq->[$_]{'letter'} = $ambiguity;
        $seq->[$_]{'new_letter'} = $ambiguity;
      }
      $seq->[$_]{'title'} .= ($seq->[$_]{'title'} ? "\n" : '') . $variation->{'alleles'} if ($config->{'title_display'}||'off') ne 'off';
      $seq->[$_]{'class'} ||= '';
      $seq->[$_]{'class'} .= ($class->{$variation->{'type'}||''} || $variation->{'type'} || '') . ' ';
      $seq->[$_]{'class'} .= 'bold ' if $variation->{'align'};
      $seq->[$_]{'class'} .= 'var '  if $variation->{'focus'};
      $seq->[$_]{'href'}   = $hub->url($variation->{'href'}) if $variation->{'href'};
      my $new_post;
      if($config->{'snp_display'} eq 'snp_link' && $variation->{'links'}) {
        $new_post = join(' ',map {
          sprintf(qq( <a href="%s">%s</a>),$hub->url($_->{'url'}),$_->{'label'})
        } @{$variation->{'links'}});
      }

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
