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
use Bio::EnsEMBL::GlyphSet::snp_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

=head2 my_label

  Arg[1]      : none
  Example     : my $label = $self->my_label;
  Description : returns the label for the track (displayed track name)
  Return type : String - track label
  Exceptions  : none
  Caller      : $self->init_label()

=cut

sub my_label { return "SNPs"; }

=head2 features

  Arg[1]      : none 
  Example     : my $f = $self->features;
  Description : this function does the data fetching from the Glovar database
  Return type : listref of Bio::EnsEMBL::SNP objects
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub features {
    my $self = shift;
    
    ## don't display glovar SNPs on chr6 haplotypes (they broken ...)
    return if ($self->{'container'}->chr_name =~ /_/);
    
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

    ## hack to disable consequences on chr7
    if ($self->{'container'}->chr_name == 7) {
        foreach my $snp (@snps) {
            $snp->{'_type'} = undef;
            $snp->{'_consequence'} = undef;
        }
    }

    return \@snps;
}

=head2 tag

  Arg[1]      : a Bio::EnsEMBL::SNP object
  Example     : my $tag = $self->tag($f);
  Description : retrieves the SNP tag (ambiguity code) in the right colour
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub tag {
    my ($self, $f) = @_;
    if (($f->snpclass eq 'SNP - indel') && ($f->start ne $f->end)) {
        my $type = $f->type;
        return ( { 'style' => 'insertion', 'colour' => $self->{'colours'}{"_$type"} } );
    } else {
        return undef;
    }
}

=head2 colour

  Arg[1]      : a Bio::EnsEMBL::SNP object
  Example     : my $colour = $self->colour($f);
  Description : sets the colour for displaying SNPs. They are coloured
                according to their position on genes
  Return type : list of colour settings
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub colour {
    my ($self, $f) = @_;
    my $T = $f->type;
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
    return( $self->{'colours'}{"_$T"}, $self->{'colours'}{"label_$T"}, (($f->snpclass eq 'SNP - indel') && ($f->start ne $f->end)) ? 'invisible' : '' );
}

=head2 zmenu

  Arg[1]      : a Bio::EnsEMBL::SNP object
  Example     : my $zmenu = $self->zmenu($f);
  Description : creates the zmenu (context menu) for the glyphset. Returns a
                hashref describing the zmenu entries and properties
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub zmenu {
    my ($self, $f ) = @_;
    my $chr_start = $f->start() + $self->{'container'}->chr_start() - 1;
    my $chr_end   = $f->end() + $self->{'container'}->chr_start() - 1;

    my $allele = $f->alleles;
    my $pos;
    my $id = $f->snpid || $f->id;
    if ($chr_start == $chr_end) {
        $pos = "$chr_start";
    } else {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
    }
    my %zmenu = ( 
        'caption'           => "SNP: $id",
        '01:SNPView' => $self->href($f),
        #'02:Sanger SNP Report' => $self->ID_URL('GLOVAR_SNP', $id),
        "03:bp: $pos" => '',
        "04:Strand: ".$f->strand => '',
        "05:Class: ".$f->snpclass => '',
        "06:Status: ".$f->raw_status => '',
        "08:Alleles: ".(length($allele)<16 ? $allele : substr($allele,0,14).'..') => '',
        "09:Position type: ".($f->type||'other') => '',
        "10:Consequence: ".($f->consequence||'unknown') => '',
    );
    $zmenu{"07:Ambiguity code: ".$f->{'_ambiguity_code'}} = '' if $f->{'_ambiguity_code'};

    my %links;
    
    my $source = $f->source_tag; 
    foreach my $link ($f->each_DBLink()) {
      my $DB = $link->database;
      if ($DB =~ s/(TSC)/\1/i) {
        $zmenu{"16:$DB:".$link->primary_id } = $self->ID_URL( $DB, $link->primary_id );
      } elsif ($DB eq 'dbSNP rs') {
        $zmenu{"16:dbSNP:".$link->primary_id } = $self->ID_URL( 'dbSNP', $link->primary_id );
      } elsif ($DB eq 'dbSNP ss') {
        $zmenu{"16:dbSNP:".$link->primary_id } = $self->ID_URL( 'SNP_SS', $link->primary_id );
      }
    }
    return \%zmenu;
}

1;
