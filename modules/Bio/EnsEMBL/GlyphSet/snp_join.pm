package Bio::EnsEMBL::GlyphSet::snp_join;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Sanger::Graphics::Glyph::Space;
use Bio::EnsEMBL::GlyphSet;
  
@Bio::EnsEMBL::GlyphSet::snp_join::ISA = qw(Bio::EnsEMBL::GlyphSet);
sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $target_gene   = $Config->{'geneid'};
    
  my $h             = 1;
    
  my @bitmap        = undef;
  my $colours       = $Config->get('snp_join','colours' );

  my $pix_per_bp    = $Config->transform->{'scalex'};

  my $strand  = $self->strand();
  my $length  = $container->length;
    
  my %exons = ();
  
  my @snps;
  if( $Config->{'fakeslice'} ) {
    @snps = @{$Config->{'snps'}};
  } else {
    @snps = map { [ $_->start, $_->end, $_  ] } 
          grep { $_->score < 4 } @{$self->{'container'}->get_all_SNPs()};
    my $context = $Config->get( 'snp_join', 'context' );
    if( $context && @snps ) {
      my $features = $self->{'container'}->get_all_Genes(lc(EnsWeb::species_defs->AUTHORITY));
      foreach my $gene ( @$features ) {
        next if $target_gene && ($gene->stable_id() ne $target_gene);
        foreach my $transcript (@{$gene->get_all_Transcripts()}) {
          foreach my $exon (@{$transcript->get_all_Exons()}) {
            $exons{ "@{[$exon->start]}:@{[$exon->end]}" }++;
          }
        }
      }
      my @snps2 = ();
      my @exons = map { [ split /:/, $_ ] } keys %exons;
      foreach my $snp (@snps) {
        foreach my $exon (@exons) { 
          if( $snp->[0] <= $exon->[1]+$context && $snp->[1] >= $exon->[0]-$context ) {
            push @snps2, $snp;
            last;
          }
        }
      }
      @snps = @snps2;
    }
  }
  my $tag = $Config->get( 'snp_join', 'tag' );
  my $tag2 = $tag + ($strand == -1 ? 1 : 0);
  my $start = $container->chr_start();
  my $T = $strand == 1 ? 1 : 0;
  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
    my $tag_root = join ':', $snp->id, $start+$snp->start, $start+$snp->end;
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $type = substr($snp->type(),3,6);
    my $colour = $colours->{"_$type"};
    my $tglyph = new Sanger::Graphics::Glyph::Space({
      'x' => $S-1,
      'y' => 0,
      'height' => 0,
      'width'  => $E-$S+1,
    });
  #  $self->join_tag( $tglyph, "X:$tag_root-$tag", $T, 0, $colour,'fill',-3 );
  #  $self->join_tag( $tglyph, "X:$tag_root-$tag", 1-$T,0, $colour,'fill',-3 );
    $self->join_tag( $tglyph, "X:$tag_root=$tag2", .5, 0, $colour,'',-3 );
    $self->join_tag( $tglyph, "X:$tag_root-$tag", .5,0, $colour,'fill',-3 );
  #  $self->join_tag( $tglyph, "X:$tag_root=$tag2", $T, 0, $colour,'',-3 );
  #  $self->join_tag( $tglyph, "X:$tag_root=$tag2", 1-$T, 0, $colour,'',-3 );
    $self->push( $tglyph );
  }
}
1;
