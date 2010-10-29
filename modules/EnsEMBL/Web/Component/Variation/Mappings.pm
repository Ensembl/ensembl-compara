# $Id$

package EnsEMBL::Web::Component::Variation::Mappings;

use strict;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self = shift;
  my $object = $self->object;

  # first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;

  my %mappings = %{$object->variation_feature_mapping};

  return [] unless keys %mappings;

  my $hub    = $self->hub;
  my $source = $object->source;
  my $name   = $object->name;
 
  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'gene asc', 'trans asc' ] });
  
  $table->add_columns(
    { key => 'gene',      title => 'Gene',                   sort => 'html'                        },
    { key => 'trans',     title => 'Transcript (strand)',    sort => 'html'                        },
    { key => 'type',      title => 'Type'  ,                 sort => 'string'                      },
    { key => 'hgvs',      title => 'HGVS names'  ,           sort => 'string'                      },     
    { key => 'trans_pos', title => 'Position in transcript', sort => 'position', align => 'center' },
    { key => 'prot_pos',  title => 'Position in protein',    sort => 'position', align => 'center' },
    { key => 'aa',        title => 'Amino acid',             sort => 'string'                      },
    { key => 'codon',     title => 'Codon',                  sort => 'string'                      },
  );
  
  my $gene_adaptor  = $hub->get_adaptor('get_GeneAdaptor');
  my $trans_adaptor = $hub->get_adaptor('get_TranscriptAdaptor');
  my $flag;
  
  foreach my $varif_id (grep $_ eq $hub->param('vf'), keys %mappings) {
    foreach my $transcript_data (@{$mappings{$varif_id}{'transcript_vari'}}) {
      my $gene       = $gene_adaptor->fetch_by_transcript_stable_id($transcript_data->{'transcriptname'}); 
      my $gene_name  = $gene ? $gene->stable_id : '';
      my $trans_name = $transcript_data->{'transcriptname'};
      my $trans      = $trans_adaptor->fetch_by_stable_id($trans_name);
      
      my $gene_url = $hub->url({
        type   => 'Gene',
        action => 'Variation_Gene/Table',
        db     => 'core',
        r      => undef,
        g      => $gene_name,
        v      => $name,
        source => $source
      });
      
      my $transcript_url = $hub->url({
        type   => 'Transcript',
        action => $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
        db     => 'core',
        r      => undef,
        t      => $trans_name,
        v      => $name,
        source => $source
      });
      
      # HGVS
      my @vfs = grep $_->dbID eq $varif_id, @{$object->Obj->get_all_VariationFeatures};
      my $vf  = $vfs[0];
      
      # get HGVS notations
      my $hgvs;
      
      unless ($object->is_somatic_with_different_ref_base){ 
        my %cdna_hgvs = %{$vf->get_all_hgvs_notations($trans, 'c')};
        my %pep_hgvs  = %{$vf->get_all_hgvs_notations($trans, 'p')};
      
        # filter peptide ones for synonymous changes
        #map {delete $pep_hgvs{$_} if $pep_hgvs{$_} =~ /p\.\=/} keys %pep_hgvs;
      
        my %by_allele;
      
        # group by allele
        push @{$by_allele{$_}}, $cdna_hgvs{$_} foreach keys %cdna_hgvs;
        push @{$by_allele{$_}}, $pep_hgvs{$_}  foreach keys %pep_hgvs;
      
        my $allele_count = scalar keys %by_allele;
      
        my @temp;
        
        foreach my $a(keys %by_allele) {
          foreach my $h (@{$by_allele{$a}}) {
            push @temp, $h . ($allele_count > 1 ? " <b>($a)</b>" : '');
          }
        }
      
        $hgvs = join '<br />', @temp;
      }

      # Now need to add to data to a row, and process rows somehow so that a gene ID is only displayed once, regardless of the number of transcripts;
      
      my $codon = $transcript_data->{'codon'} || '-';
      
      if ($codon ne '-') {
        $codon =~ s/[ACGT]/'<b>'.$&.'<\/b>'/eg;
        $codon =~ tr/acgt/ACGT/;
      }
      
      my $strand = $trans->strand;
      
      my $row = {
        gene      => qq{<a href="$gene_url">$gene_name</a>},
        trans     => qq{<a href="$transcript_url">$trans_name</a> ($strand)},
        type      => $transcript_data->{'conseq'},
        hgvs      => $hgvs || '-',
        trans_pos => $self->_sort_start_end($transcript_data->{'cdna_start'},        $transcript_data->{'cdna_end'}),
        prot_pos  => $self->_sort_start_end($transcript_data->{'translation_start'}, $transcript_data->{'translation_end'}),
        aa        => $transcript_data->{'pepallele'} || '-',
        codon     => $codon
      };
      
      $table->add_row($row);
      $flag = 1;
    }
  }

  if ($flag) { 
    return $table->render;
  } else { 
    return $self->_info('', '<p>This variation has not been mapped any Ensembl genes or transcripts</p>');
  }
}

# Mapping_table
# Arg1     : start and end coordinate
# Example  : $coord = _sort_star_end($start, $end)_
# Description : Returns $start-$end if they are defined, else 'n/a'
# Returns  string
sub _sort_start_end {
  my ($self, $start, $end) = @_;
  
  if ($start || $end) {
    return "$start-$end";
  } else {
    return '-';
  };
}

1;
