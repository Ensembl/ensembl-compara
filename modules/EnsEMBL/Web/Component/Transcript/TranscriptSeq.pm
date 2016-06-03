=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Transcript::TranscriptSeq;

use strict;
  
use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Transcript);

use List::Util qw(max);

sub get_sequence_data {
  my ($self, $object, $config,$adorn) = @_;

  my $hub = $self->hub;
  my $data = $hub->get_query('Sequence::Transcript')->go($self,{
    species => $hub->species,
    type => $object->get_db,
    transcript => $object->Obj,
    config => $config,
    adorn => $adorn,
    conseq_filter => [$hub->param('consequence_filter')],
  });
  return ($data->[0]{'sequence'},$data->[0]{'markup'});
}

sub markup_line_numbers {
  my ($self, $sequence, $config) = @_;
 
  # Keep track of which element of $sequence we are looking at
  my $n = 0;
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $seq  = $sequence->[$n];
    my $data = $sl->{'slice'} ? { 
      dir   => 1,  
      start => 1,
      end   => $config->{'length'},
      label => ''
    } : {};
    
    my $s = 0;
    my $e = $config->{'display_width'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $config->{'length'} + $config->{'display_width'};
    
    while ($e < $loop_end) {
      $start = '';
      $end   = '';
      
      my $seq_length = 0;
      my $segment    = '';
      
      # Build a segment containing the current line of sequence        
      for ($s..$e) {
        # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
        if ($seq->[$_]) {
          $seq_length++ if $config->{'line_numbering'} eq 'slice' || $seq->[$_]{'letter'} =~ /\w/;
          $segment .= $seq->[$_]{'letter'};
        }
      }
      
      # Reference sequence starting with N or NN means the transcript begins mid-codon, so reduce the sequence length accordingly.
      $seq_length -= length $1 if $segment =~ /^(N+)\w/;
      
      $end   = $e < $config->{'length'} ? $row_start + $seq_length - $data->{'dir'} : $data->{'end'};
      $start = $row_start if $seq_length;
      
      # If the line starts --,  =- or -= it is at the end of a protein section, so take one off the line number
      $start-- if $start > $data->{'start'} && $segment =~ /^([=-]{2})/;
      
      # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      $row_start = $end + $data->{'dir'} if $start && $end;
      
      # Remove the line number if the sequence doesn't start at the beginning of the line
      $start = '' if $segment =~ /^(\.|N+\w)/;
      
      $s = $e + 1;
      
      push @{$config->{'line_numbers'}{$n}}, { start => $start, end => $end || undef };
      
      # Increase padding amount if required
      $config->{'padding'}{'number'} = length $start if length $start > $config->{'padding'}{'number'};
      
      $e += $config->{'display_width'};
    }
    
    $n++;
  }
  
  $config->{'padding'}{'pre_number'}++ if $config->{'padding'}{'pre_number'}; # Compensate for the : after the label
}

sub initialize {
  my $self   = shift;
  my $hub    = $self->hub;
  my $object = $self->object || $hub->core_object('transcript');

  my $type   = $hub->param('data_type') || $hub->type;
  my $vc = $self->view_config($type);
 
  my $adorn = $hub->param('adorn') || 'none';
 
  my $config = { 
    species         => $hub->species,
    maintain_colour => 1,
    transcript      => 1,
  };
 
  $config->{'display_width'} = $hub->param('display_width') || $vc->get('display_width'); 
  $config->{$_} = ($hub->param($_) eq 'on' || $vc->get($_) eq 'on') ? 1 : 0 for qw(exons exons_case codons coding_seq translation rna snp_display utr hide_long_snps hide_rare_snps);
  $config->{'codons'}      = $config->{'coding_seq'} = $config->{'translation'} = 0 unless $object->Obj->translation;
 
  if ($hub->param('line_numbering') ne 'off') {
    $config->{'line_numbering'} = 'on';
    $config->{'number'}         = 1;
  }
  
  $self->set_variation_filter($config);
  
  my ($sequence, $markup) = $self->get_sequence_data($object, $config, $adorn);
  
  $self->markup_exons($sequence, $markup, $config)  if $config->{'exons'};
  $self->markup_codons($sequence, $markup, $config) if $config->{'codons'};
  if ($adorn ne 'none') {
    $self->markup_variation($sequence, $markup, $config) if $config->{'snp_display'};  
    push @{$config->{'loaded'}||=[]},'variants';
  } else {
    push @{$config->{'loading'}||=[]},'variants';
  }
  $self->markup_line_numbers($sequence, $config) if $config->{'line_numbering'};
  
  $config->{'v_space'} = "\n" if $config->{'coding_seq'} || $config->{'translation'} || $config->{'rna'};
  
  return ($sequence, $config);
}

sub content {
  my $self = shift;
  my ($sequence, $config) = $self->initialize;

  return $self->build_sequence($sequence, $config);
}

sub export_options { return {'action' => 'Transcript'}; }

sub initialize_export {
  my $self = shift;
  my $hub = $self->hub;
  my ($sequence, $config) = $self->initialize;
  return ($sequence, $config);
}

1;
