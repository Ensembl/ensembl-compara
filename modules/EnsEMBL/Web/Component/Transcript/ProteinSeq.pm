package EnsEMBL::Web::Component::Transcript::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub get_sequence_data {
  my $self = shift;
  my ($translation, $config) = @_;
  
  my $peptide = $translation->Obj;
  my $pep_seq = $peptide->seq;

  my @sequence = [ map {{ letter => $_ }} split //, uc $pep_seq ];
  my $markup;
  
  $config->{'slices'} = [{ slice => $pep_seq }];
  $config->{'length'} = length $pep_seq;
  
  if ($config->{'exons'}) {
    my $exons = $translation->pep_splice_site($peptide);
    my $flip  = 0;
    
    foreach (sort {$a <=> $b} keys %$exons) {
      last if $_ >= $config->{'length'};
      
      if ($exons->{$_}->{'exon'}) {
        $flip = 1 - $flip;
        push @{$markup->{'exons'}->{$_}->{'type'}}, "exon$flip";
      } elsif ($exons->{$_}->{'overlap'}) {
        push @{$markup->{'exons'}->{$_}->{'type'}}, 'exon2';
      }
    }
    
    $markup->{'exons'}->{0}->{'type'} = [ 'exon0' ];
  }
  
  if ($config->{'variation'}) {
    my $variations = $translation->pep_snps('hash');
    
    foreach (sort { $a <=> $b } keys %$variations) {
      last if $_ >= $config->{'length'};
      next unless $variations->{$_}->{'type'}; # Weed out the rubbish returned by pep_snps
      
      $markup->{'variations'}->{$_}->{'type'}      = $variations->{$_}->{'type'};
      $markup->{'variations'}->{$_}->{'alleles'}   = $variations->{$_}->{'allele'};
      $markup->{'variations'}->{$_}->{'ambigcode'} = $variations->{$_}->{'ambigcode'};
      $markup->{'variations'}->{$_}->{'pep_snp'}   = $variations->{$_}->{'pep_snp'};
      $markup->{'variations'}->{$_}->{'nt'}        = $variations->{$_}->{'nt'};
    }
  }
  
  return (\@sequence,  [ $markup ]);
}

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $translation = $object->translation_object;
  
  return $self->non_coding_error unless $translation;
  
  my $config = { 
    display_width   => $object->param('display_width') || 60,
    species         => $object->species,
    maintain_colour => 1
  };
  
  for ('exons', 'variation', 'number') {
    $config->{$_} = ($object->param($_) eq 'yes') ? 1 : 0;
  }

  my ($sequence, $markup) = $self->get_sequence_data($translation, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  my $html = sprintf('
    <div class="text_seq_buttons">
      <div class="other-tool">
        <p><a class="seq_blast find" href="#">BLAST this sequence</a></p>
        <form class="external hidden seq_blast" action="/Multi/blastview" method="post">
          <fieldset>
            <input type="hidden" name="_query_sequence" value="%s" />
            <input type="hidden" name="query" value="peptide" />
            <input type="hidden" name="database" value="peptide" />
            <input type="hidden" name="species" value="%s" />
          </fieldset>
        </form>
      </div>
    </div>',
    $translation->Obj->seq,
    $config->{'species'}
  );
  
  $html .= $self->build_sequence($sequence, $config);
  $html .= '<img src="/i/help/protview_key1.gif" alt="[Key]" border="0" />' if $config->{'exons'} || $config->{'variation'};

  return $html;
}

1;
