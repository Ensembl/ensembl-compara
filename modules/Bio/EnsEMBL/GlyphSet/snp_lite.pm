package Bio::EnsEMBL::GlyphSet::snp_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "SNPs"; }

sub features {
  my ($self) = @_;
  
  my @snps = sort { $a->type() cmp $b->type() || $a->start() <=> $b->start()}  
                  grep { $_->score < 4 } $self->{'container'}->get_all_SNPs();

  if(@snps) {
    $self->{'config'}->{'snp_legend_features'}->{'snps'} 
        = { 'priority' => 1000, 'legend' => [] };
  }

  return @snps;
}

sub href {
    my ($self, $f ) = @_;
    
    my $snp_id = $f->id();
    my $chr_start = $self->{'container'}->chr_start();
    my $chr_name = $self->{'container'}->chr_name();

    return "/$ENV{'ENSEMBL_SPECIES'}/snpview?snp=$snp_id&chr=$chr_name&vc_start=$chr_start";
}

sub colour {
  my ($self, $f) = @_;

  my $type = substr($f->type(), 3);

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

  return $self->{'colours'}{"_$type"};
}


sub zmenu {
    my ($self, $f ) = @_;
    my $ext_url = $self->{'config'}->{'ext_url'};
    
    my $chr_start = $f->start() + $self->{'container'}->chr_start() - 1;

    my %zmenu = ( 
        'caption'           => "SNP: ".$f->id(),
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $chr_start" => '',
        '08:score: '.$f->score => '',
     
   );

    if($f->id() > 0) {
      $zmenu{'03:dbSNP data'} = $ext_url->get_url('SNP', $f->id());
    }

    my %links;
    
    foreach my $link ($f->each_DBLink()) {
      $links{$link->database()} = $link->primary_id();
    }

    if(defined $links{'TSC-CSHL'}) {
      $zmenu{"04:TSC-CSHL data"} 
         = $ext_url->get_url( 'TSC-CSHL', $links{'TSC-CSHL'} );      
    }

    if(defined $links{'HGBASE'}) {
      $zmenu{"05:HGBASE data"}  
         = $ext_url->get_url( 'HGBASE', $links{'HGBASE'});
    }
    
    my $type = substr($f->type(),3);
    $zmenu{"06:Type: $type"} = "" unless $type eq '';  
    return \%zmenu;
}
1;
