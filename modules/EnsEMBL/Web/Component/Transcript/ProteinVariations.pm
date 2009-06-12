package EnsEMBL::Web::Component::Transcript::ProteinVariations;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Document::SpreadSheet;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  return $self->non_coding_error unless $object->translation_object;

  my $snps = $object->translation_object->pep_snps();
  return unless @$snps;
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    { 'key' => 'res',    'title' => 'Residue',            'width' => '10%', 'align' => 'center' },
    { 'key' => 'id',     'title' => 'Variation ID',             'width' => '15%', 'align' => 'center' }, 
    { 'key' => 'type',   'title' => 'Variation type',           'width' => '20%', 'align' => 'center' },
    { 'key' => 'allele', 'title' => 'Alleles',            'width' => '20%', 'align' => 'center' },
    { 'key' => 'ambig',  'title' => 'Ambiguity code',     'width' => '15%', 'align' => 'center' },
    { 'key' => 'alt',    'title' => 'Alternate residues', 'width' => '20%', 'align' => 'center' }
  );

  my $counter = 0;
  foreach my $residue (@$snps){
    $counter++;
    next if !$residue->{'allele'};
    my $type = $residue->{'type'} eq 'snp' ? "Non-synonymous" : ($residue->{'type'} eq 'syn' ? 'Synonymous': ucfirst($residue->{'type'}));
    my $snp_id = $residue->{'snp_id'};
    my $source = $residue->{'snp_source'} ? ";source=".$residue->{'snp_source'} : "";
    my $vf = $residue->{'vdbid'}; 
    my $url = $object->_url({'type' => 'Variation', 'action' => 'Summary', 'v' => $snp_id, 'vf' => $vf, 'vdb' => 'variation'});
    $table->add_row({
     'res'     => $counter,
     'id'      => qq(<a href = $url>$snp_id</a>),
     'type'    => $type,
     'allele'  => $residue->{'allele'},
     'ambig'   => join('', @{$residue->{'ambigcode'}||[]}),
     'alt'     => $residue->{'pep_snp'} ? $residue->{'pep_snp'} : '-',
     'LDview'  => qq(<a href="/@{[$object->species]}/ldview?snp=$snp_id$source">$snp_id</a>),
    });
  }
  return $table->render;
}

1;

