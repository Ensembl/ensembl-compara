package EnsEMBL::Web::Component::Transcript::TranscriptSNPTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

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
  my $object = $self->object;
  my @samples;
  foreach my $param ( $object->param() ) {
    if ($param =~/opt_pop/){ 
      if ($object->param($param) eq 'on' ) {
        $param =~s/opt_pop_//;
        push (@samples, $param);
      }
    }
  }
  my $snp_data = get_page_data($object, \@samples);
  my $strain_name = $object->species_defs->translate("strain");
  my %tables;
 
  foreach my $sample (@samples) {
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px' } );  
  
    $table->add_columns (
      { 'key' => 'ID',  },
      { 'key' => 'consequence', 'title' => 'Type', },
      { 'key' => 'chr' ,        'title' => "Chr: bp" },
      { 'key' => 'ref_alleles',  'title' => 'Ref. allele', },
      { 'key' => 'Alleles',     'title' => ucfirst($strain_name)." genotype", },
      { 'key' => 'Ambiguity',   'title' => 'Ambiguity',  },
      { 'key' => 'Codon',       'title' => "Transcript codon" ,  },
      { 'key' => 'cdscoord',  'title' => 'CDS coord.',  },
      { 'key' => 'aachange', 'title' => 'AA change',  },
      { 'key' => 'aacoord',  'title' => 'AA coord.',  },
      #{ 'key' => 'coverage',  'title' => 'Read coverage',  },
      { 'key' => 'Class', },
      { 'key' => 'Source', },
      { 'key' => 'Status', 'title' => 'Validation',  },
    );
    foreach my $snp_row (sort keys %$snp_data) {
      foreach my $row ( @{$snp_data->{$snp_row}{$sample} || [] } ) {
        $table->add_row($row);
      }
    }
    $tables{$sample} = $table->render; 
  }

  my $html;
  foreach (keys %tables){
  $html .= "<p><h2>Variations in $_: </h2><p> $tables{$_}";
  }  
  return $html;
}

sub get_page_data {
  my ($object, $samples) = @_;
  my %snp_data;

  foreach my $sample ( @$samples ) {
    my $munged_transcript = $object->get_munged_slice("tsv_transcript",  tsv_extent($object), 1 ) || warn "Couldn't get munged transcript";
    my $sample_slice = $munged_transcript->[1]->get_by_strain( $sample );

    my ( $allele_info, $consequences ) = $object->getAllelesConsequencesOnSlice($sample, "tsv_transcript", $sample_slice);
    next unless @$consequences && @$allele_info;

    my ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);

    my @coverage_obj;
    if ( @$raw_coverage_obj ){
      @coverage_obj = sort {$a->start <=> $b->start} @$raw_coverage_obj;
    }
    my $index = 0;
    foreach my $allele_ref (  @$allele_info ) {
      my $allele = $allele_ref->[2];
      my $conseq_type = $consequences->[$index];
      $index++;
      next unless $conseq_type && $allele;

      # Check consequence obj and allele feature obj have same alleles
      my $tmp = join "", @{$conseq_type->alleles || []};
      $tmp =~ tr/ACGT/TGCA/ if ( $object->Obj->strand ne $allele->strand);

      # Type
      my $type = join ", ", @{$conseq_type->type || []};
      if ($type eq 'SARA') {
        $type .= " (Same As Ref. Assembly)";
      }

      # Position
      my $offset = $sample_slice->strand > 0 ? $sample_slice->start - 1 :  $sample_slice->end + 1;
      my $chr_start = $allele->start() + $offset;
      my $chr_end   = $allele->end() + $offset;
      my $pos =  $chr_start;
      if( $chr_end < $chr_start ) {
        $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
      } elsif($chr_end > $chr_start ) {
        $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
      }

      # Class
      my $class = $object->var_class($allele);
      if ($class eq 'in-del') {
        $class = $chr_start > $chr_end ? 'Insertion' : 'Deletion';
      }
      $class =~ s/snp/SNP/;

      # Codon - make the letter for the SNP position in the codon bold
      my $codon = $conseq_type->codon;
      if ( $codon ) {
        my $position = ($conseq_type->cds_start % 3 || 3) - 1;
        $codon =~ s/(\w{$position})(\w)(.*)/$1<b>$2<\/b>$3/;
      }

      my $status;
      if ( grep { $_ eq "Sanger"} @{$allele->get_all_sources() || []} ) {
        my $allele_start = $allele->start;
        my $coverage;
        foreach ( @coverage_obj ) {
          next if $allele_start >  $_->end;
          last if $allele_start < $_->start;
          $coverage = $_->level if $_->level > $coverage;
        }
        $coverage = ">".($coverage-1) if $coverage == $coverage_level->[-1];
        $status = "resequencing coverage $coverage";
      } else {
        my $tmp =  $allele->variation;
        my @validation = $tmp ? @{ $tmp->get_all_validation_states || [] } : ();
        $status = join( ', ',  @validation ) || "-";
        $status =~ s/freq/frequency/;
      }

      # Other
      my $chr = $sample_slice->seq_region_name;

      my $aa_alleles = $conseq_type->aa_alleles || [];
      my $aa_coord = $conseq_type->aa_start;
      $aa_coord .= $aa_coord == $conseq_type->aa_end ? "": $conseq_type->aa_end;
      my $cds_coord = $conseq_type->cds_start;
      $cds_coord .= "-".$conseq_type->cds_end unless $conseq_type->cds_start == $conseq_type->cds_end;
      my $sources = join ", " , @{$allele->get_all_sources || [] };

      my $row = {
        'ID'          =>  qq(<a href="/@{[$object->species]}/Variation/Summary?v=@{[$allele->variation_name]};source=@{[$allele->source]};">@{[$allele->variation_name]}</a>),
        'Class'       => $class || "-",
        'Source'      => $sources || "-",
        'ref_alleles' => $allele->ref_allele_string || "-",
        'Alleles'     => $allele->allele_string || "-",
        'Ambiguity'   => $object->ambig_code($allele),
        'Status'      => $status,
        'chr'         => "$chr:$pos",
        'Codon'       => $codon || "-",
        'consequence' => $type,
        'cdscoord'    => $cds_coord || "-",
        #'coverage'    => $coverage || "0",
      };
 
      if ($conseq_type->aa_alleles){
        $row->{'aachange'} = ( join "/", @{$aa_alleles} ) || "";
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

sub tsv_extent {
  my $object = shift;
   return $object->param( 'context' ) eq 'FULL' ? 1000 :$object->param( 'context' );
}

1;
