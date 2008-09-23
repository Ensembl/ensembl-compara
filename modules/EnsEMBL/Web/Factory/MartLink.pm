package EnsEMBL::Web::Factory::MartLink;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use CGI qw(escapeHTML);

our @ISA = qw(  EnsEMBL::Web::Factory );

sub _link {
  my( $self, $dataset, $attributes, $filters ) =@_;
  my $URL = '/biomart/martview?VIRTUALSCHEMANAME=default';
  if( @$attributes ) {
    $URL .= '&ATTRIBUTES='.join('|',map { "$dataset.default.feature_page.$_" } @$attributes);
  }
  if( keys %$filters ) {
    $URL .= '&FILTERS='.join('|',map {
      sprintf( '%s.default.filters.%s."%s"',$dataset,$_, CGI::escapeHTML($filters->{$_} ) )
    } keys %$filters );
  }
warn "MART LINK URL: ",$URL;
  return $self->problem( 'redirect', $URL );
}

## family_seq
## attributes ??
## filters ensembl_family
## xref
## attributes chromosome_name,start_position,end_position,strand,gene_ensembl_id,ensembl_transcript_id
## filters (hgnc_..) 

our $configuration = {
  'snp_region' => {
    'dependency' => 'snp',
    'data_set'   => 'snp',
    'attributes' => [qw(chr_name chrom_start refsnp_id)],
    'filters'    => {qw(seq_region_name chr_name start chrom_start end chrom_end)}
  },
  'vega_region' => {
    'dependency' => 'snp',
    'data_set'   => 'gene_vega',
    'attributes' => [qw(chrom_name chrom_start chrom_end chrom_strand gene_stable_id transcript_stable_id)],
    'filters'    => {qw(seq_region_name chr_name start chrom_start end chrom_start)}
  },
  'gene_region' => {
    'data_set'   => 'gene_ensembl',
    'attributes' => [qw(chromosome_name start_position end_position strand ensembl_gene_id ensembl_transcript_id)],
    'filters'    => {qw(seq_region_name chromosome_name start start end end)}
  },
  'family' => {
    'data_set'   => 'gene_ensembl',
    'attributes' => [qw(chromosome_name start_position end_position strand ensembl_gene_id ensembl_transcript_id)],
    'filters'    => {qw(family_id ensembl_family)}
  },
  'familyseq' => {
    'data_set'   => 'gene_ensembl',
    'attributes' => [qw(str_chrom_name gene_stable_id struct_biotype peptide)],
    'filters'    => {qw(family_id ensembl_family)}
  },
  'domain' => {
    'data_set'   => 'gene_ensembl',
    'attributes' => [qw(chromosome_name start_position end_position strand ensembl_gene_id ensembl_transcript_id)],
    'filters'    => {qw(domain_id interpro)}
  },
};

sub createObjects { 
  my $self      = shift;    
  my $option    = $self->param( 'type' );
warn "...$option...";
  my $conf = $configuration->{$option};
  return $self->problem( 'Fata', 'Unknown Link type', 'Could not redirect to mart' ) unless $conf;
  if( $conf->{'dependency'} eq 'snp'  && ! $self->species_defs->databases->{'DATABASE_VARIATION'} ||
      $conf->{'dependency'} eq 'vega' && ! $self->species_defs->databases->{'DATABASE_VEGA'} ) {
    $self->problem( 'fatal', 'Unknown dataset', qq(Do not know about dataset of type "$option" for this species) );
  }
  (my $dataset = lc($self->species)) =~ s/^([a-z])[a-z]+_/$1/;
  if( $self->param('l') ) {
    my($sr,$start,$end) = $self->param('l') =~ /^(\w+):(-?[.\w]+)-([.\w]+)$/;
    if($sr) {
      $self->param('seq_region_name', $sr);
      $self->param('start', $start);
      $self->param('end', $end);
    }
  }
  return $self->_link(
    $dataset.'_'.$conf->{'data_set'},
    $conf->{'attributes'},
    {map { $conf->{'filters'}{$_} => $self->param($_) } keys %{$conf->{'filters'}} }
  );
}

1;
  
