package Bio::EnsEMBL::GlyphSet::snp_triangle_glovar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

sub features {
    my $self = shift;
    my @snps = 
        map { $_->[1] } 
        sort { $a->[0] <=> $b->[0] }
        map { [ substr($_->type,0,2) * 1e9 + $_->start, $_ ] }
        grep { $_->score < 4 } 
            @{$self->{'container'}->get_all_ExternalLiteFeatures('GlovarSNP')};

    if(@snps) {
        $self->{'config'}->{'snp_legend_features'}->{'snps'} 
            = { 'priority' => 1000, 'legend' => [] };
    }

    return \@snps;
}

sub tag {
    my ($self, $f) = @_; 
    my ($col,$labcol) =  $self->colour($f);
    #warn( "snp - $col - $labcol" );
    if ($f->snpclass eq 'SNP - substitution') {
	return( { 'style' => 'box', 'letter' => $f->{'_ambiguity_code'}, 'colour' => $col, 'label_colour' => $labcol } );
    }
    if ($f->snpclass =~ /Complex/) {
	return( { 'style' => 'left-snp', 'colour' => $col } );
    }
    if ($f->snpclass eq 'SNP - indel' ) {
	return( { 'style' => 'delta', 'colour' => $col } );
    }
    return ( { 'style'  => 'box', 'colour' => $col, 'letter' => ' ' } );
}

sub colour {
    ## sort this out once there is snp_gene_consequence data in glovar
    my ($self, $f) = @_;
    my $T = substr($f->type,3,6);
    unless($self->{'config'}->{'snp_types'}{$T}) {
        my %labels = (
            '_coding' => 'Coding SNPs',
            '_utr'    => 'UTR SNPs',
            '_intron' => 'Intronic SNPs',
            '_local'  => 'Flanking SNPs',
            '_'       => 'other SNPs'
        );
        push @{ $self->{'config'}->{'snp_legend_features'}->{'snps'}->{'legend'} }, $labels{"_$T"} => $self->{'colours'}{"_$T"};
        $self->{'config'}->{'snp_types'}{$T}=1;
    }
    return( $self->{'colours'}{"_$T"}, $self->{'colours'}{"label_$T"}, 'invisible' );
}

sub zmenu {
    my ($self, $f ) = @_;
    my $chr_start = $f->start() + $self->{'container'}->chr_start() - 1;
    my $chr_end   = $f->end() + $self->{'container'}->chr_start() - 1;

    my $allele = $f->alleles;
    my $pos;
    if ($chr_start == $chr_end) {
        $pos = "$chr_start";
    } else {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
    }
    my %zmenu = ( 
        'caption'           => "SNP: ".$f->id(),
        '01:SNP properties' => $self->href( $f ),
        "02:bp: $pos" => '',
        "03:class: ".$f->snpclass => '',
        "03:status: ".$f->raw_status => '',
        "07:ambiguity code: ".$f->{'_ambiguity_code'} => '',
        "08:alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => ''
   );

    my %links;
    
    my $source = $f->source_tag; 
    foreach my $link ($f->each_DBLink()) {
      my $DB = $link->database;
      if ( $DB eq 'TSC-CSHL' || $DB eq 'HGBASE' || $DB eq 'WI' ) {
        $zmenu{"16:$DB:".$link->primary_id } = $self->ID_URL( $DB, $link->primary_id );
      } elsif ($DB eq 'dbSNP rs') {
        $zmenu{"16:dbSNP:".$link->primary_id } = $self->ID_URL( 'dbSNP', $link->primary_id );
      } elsif ($DB eq 'dbSNP ss') {
        $zmenu{"16:dbSNP:".$link->primary_id } = $self->ID_URL( 'SNP_SS', $link->primary_id );
      }
    }
    my $type = substr($f->type(),3);
    $zmenu{"57:Type: $type"} = "" unless $type eq '';  
    return \%zmenu;
}

1;
