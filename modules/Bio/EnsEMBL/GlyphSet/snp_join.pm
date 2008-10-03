package Bio::EnsEMBL::GlyphSet::snp_join;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

use Bio::EnsEMBL::Variation::VariationFeature;
use Bio::EnsEMBL::GlyphSet;
  
@Bio::EnsEMBL::GlyphSet::snp_join::ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config        = $self->{'config'};
#  my $strand_flag   = $self->{'config'}->get('snp_join','str');
  my $strand_flag = $self->my_config('str');
  my $strand        = $self->strand();
  return if ( $strand_flag eq 'f' && $strand != 1 ) || ( $strand_flag eq 'r'  && $strand == 1 );

  my @snps = @ { $self->get_snps($Config)  || []};
 # my $tag = $Config->get( 'snp_join', 'tag' );
  my $tag = $self->my_config('tag');
  my $tag2 = $tag + ($strand == -1 ? 1 : 0);
  my $T = $strand == 1 ? 1 : 0;
  my $C=0;
  my $container     = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'} : $self->{'container'};
  my $start = $container->start();
  my $length  = $container->length;
  #my $colours       = $Config->get('snp_join','colours' );
  my $colours = $self->my_config('colours');

  foreach my $snp_ref ( @snps ) { 
    my $snp = $snp_ref->[2];
    my( $S,$E ) = ($snp_ref->[0], $snp_ref->[1] );
    my $tag_root = $snp->dbID();
    $S = 1 if $S < 1;
    $E = $length if $E > $length;
    my $type = $snp->display_consequence;
   # my $colour = $colours->{$type}->[0];
    my $colour = $self->my_colour($type);
    my $tglyph = $self->Rect({
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

sub get_snps {
  my ($self, $Config) = @_;
  return $Config->{'snps'} if $Config->{'fakeslice'} ;

  my @snps;
  if ( $Config->{'filtered_fake_snps'} ){
    @snps  = @{ $Config->{'filtered_fake_snps'} };
  }
  else {
    my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
    @snps = map  { [ $_->[1]->start, $_->[1]->end, $_->[1]  ] } 
      sort { $a->[0] <=> $b->[0] }
	map { [ - $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
	  grep { $_->map_weight < 4 }
	    @{$self->{'container'}->get_all_VariationFeatures()};
  }

  my %exons = ();
  my $target_gene   = $Config->{'geneid'};
  #my $context = $Config->get( 'snp_join', 'context' );
  my $context = $self->my_config('context');
  if( $context && @snps ) {
    my $features = $self->{'container'}->get_all_Genes(lc($self->species_defs->AUTHORITY));
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
  return \@snps;
}


1;
