=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_snp -
Glyphset to diplay SNPs from Glovar

=head1 DESCRIPTION

Displays SNPs that are stored in a Glovar database

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation;
use Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::Variation::VariationFeature objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my $self = shift;
    
    ## don't display glovar SNPs on chr6 haplotypes (they broken ...)
    return if ($self->{'container'}->seq_region_name =~ /_/);
    
    my %ct = %Bio::EnsEMBL::ExternalData::Glovar::GlovarSNPAdaptor::CONSEQUENCE_TYPES;
    my @snps = 
        map { $_->[1] } 
        sort { $a->[0] <=> $b->[0] }
        map { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
            @{$self->{'container'}->get_all_ExternalFeatures('GlovarSNP')};

    if(@snps) {
        $self->{'config'}->{'variation_legend_features'}->{'variations'} 
            = { 'priority' => 1000, 'legend' => [] };
    }

    return \@snps;
}

=head2 zmenu

  Arg[1]      : a Bio::EnsEMBL::Variation::VariationFeature object
  Example     : my $zmenu = $self->zmenu($f);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $f) = @_;
    my ($start, $end) = $self->slice2sr( $f->start, $f->end );
    my $allele = $f->allele_string;
    my $pos = $start;
    if($f->start > $f->end  ) {
      $pos = "between&nbsp;$start&nbsp;&amp;&nbsp;$end";
    }
    elsif($f->start < $f->end ) {
      $pos = "$start&nbsp;-&nbsp;$end";
    }
    my $status = join ", ", @{$f->get_all_validation_states};
    my $cons = join ", ", @{ $f->get_consequence_type || [] };
    $cons = '-' if ($cons eq '_');

    my %zmenu = ( 
        'caption' => "SNP: " . ($f->variation_name),
        '01:SNPView' => $self->href($f),
        #'02:Sanger SNP Report' => $self->ID_URL('GLOVAR_SNP', $id),
        "03:bp: $pos" => '',
        "04:Strand: ".$f->strand => '',
        "06:Status: ".($status || '-') => '',
        "05:Class: ".($f->var_class || '-') => '',
 	"07:Ambiguity code: ".($f->ambig_code || '-') => '',
        "08:Alleles: ".$f->allele_string => '',
        "09:Type: $cons" => '',
    );

    # external db links
    my %ext_db_map = (
        'TCS'       => 'TCS',
        'dbSNP rs'  => 'SNP',
        'dbSNP ss'  => 'DBSNPSS',
    );
    my $var = $f->variation;
    my @sources = @{ $var->get_all_synonym_sources };

    foreach my $ext_db (@sources) {
        my $ext_url = $ext_db_map{$ext_db};
        next unless $ext_url;
        foreach my $ext_id (@{ $var->get_all_synonyms($ext_db) }) {
            $zmenu{"16:$ext_db: ".$ext_id} = $self->ID_URL($ext_url, $ext_id);
        }
    }

    return \%zmenu;
}

1;
