# $Id$

package EnsEMBL::Web::Component::Transcript::ProteinVariations;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

use Bio::EnsEMBL::Variation::ConsequenceType;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;
  
  return $self->non_coding_error unless $object->translation_object;

  my $hub    = $self->hub;
  my %labels = %Bio::EnsEMBL::Variation::ConsequenceType::CONSEQUENCE_LABELS;
  my @data;
  
  foreach my $snp (@{$object->variation_data}) {
    next unless $snp->{'allele'};
    
    my $codons = $snp->{'codons'} || '-';
    
    if ($codons ne '-') {
      $codons =~ s/[ACGT]/'<b>'.$&.'<\/b>'/eg;
      $codons =~ tr/acgt/ACGT/;
    }
    
    push @data, {
      res    => $snp->{'position'},
      id     => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Variation', action => 'Summary', v => $snp->{'snp_id'}, vf => $snp->{'vdbid'}, vdb => 'variation' }), $snp->{'snp_id'}),
      type   => $labels{$snp->{'type'}},
      allele => $snp->{'allele'},
      ambig  => $snp->{'ambigcode'} || '-',
      alt    => $snp->{'pep_snp'} || '-',
      codons => $codons
    };
  }
  
  return $self->new_table([
    { key => 'res',    title => 'Residue',            width => '10%', align => 'center', sort => 'numeric' },
    { key => 'id',     title => 'Variation ID',       width => '10%', align => 'center', sort => 'html'    }, 
    { key => 'type',   title => 'Variation type',     width => '20%', align => 'center', sort => 'string'  },
    { key => 'allele', title => 'Alleles',            width => '15%', align => 'center', sort => 'string'  },
    { key => 'ambig',  title => 'Ambiguity code',     width => '15%', align => 'center', sort => 'string'  },
    { key => 'alt',    title => 'Alternate residues', width => '15%', align => 'center', sort => 'string'  },
    { key => 'codons', title => 'Alternate codons',   width => '15%', align => 'center', sort => 'string'  }
  ], \@data, { data_table => 1, sorting => [ 'res asc' ] })->render;
}

1;

