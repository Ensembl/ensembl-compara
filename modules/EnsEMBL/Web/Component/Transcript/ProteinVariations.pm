# $Id$

package EnsEMBL::Web::Component::Transcript::ProteinVariations;

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

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
  my $cons_format = $hub->param('consequence_format');
  my @data;
  
  foreach my $snp (@{$object->variation_data}) {
    next unless $snp->{'allele'};
    
    my $codons = $snp->{'codons'} || '-';
    
    if ($codons ne '-') {
      $codons =~ s/[ACGT]/'<b>'.$&.'<\/b>'/eg;
      $codons =~ tr/acgt/ACGT/;
    }
    
    my $allele = $snp->{'allele'};
    my $tva    = $snp->{'tva'};
    my $var_allele = $tva->variation_feature_seq;
    
    $allele =~ s/(.{20})/$1\n/g;
    $allele =~ s/$var_allele/<b>$&<\/b>/ if $allele =~ /\//;
    
    # consequence type
    my $type;
    
    if($cons_format eq 'so') {
      $type = join ", ", map {$hub->get_ExtURL_link($_->SO_term, 'SEQUENCE_ONTOLOGY', $_->SO_accession)} @{$tva->get_all_OverlapConsequences};
    }
    
    elsif($cons_format eq 'ncbi') {
      # not all terms have an ncbi equiv so default to SO
      $type = join ", ", map {$_->NCBI_term || $hub->get_ExtURL_link($_->SO_term, 'SEQUENCE_ONTOLOGY', $_->SO_accession).'<span style="color:red;">*</span>'} @{$tva->get_all_OverlapConsequences};
    }
    
    else {
      $type = join ", ", map{'<span title="'.$_->description.'">'.$_->label.'</span>'} @{$tva->get_all_OverlapConsequences};
    }
    
    push @data, {
      res    => $snp->{'position'},
      id     => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Variation', action => 'Summary', v => $snp->{'snp_id'}, vf => $snp->{'vdbid'}, vdb => 'variation' }), $snp->{'snp_id'}),
      type   => $type,
      allele => $allele,
      ambig  => $snp->{'ambigcode'} || '-',
      alt    => $snp->{'pep_snp'} || '-',
      codons => $codons
    };
  }
  
  my $html = $self->new_table([
    { key => 'res',    title => 'Residue',            width => '10%', align => 'center', sort => 'numeric' },
    { key => 'id',     title => 'Variation ID',       width => '10%', align => 'center', sort => 'html'    }, 
    { key => 'type',   title => 'Variation type',     width => '20%', align => 'center', sort => 'string'  },
    { key => 'allele', title => 'Alleles',            width => '15%', align => 'center', sort => 'string'  },
    { key => 'ambig',  title => 'Ambiguity code',     width => '15%', align => 'center', sort => 'string'  },
    { key => 'alt',    title => 'Alternate residues', width => '15%', align => 'center', sort => 'string'  },
    { key => 'codons', title => 'Alternate codons',   width => '15%', align => 'center', sort => 'string'  }
  ], \@data, { data_table => 1, sorting => [ 'res asc' ] })->render;
  
  $html .= $self->_info('Information','<p><span style="color:red;">*</span> SO terms are shown when no NCBI term is available</p>', '50%') if $cons_format eq 'ncbi';
  
  return $html;
}

1;

