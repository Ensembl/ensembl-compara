=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Transcript::PopulationTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $strain_name = $hub->species_defs->translate('strain');
  my ($html, @samples, %tables);
  
  foreach my $param ($hub->param) {
    if ($param =~ /opt_pop/ && $hub->param($param) eq 'on') {
      $param =~ s/opt_pop_//;
      push @samples, $param;
    }
  }
  my $snp_data = $self->get_page_data(\@samples);

  my $columns  = [
    { key => 'ID',          sort => 'html'                                               },
  ];

  if ($hub->param('data_grouping') eq 'by_variant') {
    push @$columns, { key => 'sample', sort => 'string',  title => 'Population'};
  }

  push @$columns,
    { key => 'consequence', sort => 'string',   title => 'Type'                          },
    { key => 'chr' ,        sort => 'position', title => 'Chr: bp'                       },
    { key => 'ref_alleles', sort => 'string',   title => 'Ref. allele'                   },
    { key => 'Alleles',     sort => 'string',   title => ucfirst "$strain_name genotype" },
    { key => 'Ambiguity',   sort => 'string',   title => 'Ambiguity'                     },
    { key => 'Codon',       sort => 'html',     title => 'Transcript codon'              },
    { key => 'cdscoord',    sort => 'numeric',  title => 'CDS coord.'                    },
    { key => 'aachange',    sort => 'string',   title => 'Amino acids'                   },
    { key => 'aacoord',     sort => 'numeric',  title => 'AA coord.'                     },
    { key => 'Class',       sort => 'string'                                             },
    { key => 'Source',      sort => 'string'                                             },
    { key => 'Status',      sort => 'string',   title => 'Validation'                    }
  ;
 
  my $message = '
        <p>
          There are no variations in this region in %s, or the variations have been filtered out by the options set in the page configuration. 
          To change the filtering options select the "Configure this page" link from the menu on the left hand side of this page.
        </p><br />
      ';

  if ($hub->param('data_grouping') eq 'by_variant') {
    $html .= "<h2>Variations in position</h2>";
    my (@rows, @missing);
    foreach my $sample (@samples) {
      my @data = map @{$snp_data->{$_}{$sample} || []}, sort keys %$snp_data;
      if (@data) {
        push @rows, @data;
      }
      else {
        push @missing, $sample;
      }
    }
    if (@missing) {
      $html .= $self->_info('Configuring the display', sprintf($message, join(',', @missing)));
    }

    my $table = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'chr asc', 'ID asc'], data_table_config => {iDisplayLength => 10} })->render;
    $html .= $table;
  }
  else { 
    foreach my $sample (@samples) {
      my @rows = map @{$snp_data->{$_}{$sample} || []}, sort keys %$snp_data;
    
      if (scalar @rows) {      
        $tables{$sample} = $self->new_table($columns, \@rows, { data_table => 1, sorting => [ 'chr asc' ] })->render;
      } else {
        $tables{$sample} = sprintf($message, 'this strain');
      }
    }  
  $html .= "<h2>Variations in $_:</h2>$tables{$_}" for keys %tables;
  }

  $html .= $self->_info('Configuring the display', sprintf('
    <p>These %ss are displayed by default: <b>%s.</b><br />
    Select the "Configure this page" link in the left hand menu to customise which %ss and types of variation are displayed in the tables above.</p>',
    $strain_name, join(', ', $self->object->get_samples('default')), $strain_name
  ));  
  
  return $html;
}

sub get_page_data {
  my ($self, $samples) = @_;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $transcript = $object->Obj;
  my %snp_data;
  
  my $con_format = $hub->param('consequence_format');
  
  my $base_url = $hub->url({
    'type' => 'Variation',
    'action' => 'Summary',
    'v' => undef ,
    'vf' => undef,
    'source' => undef
  });

  foreach my $sample (@$samples) {
    my $munged_transcript = $object->get_munged_slice('tsv_transcript', $hub->param('context') eq 'FULL' ? 1000 : $hub->param('context'), 1) || warn "Couldn't get munged transcript";
    ## Don't assume that a sample ID taken from CGI input is actually present in this species!
    my $sample_slice      = eval { $munged_transcript->[1]->get_by_strain($sample); };

    unless ($@) {
      my ($allele_info, $consequences) = $object->getAllelesConsequencesOnSlice($sample, 'tsv_transcript', $sample_slice);
    
      next unless @$consequences && @$allele_info;
    
      my ($coverage_level, $raw_coverage_obj) = $object->read_coverage($sample, $sample_slice);
      my @coverage_obj = @{$raw_coverage_obj||[]} ? sort { $a->start <=> $b->start } @$raw_coverage_obj : ();
      my $index        = 0;
    
      foreach my $allele_ref (@$allele_info) {
        my $allele      = $allele_ref->[2];
        my $conseq_type = $consequences->[$index];
      
        $index++;
      
        next unless $conseq_type && $allele;
      
        my $cons = $conseq_type->consequence_type($con_format);
        $cons = $conseq_type->consequence_type('label') if $cons->[0] eq '';
      
        my $type       = join ', ', @{$cons || []};
        $type         .= ' (Same As Ref. Assembly)' if $type eq 'SARA';
        my $offset     = $sample_slice->strand > 0 ? $sample_slice->start - 1 :  $sample_slice->end + 1;
        my $chr_start  = $allele->start + $offset;
        my $chr_end    = $allele->end   + $offset;
        my $class      = $allele->variation_feature->var_class();
        my $codons     = $conseq_type->codons;
        my $chr        = $sample_slice->seq_region_name;
        my $aa_alleles = $conseq_type->pep_allele_string;
        my $aa_coord   = $conseq_type->translation_start;
        $aa_coord     .= $aa_coord == $conseq_type->translation_end ? "": $conseq_type->translation_end;
        my $cds_coord  = $conseq_type->cds_start;
        $cds_coord    .= '-' . $conseq_type->cds_end unless $conseq_type->cds_start == $conseq_type->cds_end;
      
        $codons     =~ s/\//\|/g;
        $aa_alleles =~ s/\//\|/g;
      
        my ($pos, $status);
        if ($chr_end < $chr_start) {
          $pos = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
        } elsif ($chr_end > $chr_start) {
         $pos = "$chr_start&nbsp;-&nbsp;$chr_end";
        } else {
          $pos = $chr_start;
        }

        # Codon - make the letter for the SNP position in the codon bold
        if ($codons) {
          my $position = ($conseq_type->cds_start % 3 || 3) - 1;
          $codons =~ s/([ACGT])/<b>$1<\/b>/g;
          $codons =~ tr/acgt/ACGT/;
        }
      
        # read coverage in mouse?
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
      
        # url
        my $vid = $allele->variation_name;
        my $source = $allele->source;
        my $vf = $allele->variation_feature->dbID; 
        my $url = $base_url.qq{;v=$vid;vf=$vf;source=$source};
      
        # source
        #my $sources = join ", " , @{$allele->get_all_sources || [] };
        my $sources = $source;
      
        my $row = {
          ID          => sprintf('<a href="%s">%s</a>', $url, $allele->variation_name),
          Class       => $class                     || '-',
          sample      => $sample,
          Source      => $sources                   || '-',
          ref_alleles => $allele->ref_allele_string || '-',
          Alleles     => $allele->allele_string     || '-',
          Ambiguity   => ambiguity_code($allele->allele_string),
          Status      => $status                    || '-',
          chr         => "$chr:$pos",
          Codon       => $codons                    || '-',
          consequence => $type,
          cdscoord    => $cds_coord                 || '-'
        };
 
        if ($aa_alleles) {
          $row->{'aachange'} = $aa_alleles;
          $row->{'aacoord'}  = $aa_coord;
        } else {
          $row->{'aachange'} = '-';
          $row->{'aacoord'}  = '-';
        } 

        push @{$snp_data{"$chr:$pos"}{$sample}}, $row;
      }
    }
  }
  return \%snp_data;
} 

1;
