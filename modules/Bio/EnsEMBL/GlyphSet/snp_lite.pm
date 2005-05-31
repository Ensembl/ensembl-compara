package Bio::EnsEMBL::GlyphSet::snp_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  
  my @snps = 
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ substr($_->type,0,2) * 1e9 + $_->start, $_ ] }
             grep { $_->score < 4 } @{$self->{'container'}->get_all_SNPs()};

  if(@snps) {
    $self->{'config'}->{'snp_legend_features'}->{'snps'} 
        = { 'priority' => 1000, 'legend' => [] };
  }

  return \@snps;
}

sub href {
    my ($self, $f ) = @_;

    my( $chr_start, $chr_end ) = $self->slice2sr( $f->start, $f->end );
    my $snp_id = $f->snpid || $f->id;

    my $source = $f->source_tag;
    my $chr_name = $self->{'container'}->seq_region_name();

    return "/@{[$self->{container}{_config_file_name_}]}/snpview?snp=$snp_id;source=$source;chr=$chr_name;vc_start=$chr_start";
}

sub image_label {
  my ($self, $f) = @_;
  return $f->{'_ambiguity_code'} eq '-' ? undef : ($f->{'_ambiguity_code'},'overlaid');
}

sub tag {
  my ($self, $f) = @_;
   if($f->{'_range_type'} eq 'between' ) {
      my $type = substr($f->type(),3,6);
      return ( { 'style' => 'insertion', 'colour' => $self->{'colours'}{"_$type"} } );
   } else {
      return undef;
   }
}

sub colour {
  my ($self, $f) = @_;

  my $type = substr($f->type(),3,6);
  unless($self->{'config'}->{'snp_types'}{$type}) {
    my %labels = (
	 '_coding' => 'Coding SNPs',
	 '_utr'    => 'UTR SNPs',
	 '_intron' => 'Intronic SNPs',
	 '_local'  => 'Flanking SNPs',
	 '_'       => 'Other SNPs' );
    push @{ $self->{'config'}->{'snp_legend_features'}->{'snps'}->{'legend'}},
           $labels{"_$type"} => $self->{'colours'}{"_$type"};
    $self->{'config'}->{'snp_types'}{$type} = 1;
  }

  return $self->{'colours'}{"_$type"},$self->{'colours'}{"label_$type"}, $f->{'_range_type'} eq 'between' ? 'invisible' : '';
}


sub zmenu {
    my ($self, $f ) = @_;
    my( $chr_start, $chr_end ) = $self->slice2sr( $f->start, $f->end );

    my $allele = $f->alleles;
    my $dbsnp_id  = '';
    my $tsc_id    = '';
    my $hgbase_id = '';
    my $wi_id     = '';
    foreach my $link ($f->each_DBLink()) {
      my $DB = $link->database;
         if( $DB eq 'TSC-CSHL' ) { $tsc_id    = $link->primary_id; }
      elsif( $DB eq 'HGBASE'   ) { $hgbase_id = $link->primary_id; }
      elsif( $DB eq 'WI'       ) { $wi_id     = $link->primary_id; }
      elsif( $DB eq 'dbSNP' && $f->source_tag eq 'dbSNP' ) { $dbsnp_id  = $link->primary_id; }
    }
    
    return "zs( '@{[join ';',
      'hs', $self->{'container'}->seq_region_name, $chr_start, $chr_end-$chr_start,
      $f->snpid||$f->id, $f->source_tag, $f->status, $f->{'_mapweight'},
      $f->{'_ambiguity_code'}, (length($allele<16)?$allele : substr($allele,0,14).'..'),
      substr( $f->type(),3 ),
      $dbsnp_id, $tsc_id, $hgbase_id, $wi_id
      ]}')";
      
}
1;
