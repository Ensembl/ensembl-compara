package Bio::EnsEMBL::GlyphSet::snp_join;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Bio::EnsEMBL::Variation::VariationFeature;
use Sanger::Graphics::Glyph::Space;
use Bio::EnsEMBL::GlyphSet;
  
@Bio::EnsEMBL::GlyphSet::snp_join::ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
  my $strand_flag   = $self->{'config'}->get('snp_join','str');
  my $strand        = $self->strand();
  return if ( $strand_flag eq 'f' && $strand != 1 ) || ( $strand_flag eq 'r'  && $strand == 1 );

  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $target_gene   = $Config->{'geneid'};
    
  my $h             = 1;
    
  my @bitmap        = undef;
  my $colours       = $Config->get('snp_join','colours' );

  my $pix_per_bp    = $Config->transform->{'scalex'};

  my $length  = $container->length;
    
  my %exons = ();
  
  my @snps;
  if( $Config->{'fakeslice'} ) {
    @snps = @{$Config->{'snps'}};
  } else {
    my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
    @snps = map  { [ $_->[1]->start, $_->[1]->end, $_->[1]  ] } 
            sort { $a->[0] <=> $b->[0] }
            map { [ - $ct{$_->get_consequence_type} * 1e9 + $_->start, $_ ] }
            grep { $_->map_weight < 4 }
            @{$self->{'container'}->get_all_VariationFeatures()};
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
  my $start = $container->start();
  my $T = $strand == 1 ? 1 : 0;
  my $C=0;
  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
    my $tag_root = $snp->dbID();
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $type = $snp->get_consequence_type();
    my $colour = $colours->{$type};
    my $tglyph = new Sanger::Graphics::Glyph::Space({
      'x' => $S-1,
      'y' => 0,
      'height' => 0,
      'width'  => $E-$S+1,
    });
    $self->join_tag( $tglyph, "X:$tag_root=$tag2", .5, 0, $colour,'',-3 );
    $self->join_tag( $tglyph, "X:$tag_root-$tag", .5,0, $colour,'fill',-3 );
    $self->push( $tglyph );
  }
}
1;
