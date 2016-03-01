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

package EnsEMBL::Draw::GlyphSet::_transcript;

### Default module for drawing Ensembl transcripts (i.e. where rendering
### does not need to be tweaked to fit a particular display)

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet_transcript_new);

sub _get_all_genes {
  my ($self,$slice,$analysis,$alias) = @_;

  my $hub = $self->{'config'}->hub;
  my $species = $self->species;
  my $load_transcripts = ($self->{'display'} =~ /transcript/);
  my $key = join('::',$self->species,$slice->name,$analysis,$alias,$load_transcripts);
  my $out = $hub->req_cache_get($key);
  return $out if defined $out;
  $out = $slice->get_all_Genes($analysis,$alias,$load_transcripts);
  $hub->req_cache_set($key,$out);
  return $out;
}

sub features {
  my $self           = shift;
  my @genes          = @_;
  my $slice          = $self->{'container'};
  my $display        = $self->{'display'};  
  my $db_alias       = $self->my_config('db');
  my $analyses       = $self->my_config('logic_names');
  my $selected_gene  = $self->my_config('g') || $self->core('g');
  my $selected_trans = $self->core('t')      || $self->core('pt');
  my $highlight      = $self->core('db') eq $self->my_config('db') ? $display =~ /transcript/ ? 'highlight1' : 'highlight2' : undef;
  my (%highlights, %transcripts, %exons);
  
  if (!scalar @genes) {
    ## FIXME - this is an ugly hack!
    if ($analyses->[0] eq 'LRG_import' && !$slice->isa('Bio::EnsEMBL::LRGSlice')) {
      my $lrg_slices = $slice->project('lrg');
      if ($lrg_slices->[0]) {
        my $lrg_slice = $lrg_slices->[0]->to_Slice;
        @genes = map @{$self->_get_all_genes($lrg_slice,$_,$db_alias) || []}, @$analyses;
        $display = 'transcript_label';
      }
    }
    elsif ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
      @genes = map @{$slice->feature_Slice->get_all_Genes($_, $db_alias) || []}, @$analyses;
    } else {
      @genes = map @{$self->_get_all_genes($slice,$_,$db_alias) || []}, @$analyses;
    }
  }
  
  if ($highlight) {
    $highlights{$selected_gene}  = $highlight;
    $highlights{$selected_trans} = 'highlight2';
  }
  
  if ($display =~ /collapsed/) {
    $exons{$_->stable_id} = [ map @{$_->get_all_Exons}, @{$_->get_all_Transcripts} ] for @genes;
  } elsif ($display =~ /transcript/) {
    my $coding_only = $display =~ /coding/;    
    
    foreach my $gene (@genes) {    
      my $gene_id         = $gene->stable_id;
      my $is_coding_check = $coding_only ? $self->is_coding_gene($gene) : 0;
      my @trans           = @{$gene->get_all_Transcripts};
         @trans           = grep $_->translation, @trans if $is_coding_check;         
    
      foreach (@trans) {        
        my $transcript_id           = $_->stable_id;
        my $transcript_coding_start = defined $_->coding_region_start ? $_->coding_region_start : -1e6;
        my $transcript_coding_end   = defined $_->coding_region_end   ? $_->coding_region_end   : -1e6;
        
        foreach (sort { $a->start <=> $b->start } grep $_, @{$_->get_all_Exons}) {
          my ($start, $end) = ($_->start, $_->end);
          my $coding_start  = max($transcript_coding_start, $start);
          my $coding_end    = min($transcript_coding_end,   $end);
          
          # The start of the transcript is before the start of the coding
          # region OR the end of the transcript is after the end of the
          # coding regions.  Non coding portions of exons, are drawn as
          # non-filled rectangles
          # Draw a non-filled rectangle around the entire exon
          push @{$exons{$transcript_id}}, [ $_, 'border' ] if $start < $transcript_coding_start || $end > $transcript_coding_end;
          
          # Draw a filled rectangle in the coding region of the exon
          # Calculate and draw the coding region of the exon
          push @{$exons{$transcript_id}}, [ $_, 'fill', $coding_start - $start, $end - $coding_end ] if $coding_start <= $coding_end;
        }
        
        $highlights{$transcript_id} ||= $_->get_all_Attributes('ccds')->[0] ? $self->{'colours'}{'ccds_hi'} ? $self->my_colour('ccds_hi') : 'lightblue1' : $highlights{$gene_id} if $highlight;
      }
      
      $transcripts{$gene_id} = \@trans;
    }
  }  
  return (\@genes, \%highlights, \%transcripts, \%exons);
}

sub export_feature {
  my ($self, $feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  }, { source => $gene_source });
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $hub    = $self->{'config'}->hub;
  my $params = {
    %{$hub->multi_params},
    species    => $self->species,
    type       => $transcript ? 'Transcript' : 'Gene',
    action     => $self->my_config('zmenu') ? $self->my_config('zmenu') : $hub->action,
    g          => $gene->stable_id,
    db         => $self->my_config('db'),
    calling_sp => $hub->species,
    real_r     => $hub->param('r'),
  };

  $params->{'r'} = undef                  if $self->{'container'}{'web_species'} ne $self->species;
  $params->{'t'} = $transcript->stable_id if $transcript;

  return $self->_url($params);
}

1;
