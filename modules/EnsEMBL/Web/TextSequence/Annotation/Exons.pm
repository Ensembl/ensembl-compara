package EnsEMBL::Web::TextSequence::Annotation::Exons;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub annotate {
  my ($self, $config, $slice_data, $markup) = @_; 
  my $slice    = $slice_data->{'slice'};
  my $exontype = $config->{'exon_display'} || '';
  my ($slice_start, $slice_end, $slice_length, $slice_strand) = map $slice->$_, qw(start end length strand);
  my @exons;
  
  if ($exontype eq 'Ab-initio') {
    @exons = grep { $_->seq_region_start <= $slice_end && $_->seq_region_end >= $slice_start } map @{$_->get_all_Exons}, @{$slice->get_all_PredictionTranscripts};
  } elsif ($exontype eq 'vega' || $exontype eq 'est') {
    @exons = map @{$_->get_all_Exons}, @{$slice->get_all_Genes('', $exontype)};
  } else {
    @exons = map @{$_->get_all_Exons}, @{$slice->get_all_Genes};
  }
  
  # Values of parameter should not be fwd and rev - this is confusing.
  if (($config->{'exon_ori'}||'') eq 'fwd') {
    @exons = grep { $_->strand > 0 } @exons; # Only exons in same orientation 
  } elsif (($config->{'exon_ori'}||'') eq 'rev') {
    @exons = grep { $_->strand < 0 } @exons; # Only exons in opposite orientation
  }
  
  my @all_exons = map [ $config->{'comparison'} ? 'compara' : 'other', $_ ], @exons;
  
  if ($config->{'exon_features'}) {
    push @all_exons, [ 'gene', $_ ] for @{$config->{'exon_features'}};
      
    if ($config->{'exon_features'} && $config->{'exon_features'}->[0] && $config->{'exon_features'}->[0]->isa('Bio::EnsEMBL::Exon')) {
      $config->{'gene_exon_type'} = 'exons';
    } else {
      $config->{'gene_exon_type'} = 'features';
    }   
  }
  
  if ($config->{'mapper'}) {
    my $slice_name = $slice->seq_region_name;
    push @$_, $config->{'mapper'}->map_coordinates($slice_name, $_->[1]->seq_region_start, $_->[1]->seq_region_end, $slice_strand, 'ref_slice') for @all_exons;
  }
 
  foreach (@all_exons) {
    my ($type, $exon, @mappings) = @$_;
     
    next unless $exon->seq_region_start && $exon->seq_region_end;
        
    foreach (scalar @mappings ? @mappings : $exon) {
      my $start = $_->start - ($type eq 'gene' ? $slice_start : 1);
      my $end   = $_->end   - ($type eq 'gene' ? $slice_start : 1);
      my $id    = $exon->can('stable_id') ? $exon->stable_id : '';

      ($start, $end) = ($slice_length - $end - 1, $slice_length - $start - 1) if $type eq 'gene' && $slice_strand < 0 && $exon->strand < 0;

      next if $end < 0 || $start >= $slice_length;

      $start = 0                 if $start < 0;
      $end   = $slice_length - 1 if $end >= $slice_length;

      for ($start..$end) {
        push @{$markup->{'exons'}{$_}{'type'}}, $type;
        $markup->{'exons'}{$_}{'id'} .= ($markup->{'exons'}{$_}{'id'} ? "\n" : '') . $id unless ($markup->{'exons'}{$_}{'id'}||'') =~ /$id/;
      }
    }
  }
}

1;
