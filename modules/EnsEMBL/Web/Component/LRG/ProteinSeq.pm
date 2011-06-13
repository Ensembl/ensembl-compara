package EnsEMBL::Web::Component::LRG::ProteinSeq;

use strict;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub get_sequence_data {
  my ($self, $translation, $transcript, $config) = @_;
  my $object   = $transcript;
  my $pep_seq  = $translation->Obj->seq;
  my @sequence = [ map {{ letter => $_ }} split //, uc $pep_seq ];
  my $markup;
  
  $config->{'slices'} = [{ slice => $pep_seq }];
  $config->{'length'} = length $pep_seq;
  
  if ($config->{'exons'}) {
    my $exons = $object->peptide_splice_sites;
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
    my $hub    = $self->hub;
    my $filter = $hub->param('population_filter');
    my $slice  = $translation->get_Slice;
    my %population_filter;
    
    if ($filter && $filter ne 'off') {
      %population_filter = map { $_->dbID => $_ }
        @{$slice->get_all_VariationFeatures_by_Population(
          $hub->get_adaptor('get_PopulationAdaptor', 'variation')->fetch_by_name($filter), 
          $hub->param('min_frequency')
        )};
    }
    
    foreach my $snp (@{$object->variation_data}) {
      my $pos  = $snp->{'position'} - 1;
      my $dbID = $snp->{'vdbid'};
      
      next if keys %population_filter && !$population_filter{$dbID};
      
      $markup->{'variations'}->{$pos}->{'type'}    = lc $snp->{'type'};
      $markup->{'variations'}->{$pos}->{'alleles'} = $snp->{'allele'};
      $markup->{'variations'}->{$pos}->{'href'} ||= {
        type        => 'ZMenu',
        action      => 'TextSequence',
        factorytype => 'Location'
      };
      
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'v'}},  $snp->{'snp_id'};
      push @{$markup->{'variations'}->{$pos}->{'href'}->{'vf'}}, $dbID;
    }
  }
  
  return (\@sequence, [ $markup ]);
}

sub initialize {
  my ($self, $translation, $transcript) = @_;
  
  my $hub = $self->hub;
  
  my $config = {
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1
  };
  
  for (qw(exons variation number)) {
    $config->{$_} = $hub->param($_) eq 'yes' ? 1 : 0;
  }

  my ($sequence, $markup) = $self->get_sequence_data($translation, $transcript, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  return ($sequence, $config);
}

sub content {
  my $self        = shift;
	my $transcript  = $self->get_transcription_object;
	my $translation = $transcript->translation_object;
	
  return $self->non_coding_error unless $translation;
  
  my ($sequence, $config) = $self->initialize($translation,$transcript);
  
	my $html = '<h2>Protein ID: '.$translation->stable_id.'</h2><h3>(Transcript ID: '.$transcript->stable_id.')</h3>';
  $html   .= $self->tool_buttons($translation->Obj->seq, $config->{'species'}, 'peptide');
  $html   .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
  $html   .= $self->build_sequence($sequence, $config);

  return $html;
}

sub content_rtf {
  my $self        = shift;
  my $transcript  = $self->get_transcription_object;
	my $translation = $transcript->translation_object;
  
  my ($sequence, $config) = $self->initialize($translation,$transcript);
  
  return $self->export_sequence($sequence, $config, sprintf 'Protein-Sequence-%s-%s', $config->{'species'}, $translation->stable_id);
}

# Return an EnsEMBL::Web::Object::Transcript object
sub get_transcription_object {
	my $self = shift;
	my $param  = $self->hub->param('lrgt');
	
	my $transcripts = $self->object->get_all_transcripts;
	
	if (!$param) {
		return $transcripts->[0];
	}
	else {
		foreach my $tr (@$transcripts) {
			if ($tr->stable_id eq $param) {
				return $tr;
			}
		}
	}
}

1;
