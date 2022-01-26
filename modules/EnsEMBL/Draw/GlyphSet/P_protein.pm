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

package EnsEMBL::Draw::GlyphSet::P_protein;

### Draws protein track on Transcript/ProteinSummary
### (alternate blocks of light and dark purple)

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _obp {
  return "" if(defined($_[1]) and $_[0]==$_[1]);
  return ("(1st base)","(2nd base)","(3rd base)")[$_[0]];
}
sub _trisect {
  return sprintf("%d%s",$_[0]/3,(""," 1/3"," 2/3")[$_[0]%3]);
}

sub _init {
  my ($self) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
  my $protein    = $self->{'container'};	
  my $pep_splice = $self->cache('image_splice');

  my $h          = $self->my_config('height') || 4; 
  my $flip       = 0;
  my @colours    = ($self->my_colour('col1'), $self->my_colour('col2'));
  my $o_offset  = 0;
  if( $pep_splice ){
    for my $exon_offset (sort { $a <=> $b } keys %$pep_splice){
      my $colour = $colours[$flip];
      my $exon_id = $pep_splice->{$exon_offset}{'exon'};
      next unless $exon_id;

      # This code brought to you by the number 3.
      # We could have made this easier for ourselves by using cdna-bp co-ordinates throughout...
      my $n_offset = ($exon_offset) * 3 - (3-$pep_splice->{$exon_offset}{'phase'})%3;
      # zero-based offset and phase, semi-open
      my ($aa_s,$p_s,$aa_e,$p_e,$aa_l,$p_l) = 
          (int($o_offset/3),$o_offset%3,
           int($n_offset/3),$n_offset%3,
           int(($n_offset-1)/3),($n_offset-1)%3);           

      my $location_link;
      my $adaptor     = $protein->adaptor->db->get_TranscriptAdaptor;
      my $transcript  = $adaptor->fetch_by_translation_stable_id($protein->stable_id);
      if ($transcript) {
        my $slice = $transcript->feature_Slice;
        if ($slice) {
          my $location    = sprintf('%s:%s-%s', $slice->seq_region_name, $slice->start, $slice->end);
          my $url         = $self->{'config'}->hub->url({'type' => 'Location', 'action' => 'View', 'r' => $location});
          $location_link  = sprintf('<a href="%s">%s</a>', $url, $location);
        }
      }

      my $full_aa = $aa_e - $aa_s;
      $full_aa-- if($p_s);

      my $length = sprintf("%dbp, %s aa",$n_offset-$o_offset,_trisect($n_offset-$o_offset));

      $self->push( $self->Rect({
        'x'        => $aa_s,
        'y'        => 0,
        'width'    => $aa_e - $aa_s + 1,
        'height'   => $h,
        'colour'   => $colour,
        'title'    => sprintf 'Exon: %s; Location: %s; First aa: %d %s; Last aa: %d %s; Start phase: %s; End phase: %s; Length: %s',
	                $exon_id,
                  $location_link,
                  $aa_s+1,_obp($p_s,0),$aa_l+1,_obp($p_l,2),
                  $p_s,$p_l,
                  $length,
      }));
      $flip        = 1-$flip;
      $o_offset = $n_offset;
    }
  } else {
    $self->push( $self->Rect({
      'x'        => 0,
      'y'        => 0,
      'width'    => $protein->length(),
      'height'   => $h,
      'colour'   => $colours[0],
    }));
  }
}

sub render_text {
  my $self = shift;
  
  my $container = $self->{'container'};
  my $pep_splice = $self->cache('image_splice') || {};
  my $start = 1;
  my $start_phase = 1;
  my $export;
  
  foreach (sort { $a <=> $b } keys %$pep_splice) {
    my $exon_id = $pep_splice->{$_}->{'exon'};
    
    next unless $exon_id;
    
    my $end_phase = $pep_splice->{$_}->{'phase'} + 1;
    
    $export .= $self->_render_text($container, 'Protein', { 
      'headers' => [ 'exon_id', 'start_phase', 'end_phase' ], 
      'values'  => [ $exon_id, $start_phase, $end_phase ] 
    }, { 
      'start' => $start,
      'end'   => $_
    });
    
    $start = $_ + 1;
    $start_phase = $end_phase;
  }
  
  return $export;
}

1;
