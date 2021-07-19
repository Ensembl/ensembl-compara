=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::snp_join;

### Draws "tent" lines joining variation track to zoomed out SNPs
### on Transcript/Population/Image

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self        = shift; 
  my $strand_flag = $self->my_config('str');
  my $strand      = $self->strand();
  
  return if ($strand_flag eq 'f' && $strand != 1) || ($strand_flag eq 'r' && $strand == 1);
  
  my $tag       = $self->my_config('tag');
  my $tag2      = $tag + ($strand == -1 ? 1 : 0);
  my $container = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $length    = $container->length;
  my $colours   = $self->my_config('colours'); 
  
  foreach my $snp_ref (@{$self->get_snps || []}) {
    my $snp      = $snp_ref->[2];
    my $tag_root = $snp->dbID;
    my $type     = lc $snp->display_consequence;
    my $colour   = $colours->{$type}->{'default'};
    my ($s, $e)  = ($snp_ref->[0], $snp_ref->[1]);
    
    $s = 1 if $s < 1;
    $e = $length if $e > $length;
    
    my $tglyph = $self->Space({
      x      => $s - 1,
      y      => 0,
      height => 0,
      width  => $e - $s + 1,
    });
    
    $self->join_tag($tglyph, "X:$tag_root=$tag2", .5, 0, $colour, '',     -3); 
    $self->join_tag($tglyph, "X:$tag_root-$tag",  .5, 0, $colour, 'fill', -3);  
    $self->push($tglyph);
  }
}

sub get_snps {
  my $self   = shift;
  my $config = $self->{'config'};

  return $config->{'snps'} if $config->{'fakeslice'} ;
  
  my @snps        = @{$config->{'filtered_fake_snps'} || []}; 
  my $target_gene = $config->{'geneid'};  
  my $context     = $self->my_config('context') || 100; 
  my %exons;
  
  if ($context && @snps) {
    my $features = $self->{'container'}->get_all_Genes;

    foreach my $gene (@$features) {
      next if $target_gene && $gene->stable_id ne $target_gene;
      
      $exons{join ':', $_->start, $_->end}++ for map @{$_->get_all_Exons}, @{$gene->get_all_Transcripts};
    }
    
    my @exons = map [ split /:/, $_ ], keys %exons;
    my @snps2;
    
    foreach my $snp (@snps) { 
      foreach my $exon (@exons) {  
       if ($snp->[0] <= $exon->[1] + $context && $snp->[1] >= $exon->[0] - $context) {
         push @snps2, $snp;
         last;
       }
      }
    }
    
    @snps = @snps2;
  }
  
  return \@snps;
}


1;
