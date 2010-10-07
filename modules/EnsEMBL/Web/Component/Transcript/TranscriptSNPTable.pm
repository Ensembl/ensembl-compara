# $Id$

package EnsEMBL::Web::Component::Transcript::TranscriptSNPTable;

use strict;

use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my @samples;
  
  foreach my $param ($hub->param) {
    if ($param =~ /opt_pop/ && $hub->param($param) eq 'on') {
      $param =~ s/opt_pop_//;
      push @samples, $param;
    }
  }
  
  my $snp_data    = $self->get_page_data(\@samples);
  my $strain_name = $hub->species_defs->translate('strain');
  my %tables;
 
  foreach my $sample (@samples) {
    my $flag  = 0;
    my $table = new EnsEMBL::Web::Document::SpreadSheet([], [], { data_table => 1, sorting => [ 'chr asc' ] });  
  
    $table->add_columns (
      { key => 'ID',          sort => 'html'                                               },
      { key => 'consequence', sort => 'string',   title => 'Type'                          },
      { key => 'chr' ,        sort => 'position', title => 'Chr: bp'                       },
      { key => 'ref_alleles', sort => 'string',   title => 'Ref. allele'                   },
      { key => 'Alleles',     sort => 'string',   title => ucfirst "$strain_name genotype" },
      { key => 'Ambiguity',   sort => 'string',   title => 'Ambiguity'                     },
      { key => 'HGVS',        sort => 'string',   title => 'HGVS name(s)'                  },
      { key => 'Codon',       sort => 'html',     title => 'Transcript codon'              },
      { key => 'cdscoord',    sort => 'numeric',  title => 'CDS coord.'                    },
      { key => 'aachange',    sort => 'string',   title => 'AA change'                     },
      { key => 'aacoord',     sort => 'numeric',  title => 'AA coord.'                     },
      { key => 'Class',       sort => 'string'                                             },
      { key => 'Source',      sort => 'string'                                             },
      { key => 'Status',      sort => 'string',   title => 'Validation'                    }
    );
    
    foreach my $snp_row (sort keys %$snp_data) { 
      foreach my $row (@{$snp_data->{$snp_row}{$sample} || []}) {  
        $flag = 1;
        $table->add_row($row);
      }
    }
    
    $tables{$sample} = $flag ? $table->render : q{
      <p>
        There are no variations in this region in this strain, or the variations have been filtered out by the options set in the page configuration. 
        To change the filtering options select the 'Configure this page' link from the menu on the left hand side of this page.
      </p><br />};
  }
  
  $strain_name .= 's';
  
  my $html;
  
  $html .= "<h2>Variations in $_:</h2>$tables{$_}" for keys %tables;
  
  $html .= $self->_info(
    'Configuring the display',
    sprintf(
      q{<p>These %s are displayed by default:<b> %s.</b>
      <br /> Select the 'Configure this page' link in the left hand menu to customise which %s and types of variation are displayed in the tables above.</p>},
      $strain_name, join(', ', $self->object->get_samples('default')), $strain_name
    )
  );  
  
  return $html;
}

sub get_page_data {
  my ($self, $samples) = @_;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $transcript = $object->Obj;
  my %snp_data;

  foreach my $sample (@$samples) {
    my $munged_transcript = $object->get_munged_slice('tsv_transcript',  $hub->param('context') eq 'FULL' ? 1000 : $hub->param('context'), 1) || warn "Couldn't get munged transcript";
    my $sample_slice      = $munged_transcript->[1]->get_by_strain($sample);

    my ($allele_info, $consequences) = $object->getAllelesConsequencesOnSlice($sample, 'tsv_transcript', $sample_slice);
    
    next unless @$consequences && @$allele_info;
    
    my ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);
    my @coverage_obj = @$raw_coverage_obj ? sort { $a->start <=> $b->start } @$raw_coverage_obj : ();
    my $index        = 0;
    
    foreach my $allele_ref (@$allele_info) {
      my $allele      = $allele_ref->[2];
      my $conseq_type = $consequences->[$index];
      
      $index++;
      
      next unless $conseq_type && $allele;

      # Check consequence obj and allele feature obj have same alleles
      my $tmp        = join '', @{$conseq_type->alleles || []};
      $tmp           =~ tr/ACGT/TGCA/ if $transcript->strand ne $allele->strand;
      my $type       = join ', ', @{$conseq_type->type || []};
      $type         .= ' (Same As Ref. Assembly)' if $type eq 'SARA';
      my $offset     = $sample_slice->strand > 0 ? $sample_slice->start - 1 :  $sample_slice->end + 1;
      my $chr_start  = $allele->start + $offset;
      my $chr_end    = $allele->end   + $offset;
      my $class      = $object->var_class($allele);
      $class         = $chr_start > $chr_end ? 'Insertion' : 'Deletion' if $class eq 'in-del';
      $class         =~ s/snp/SNP/;
      my $codon      = $conseq_type->codon;
      my $chr        = $sample_slice->seq_region_name;
      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $aa_coord   = $conseq_type->aa_start;
      $aa_coord     .= $aa_coord == $conseq_type->aa_end ? "": $conseq_type->aa_end;
      my $cds_coord  = $conseq_type->cds_start;
      $cds_coord    .= '-' . $conseq_type->cds_end unless $conseq_type->cds_start == $conseq_type->cds_end;
      my $sources    = join ', ' , @{$allele->get_all_sources || []};
      my $vid        = $allele->variation_name;
      my $source     = $allele->source;
      my $vf         = $allele->variation->dbID; 
      my $url        = $hub->url({ type => 'Variation', action => 'Summary', v => $vid , vf => $vf, source => $source });
      my $hgvs       = join ', ', values %{$allele->variation_feature->get_all_hgvs_notations($transcript, 'c')}; 
      my ($pos, $status);
      
      if ($chr_end < $chr_start) {
        $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
      } elsif ($chr_end > $chr_start) {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      } else {
        $pos = $chr_start;
      }

      # Codon - make the letter for the SNP position in the codon bold
      if ($codon) {
        my $position = ($conseq_type->cds_start % 3 || 3) - 1;
        $codon =~ s/(\w{$position})(\w)(.*)/$1<b>$2<\/b>$3/;
      }
      
      if (grep $_ eq 'Sanger', @{$allele->get_all_sources || []}) {
        my $allele_start = $allele->start;
        my $coverage;
        
        foreach (@coverage_obj) {
          next if $allele_start > $_->end;
          last if $allele_start < $_->start;
          $coverage = $_->level if $_->level > $coverage;
        }
        
        $coverage = '>' . ($coverage - 1) if $coverage == $coverage_level->[-1];
        $status   = "resequencing coverage $coverage";
      } else {
        my $tmp        = $allele->variation;
        my @validation = $tmp ? @{$tmp->get_all_validation_states || []} : ();
        $status        = join ', ',  @validation;
        $status        =~ s/freq/frequency/;
      }

      # Other
      my $chr = $sample_slice->seq_region_name;
      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $aa_coord = $conseq_type->aa_start;
      $aa_coord .= $aa_coord == $conseq_type->aa_end ? "": $conseq_type->aa_end;
      my $cds_coord = $conseq_type->cds_start;
      $cds_coord .= "-".$conseq_type->cds_end unless $conseq_type->cds_start == $conseq_type->cds_end;
      my $sources = join ", " , @{$allele->get_all_sources || [] };
      my $vid = $allele->variation_name;
      my $source = $allele->source;
      my $vf = $allele->variation->dbID; 
      my $url = $hub->url({'type' => 'Variation', 'action' => 'Summary',  'v' => $vid , 'vf' => $vf, 'source' => $source });
      my @hgvs = values %{$allele->variation_feature->get_all_hgvs_notations($object->transcript, 'c')};
      s/ENS(...)?[TG]\d+(\.\d+)?\://g for @hgvs;
      my $hgvs = join ", ", @hgvs;
      my %hgvs = %{$allele->variation_feature->get_all_hgvs_notations($object->transcript, 'c')};
      
      my $row = {
        ID          => sprintf('<a href="%s">%s</a>', $url, $allele->variation_name),
        Class       => $class                     || '-',
        Source      => $sources                   || '-',
        ref_alleles => $allele->ref_allele_string || '-',
        Alleles     => $allele->allele_string     || '-',
        Ambiguity   => $object->ambig_code($allele),
        HGVS        => $hgvs                      || '-',
        Status      => $status                    || '-',
        chr         => "$chr:$pos",
        Codon       => $codon                     || '-',
        consequence => $type,
        cdscoord    => $cds_coord                 || '-'
      };
 
      if ($conseq_type->aa_alleles) {
        $row->{'aachange'} = join '/', @$aa_alleles || '';
        $row->{'aacoord'}  = $aa_coord;
      } else {
        $row->{'aachange'} = '-';
        $row->{'aacoord'}  = '-';
      }
      
      push @{$snp_data{"$chr:$pos"}{$sample}}, $row;
    }
  }
  
  return \%snp_data;
} 

1;
