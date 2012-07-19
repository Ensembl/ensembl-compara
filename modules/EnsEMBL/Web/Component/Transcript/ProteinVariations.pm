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
  my $show_scores = $hub->param('show_scores');
  my @data;
  
  foreach my $snp (@{$object->variation_data}) {
    #next unless $snp->{'allele'};
    
    my $codons = $snp->{'codons'} || '-';
    
    if ($codons ne '-') {
      if (length($codons)>25) {
        my $display_codons = substr($codons,0,25).'...';
           $display_codons =~ s/([ACGT])/<b>$1<\/b>/g;
           $display_codons =~ tr/acgt/ACGT/;
           $codons =~ tr/acgt/ACGT/;
            $display_codons .= $self->trim_large_string($codons,'codons_'.$snp->{'snp_id'});
        $codons = $display_codons;
      }
      else {
        $codons =~ s/([ACGT])/<b>$1<\/b>/g;
         $codons =~ tr/acgt/ACGT/;
      }
    }
    my $allele = $snp->{'allele'};
    my $tva    = $snp->{'tva'};
    my $var_allele = $tva->variation_feature_seq;
    
    # Check allele size (for display issues)
    if (length($allele)>20) {
      my $display_allele = $self->trim_large_allele_string($allele,'allele_'.$snp->{'snp_id'},20);
      $allele = $display_allele;
    }
    $allele =~ s/$var_allele/<b>$var_allele<\/b>/ if $allele =~ /\//;
    
    # consequence type
    my $type;
    
    if($cons_format eq 'so') {
      $type = join ", ", map {$hub->get_ExtURL_link($_->label, 'SEQUENCE_ONTOLOGY', $_->SO_accession)} @{$tva->get_all_OverlapConsequences};
    }
    
    else {
      # Avoid duplicated Ensembl terms
      my %ens_term = map { '<span title="'.$_->description.'">'.$_->display_term.'</span>' => 1 } @{$tva->get_all_OverlapConsequences};
      $type = join ', ', keys(%ens_term);
    }
    
    push @data, {
      res    => $snp->{'position'},
      id     => sprintf('<a href="%s">%s</a>', $hub->url({ type => 'Variation', action => 'Mappings', v => $snp->{'snp_id'}, vf => $snp->{'vdbid'}, vdb => 'variation' }), $snp->{'snp_id'}),
      type   => $type,
      allele => $allele,
      ambig  => $snp->{'ambigcode'} || '-',
      alt    => $snp->{'pep_snp'} || '-',
      codons => $codons,
      sift   => $self->render_sift_polyphen($tva->sift_prediction, $tva->sift_score),
      poly   => $self->render_sift_polyphen($tva->polyphen_prediction, $tva->polyphen_score),
    };
  }
  
  my $columns = [
    { key => 'res',    title => 'Residue',            width => '5%',  sort => 'numeric' },
    { key => 'id',     title => 'Variation ID',       width => '10%', sort => 'html'    }, 
    { key => 'type',   title => 'Variation type',     width => '20%', sort => 'string'  },
    { key => 'allele', title => 'Alleles',            width => '10%', sort => 'string'  },
    { key => 'ambig',  title => 'Ambiguity code',     width => '5%',  sort => 'string'  },
    { key => 'alt',    title => 'Residues',           width => '10%', sort => 'string'  },
    { key => 'codons', title => 'Codons',             width => '10%', sort => 'string'  },
  ];
  
  push @$columns, (
    { key => 'sift',   title => 'SIFT',               width => '15%', align => 'center', sort => 'position_html'  },
    { key => 'poly',   title => 'PolyPhen',           width => '15%', align => 'center', sort => 'position_html'  }
  ) if $hub->species =~ /homo_sapiens/i;
  
  my $html = $self->new_table($columns, \@data, { data_table => 1, sorting => [ 'res asc' ] })->render;
  
  $html .= $self->_info('Information','<p><span style="color:red;">*</span> SO terms are shown when no NCBI term is available</p>', '50%') if $cons_format eq 'ncbi';
  
  return $html;
}

1;

