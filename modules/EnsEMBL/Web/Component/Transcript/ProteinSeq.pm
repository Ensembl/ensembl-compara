package EnsEMBL::Web::Component::Transcript::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub get_sequence_data {
  my $self = shift;
  my ($translation, $config) = @_;
  
  my $peptide  = $translation->Obj;
  my $pep_seq  = $peptide->seq;
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
    my $object = $self->object;
    my $filter = $object->param('population_filter');
    my %population_filter;
    
    my $slice  = $translation->get_Slice;
    
    if ($filter && $filter ne 'off') {
      %population_filter = map { $_->dbID => $_ }
        @{$slice->get_all_VariationFeatures_by_Population(
          $object->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter), 
          $object->param('min_frequency')
        )};
    }
    
    foreach my $transcript_variation (@{$object->get_transcript_variations}) {
      my $pos = $transcript_variation->translation_start;
      
      next unless $pos;
      
      $pos--;
      
      my $var  = $transcript_variation->variation_feature->transfer($slice);
      my $dbID = $var->dbID;
      
      next if keys %population_filter && !$population_filter{$dbID};
      
      $markup->{'variations'}->{$pos}->{'type'}      = lc $var->display_consequence;
      $markup->{'variations'}->{$pos}->{'alleles'}   = $var->allele_string;
      $markup->{'variations'}->{$pos}->{'ambigcode'} = $var->ambig_code || '*';
      $markup->{'variations'}->{$pos}->{'href'} ||= {
        type        => 'Zmenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'v'}},  $var->variation_name;
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'vf'}}, $dbID;
    }
  }
  
  return (\@sequence, [ $markup ]);
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
  
  for (qw(exons variation number)) {
    $config->{$_} = $object->param($_) eq 'yes' ? 1 : 0;
  }

  my ($sequence, $markup) = $self->get_sequence_data($translation, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  my $html = sprintf('
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
    </div>',
    $translation->Obj->seq,
    $config->{'species'}
  );
  
  $html .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
  $html .= $self->build_sequence($sequence, $config);

  return $html;
}

1;
