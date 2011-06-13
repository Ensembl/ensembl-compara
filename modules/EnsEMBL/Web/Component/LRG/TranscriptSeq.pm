
package EnsEMBL::Web::Component::LRG::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::Transcript EnsEMBL::Web::Component::Transcript::TranscriptSeq EnsEMBL::Web::Component::TextSequence);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub initialize {
  my $self       = shift;
	my $transcript = shift; 
  my $hub        = $self->hub;
  
  my $config = { 
    display_width   => $hub->param('display_width') || 60,
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1
  };
  
  $config->{$_} = $hub->param($_) eq 'yes' ? 1 : 0 for qw(exons codons coding_seq translation rna variation number utr);
  
  $config->{'codons'}    = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $transcript->Obj->translation;
	$config->{'variation'} = 0 unless $hub->species_defs->databases->{'DATABASE_VARIATION'};
  
  my ($sequence, $markup, $raw_seq) = $self->get_sequence_data($transcript, $config);
  
  $self->markup_exons($sequence, $markup, $config)     if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config)    if $config->{'codons'};
  $self->markup_variation($sequence, $markup, $config) if $config->{'variation'};  
  $self->markup_line_numbers($sequence, $config)       if $config->{'number'};
  
  $config->{'v_space'} = "\n" if $config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'};
  
  return ($sequence, $config, $raw_seq);
}

sub content {
  my $self = shift;
 
	my $transcript = $self->get_transcript_object;
  my ($sequence, $config, $raw_seq) = $self->initialize($transcript);
  
	my $html = '<h2>Transcript ID: '.$transcript->stable_id.'</h2>';
  $html   .= $self->tool_buttons($raw_seq, $config->{'species'});
  $html   .= sprintf('<div class="sequence_key">%s</div>', $self->get_key($config));
  $html   .= $self->build_sequence($sequence, $config);

  return $html;
}

sub content_rtf {
  my $self = shift;
	my $transcript = $self->get_transcript_object;
  my ($sequence, $config) = $self->initialize($transcript);
  return $self->export_sequence($sequence, $config, sprintf 'cDNA-Sequence-%s-%s', $config->{'species'}, $self->object->stable_id);
}


# Return an EnsEMBL::Web::Object::Transcript object
sub get_transcript_object {
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
