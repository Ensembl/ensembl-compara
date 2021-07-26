=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Constants;

### A repository for various site-wide configuration options,
### typically those that are too complex to be captured in
### .ini files

### Not an instantiated object, simply a collection of methods
### that return unblessed data structures


use strict;
use warnings;
no warnings 'uninitialized';

sub RENDERERS {
### Master set of renderers for all formats
  return {
    'pvalue' => {'renderers' => ['signal', 'Wiggle plot', 'gradient', 'P-value'],
                  'default'  => 'gradient'},
  }

}

sub SEARCH_CONFIG {
### Configuration options for the large search box, depending on context
  return {
    'home' => {
                'header'        => 'Search',
                'form_classes'  => [qw(homepage-search-form no-sel)],
                'show_species'  => 1,
                'search_prompt' => ' ', ## leave blank for now
              },
    'help' => {
                'form_classes'  => [qw(no-sel no-ac)],
                'sample_data'   => ['biotype', 'API tutorial', 'citing Ensembl'],
                'search_prompt' => 'Search help and documentation&hellip;',
                'is_encoded'    => 1,
              },
    'species' => {
                'is_encoded'      => 1,
                'inline'          => 1,
              },
  };
}


sub ICON_MAPPINGS {
### Metadata for the icons that appear on the configuration bar
### attached to images
  my $component = shift || 'page';
  
  return {
    'config'        => { 'file' => 'setting.png',         'alt' => 'config',      'title' => "Configure this $component"          },
    'search'        => { 'file' => 'search.png',          'alt' => 'search',      'title' => "Search this $component"             },
    'download'      => { 'file' => 'download.png',        'alt' => 'download',    'title' => "Download data from this $component" },
    'image'         => { 'file' => 'picture.png',         'alt' => 'image',       'title' => "Export this image"                  },
    'userdata'      => { 'file' => 'page-user.png',       'alt' => 'data',        'title' => "Custom tracks"                      },
    'share'         => { 'file' => 'share.png',           'alt' => 'share',       'title' => "Share this $component"              },
    'reset_config'  => { 'file' => 'settings-reset.png',  'alt' => 'reset config','title' => "Reset configuration"                },
    'reset_order'   => { 'file' => 'order-reset.png',     'alt' => 'reset order', 'title' => "Reset track order"                  },
    'resize'        => { 'file' => 'image_resize.png',    'alt' => 'resize image','title' => "Resize this image"                  },
  };
}

sub USERDATA_FORMATS {
  return {
    'bam'         => {'ext' => 'bam',     'label' => 'BAM',       'display' => 'graph',   'limit' => 'remote'},
    'bcf'         => {'ext' => 'bcf',     'label' => 'BCF',       'display' => 'graph',   'limit' => 'remote'},
    'bed'         => {'ext' => 'bed',     'label' => 'BED',       'display' => 'feature'},
    'bedgraph'    => {'ext' => 'bed',     'label' => 'bedGraph',  'display' => 'graph'},
    'bigbed'      => {'ext' => 'bb',      'label' => 'BigBed',    'display' => 'graph',   'limit' => 'remote'},
    'bigpsl'      => {'ext' => 'bb',      'label' => 'BigPsl',    'display' => 'graph',   'limit' => 'remote'},
    'bigint'      => {'ext' => 'bb',      'label' => 'BigInteract',    'display' => 'graph',   'limit' => 'remote'},
    'bigwig'      => {'ext' => 'bw',      'label' => 'BigWig',    'display' => 'graph',   'limit' => 'remote'},
    'cram'        => {'ext' => 'cram',    'label' => 'CRAM',      'display' => 'graph',   'limit' => 'remote'},
    'gff3'        => {'ext' => 'gff3',    'label' => 'GFF3',      'display' => 'feature'},
    'gtf'         => {'ext' => 'gff|gtf', 'label' => 'GFF2/GTF',  'display' => 'feature'},
    'pairwise'    => {'ext' => 'txt',     'label' => 'Pairwise interactions', 'display' => 'feature'},
    'psl'         => {'ext' => 'psl',     'label' => 'PSL',       'display' => 'feature'},
    'trackhub'    => {'ext' => 'txt',     'label' => 'Track Hub', 'display' => 'graph',   'limit' => 'remote'},
    'vcf'         => {'ext' => 'vcf',     'label' => 'VCF',       'display' => 'graph'},
    'vep_output'  => {'ext' => 'txt',     'label' => 'VEP',       'display' => 'feature'},
    'wig'         => {'ext' => 'wig',     'label' => 'WIG',       'display' => 'graph'},
  };
}

sub IMAGE_EXPORT_FORMATS {
### Metadata for image export formats
  return (
	  'png'  => { 'name' => 'PNG', 'extn' => 'png', 'type' => 'raster', 'mime' => 'image/png'        },
	  'svg'  => { 'name' => 'SVG', 'extn' => 'svg', 'type' => 'vector', 'mime' => 'image/svg+xml'    },
	  'pdf'  => { 'name' => 'PDF', 'extn' => 'pdf', 'type' => 'vector', 'mime' => 'application/pdf'  },
  );
}

sub IMAGE_EXPORT_PRESETS {
## Metadata for preset image export - format, size, etc
  return {
          'journal'   => {'label'     => 'Journal/report',
                          'desc'      => 'High resolution, suitable for printing at A4/letter size',
                          'info'      => '<ul><li>PNG</li><li>2000px wide</li><li>2x resolution</li><li>Darker colours</li></ul>',
                          'format'    => 'png',
                          'size'      => '1000',
                          'scale'     => '2',
                          'contrast'  => 2,
                          'order'     => 4,
                          },
          'poster'    => {'label'     => 'Poster',
                          'desc'      => 'Very high resolution, suitable for posters and other large print uses',
                          'info'      => '<ul><li>PNG</li><li>5000px wide</li><li>5x resolution</li><li>Darker colours</li></ul>',
                          'format'    => 'png',
                          'size'      => '1000',
                          'scale'     => '5',
                          'contrast'  => 2,
                          'order'     => 3,
                          },
          'projector' => {'label'     => 'Presentation',
                          'desc'      => 'Saturated image, better suited to projectors',
                          'info'      => '<ul><li>PNG</li><li>1200px wide</li><li>Standard resolution</li><li>Darker colours</li></ul>',
                          'format'    => 'png',
                          'size'      => '1200',
                          'scale'     => '1.00',
                          'contrast'  => 2,
                          'order'     => 2,
                          },
          'png'       => {'label'     => 'Web',
                          'desc'      => 'Standard image, suitable for web pages, blog posts, etc.',
                          'info'      => '<ul><li>PNG</li><li>Same size, resolution and colours as original image</li></ul>',
                          'format'    => 'png',
                          'order'     => 5,
                          },
          'pdf'       => {'label'     => 'PDF file',
                          'desc'      => 'Standard image as PDF file',
                          'format'    => 'pdf',
                          'order'     => 1,
                          },
          'custom'    => {'label'     => 'Custom image',
                          'desc'      => 'Select from a range of formats and sizes',
                          'order'     => 6,
                          },
        };
}

sub FASTA_OPTIONS {
  return  (
        { 'value' => 'cdna',       'caption' => 'cDNA (transcripts)'},
        { 'value' => 'coding',     'caption' => 'Coding sequences (CDS)'},
        { 'value' => 'peptide',    'caption' => 'Amino acid sequences'},
        { 'value' => 'utr5',       'caption' => "5' UTRs"},
        { 'value' => 'utr3',       'caption' => "3' UTRs"},
        { 'value' => 'exon',       'caption' => 'Exons'},
        { 'value' => 'intron',     'caption' => 'Introns'},
        { 'value' => 'sequence',   'caption' => 'Genomic sequence'},
  );
}

sub GENE_JOIN_TYPES {
### Another compara lookup, this time for orthologues,
### paralogues, etc
  return {
    'ortholog_one2one'          => 'orthologue',
    'ortholog_one2many'         => 'orthologue_multi',
    'ortholog_many2many'        => 'orthologue_multi',
    'within_species_paralog'    => 'paralogue',
    'other_paralog'             => 'paralogue',
    'alt_allele'                => 'projection',
    'gene_split'                => 'hidden',
    # last seen in e73
    'apparent_ortholog_one2one' => 'orthologue',
    'possible_ortholog'         => 'possible_ortholog',
    'projection_unchanged'      => 'projection',
    'putative_gene_split'       => 'hidden',
    'contiguous_gene_split'     => 'hidden',
    # last seen a long long time ago (before e60)
    'UBRH'                      => 'orthologue',
    'BRH'                       => 'orthologue',
    'MBRH'                      => 'orthologue',
    'RHS'                       => 'orthologue',
    'between_species_paralog'   => 'paralogue',
  }
}

sub ALIGNMENT_FORMATS {
### Metadata for alignment export formats
  return (
    'fasta'     => 'FASTA',
    'msf'       => 'MSF',
    'clustalw'  => 'CLUSTAL',
    'selex'     => 'Selex',
    'pfam'      => 'Pfam',
    'mega'      => 'Mega',
    'nexus'     => 'Nexus',
    'phylip'    => 'Phylip',
    'psi'       => 'PSI',
    'stockholm' => 'Stockholm',
  );
}
sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub TREE_FORMATS {
### Metadata for tree export formats
  return (
    'text' => { 
      'caption'    => 'Text dump', 
      'method'     => 'string_tree', 
      'parameters' => [ 'scale' ] 
     },
    'newick' => { 
      'caption'    => 'Newick', 
      'method'     => 'newick_format', 
      'parameters' => [ 'newick_mode' ], 
      'split'      => ',', 
      'link'       => 'http://en.wikipedia.org/wiki/Newick_format'
     },
    'nhx' => { 
      'caption'    => 'New Hampshire eXtended (NHX)', 
      'method'     => 'nhx_format', 
      'parameters' => [ 'nhx_mode' ], 
      'split'      => ',', 
      'link'       => 'http://www.phylosoft.org/forester/NHX.html'
    }
  );
}

sub NHX_OPTIONS {
### Extended metadata for NHX (Phylip) format
  return (
    'full'                    => 'Full mode',
    'protein_id'              => 'Protein ID',
    'transcript_id'           => 'Transcript ID',
    'gene_id'                 => 'Gene ID',
    'display_label'           => 'Display label',
    'display_label_composite' => 'Display label composite',
    'simple'                  => 'Simple',
    'phylip'                  => 'PHYLIP',
  );
}

sub NEWICK_OPTIONS {
### Extended metadata for Newick format
  return (
    'full'                    => 'Full',
    'full_common'             => 'Full (common)',
    'int_node_id'             => 'Int node id',
    'display_label_composite' => 'Display label composite',
    'full_web'                => 'Full (web)',
    'gene_stable_id'          => 'Gene ID',
    'otu_id'                  => 'OTU ID',
    'simple'                  => 'Simple',
    'species'                 => 'Species',
    'species_short_name'      => 'Short species name',
    'ncbi_taxon'              => 'NCBI taxon',
    'ncbi_name'               => 'NCBI name',
    'phylip'                  => 'PHYLIP',
  );
}

sub FAMILY_EXTERNAL {
### Metadata for protein family sources
  return (
    'swissprot' => { 'name' => 'UniProt/Swiss-Prot' , 'key' => 'Uniprot/SWISSPROT' },
    'trembl'    => { 'name' => 'UniProt/TrEMBL',      'key' => 'Uniprot/SPTREMBL'  }
  );
}



sub MARKUP_OPTIONS {
### Configuration for text sequence displays
  return {
  ### TEXT SEQUENCE MARKUP
    'exons' => {
      'type'    => 'Checkbox',
      'name'    => 'exons',
      'label'   => 'Show exons',
      'value'   => 'on',
      'checked' => 'checked',
    },
    'exons_only' => {
      type  => 'CheckBox',
      label => 'Show exons only',
      name  => 'exons_only',
      value => 'on',
    },
    'exons_case' => {
      type  => 'CheckBox',
      label => 'Show exons as alternating upper/lower case',
      name  => 'exons_case',
      value => 'on',
    },
    'line_numbering' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'line_numbering',
      'label'  => 'Line numbering',
      'values' => [
        { 'value' => 'sequence', 'caption' => 'Relative to this sequence'      },
        { 'value' => 'slice',    'caption' => 'Relative to coordinate systems' },
        { 'value' => 'off',      'caption' => 'None'                           },
      ]
    },
    'exon_ori' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'exon_ori',
      'label'  => 'Orientation of additional exons',
      'values' => [
        { 'value' => 'fwd', 'caption' => 'Display same orientation exons only'    },
        { 'value' => 'rev', 'caption' => 'Display reverse orientation exons only' },
        { 'value' => 'all', 'caption' => 'Display exons in both orientations'     },
      ],
    },
    'pop_filter' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'population_filter',
      'label'  => 'Filter variants by population',
      'notes'  => 'Warning: This could cause the page to take a long time to load',
      'values' => [{ 'value' => 'off', 'caption' => 'None' }]
    },
    'pop_min_freq' => {
      'type'  => 'NonNegFloat', 
      'label' => 'Minor allele frequency for population filter',  
      'name'  => 'min_frequency',
      'max'   => 0.5
    },
    'consequence_filter' => {
      'type'     => 'DropDown',
      'multiple' => 1,
      'size'     => 5,
      'select'   => 'select',
      'name'     => 'consequence_filter',
      'label'    => 'Filter variants by consequence type',
      'values'   => [{ 'value' => 'off', 'caption' => 'No filter' }]
    },
    'evidence_filter' => {
      'type'     => 'DropDown',
      'multiple' => 1,
      'size'     => 5,
      'select'   => 'select',
      'name'     => 'evidence_filter',
      'label'    => 'Filter variants by evidence status',
      'values'   => [{ 'value' => 'off', 'caption' => 'No filter' }]
    },
    'hidden_sources' => {
      'type'     => 'DropDown',
      'multiple' => 1,
      'size'     => 5,
      'select'   => 'select',
      'name'     => 'hidden_sources',
      'label'    => 'Hide individual variant sources',
      'values'   => [{ value => '_all', caption => 'No filter' }],
    },
    'hide_long_snps' => {
      'type'   => 'Checkbox', 
      'select' => 'select',
      'name'   => 'hide_long_snps',
      'label'  => 'Hide variants longer than 10bp',
      'value'  => 'on',
    },
    'hide_rare_snps' => {
      'type'     => 'DropDown',
      'select'   => 'select',
      'name'     => 'hide_rare_snps',
      'label'    => 'Hide variants by frequency (MAF)',
      'values'   => [{ 'value' => 'off', 'caption' => "Don't hide" },
                     { 'value' => 0.0001, 'caption' => 'Hide rare, MAF &lt; 0.01%' },
                     { 'value' => 0.001, 'caption' => 'Hide rare, MAF &lt; 0.1%' },
                     { 'value' => 0.01, 'caption' => 'Hide rare, MAF &lt; 1%' },
                     { 'value' => 0.1, 'caption' => 'Hide rare, MAF &lt; 10%' },
                     { 'value' => -0.0001, 'caption' => 'Hide common, MAF &gt; 0.01%' },
                     { 'value' => -0.001, 'caption' => 'Hide common, MAF &gt; 0.1%' },
                     { 'value' => -0.01, 'caption' => 'Hide common, MAF &gt; 1%' },
                     { 'value' => -0.1, 'caption' => 'Hide common, MAF &gt; 10%' }]
    },
    ### GENE-SPECIFIC TEXT SEQUENCE
    'flank5_display' => {
      'type'     => 'NonNegInt', 
      'required' => 'yes',
      'label'    => "5' Flanking sequence (upstream)",  
      'name'     => 'flank5_display',
      'max'      => 1e6
    },
    'flank3_display' => {
      'type'     => 'NonNegInt', 
      'required' => 'yes',
      'label'    => "3' Flanking sequence (downstream)",  
      'name'     => 'flank3_display',
      'max'      => 1e6
    },
    'exon_display' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'exon_display',
      'label'  => 'Additional exons to display',
      'values' => [
        { 'value' => 'off',       'caption' => 'No exon markup'  },
        { 'value' => 'Ab-initio', 'caption' => 'Ab-initio exons' },
        { 'value' => 'core',      'caption' => 'Core exons'      },
      ],
    },
    ### ALIGNED SEQUENCE MARKUP
    'display_width' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'display_width',
      'label'  => 'Number of base pairs per row',
      'values' => [
        map { { 'value' => $_, 'caption' => "$_ bps" } } map { $_*15 } (2..12)
      ],
    },
    'strand' => {
      'type'   => 'DropDown', 
      'select' => 'select',   
      'name'   => 'strand',
      'label'  => 'Strand',
      'values' => [
        { 'value' => '1',  'caption' => 'Forward' },
        { 'value' => '-1', 'caption' => 'Reverse' }
    ]
    },
    'codons_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'codons_display',
      'label'  => 'Codons',
      'values' => [
        { 'value' => 'all', 'caption' => 'START/STOP codons'  },
        { 'value' => 'off', 'caption' => 'Do not show codons' },
      ],
    },
    'title_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'title_display',
      'label'  => 'Display pop-up information on mouseover',
      'values' => [
        { 'value' => 'on', 'caption' => 'Yes' },
        { 'value' => 'off', 'caption' => 'No'  },
      ],
    },
    'seq_type' => {
      'type'    => 'RadioList',
      'name'    => 'seq_type',
      'label'   => 'Sequence to export',
      'values' => [
        { 'value' => 'msa_dna', 'caption' => 'Alignments - DNA' },
        { 'value' => 'msa_pep', 'caption' => 'Alignments - amino acids' },
        { 'value' => 'seq_dna', 'caption' => 'Unaligned sequences - CDS' },
        { 'value' => 'seq_pep', 'caption' => 'Unaligned sequences - proteins' },
      ],
      'value'   => 'msa_dna',
    }, 
  };
}

############ OLD MARKUP HASHES - REMOVE ONCE VIEWCONFIG REFACTOR IS COMPLETE ################

sub GENERAL_MARKUP_OPTIONS {
### Configuration for text sequence displays, shared by
### 'Genomic Alignments', 'Marked-up Sequence' and 'Resequencing'
  return (
    'snp_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'snp_display',
      'label'  => 'Show variants',
      'values' => [
        { 'value' => 'off', 'caption' => 'No'  },
        { 'value' => 'on', 'caption' => 'Yes' },
      ]
    },
    'line_numbering' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'line_numbering',
      'label'  => 'Line numbering',
      'values' => [
        { 'value' => 'sequence', 'caption' => 'Relative to this sequence'      },
        { 'value' => 'slice',    'caption' => 'Relative to coordinate systems' },
        { 'value' => 'off',      'caption' => 'None'                           },
      ]
    },
    'exon_ori' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'exon_ori',
      'label'  => 'Orientation of additional exons',
      'values' => [
        { 'value' => 'fwd', 'caption' => 'Display same orientation exons only'    },
        { 'value' => 'rev', 'caption' => 'Display reverse orientation exons only' },
        { 'value' => 'all', 'caption' => 'Display exons in both orientations'     },
      ],
    },
    'pop_filter' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'population_filter',
      'label'  => 'Filter variants by population',
      'notes'  => 'Warning: This could cause the page to take a long time to load',
      'values' => [{ 'value' => 'off', 'caption' => 'None' }]
    },
    'pop_min_freq' => {
      'type'  => 'NonNegFloat',
      'label' => 'Minor allele frequency for population filter',
      'name'  => 'min_frequency',
      'max'   => 0.5
    },
    'consequence_filter' => {
      'type'     => 'DropDown',
      'multiple' => 1,
      'size'     => 5,
      'select'   => 'select',
      'name'     => 'consequence_filter',
      'label'    => 'Filter variants by consequence type',
      'values'   => [{ 'value' => 'off', 'caption' => 'No filter' }]
    },
    'hide_long_snps' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'hide_long_snps',
      'label'  => 'Hide variants longer than 10bp',
      'values' => [
        { 'value' => 'yes', 'caption' => 'Yes' },
        { 'value' => 'off', 'caption' => 'No'  },
      ]
    },
  );
}

sub GENE_MARKUP_OPTIONS {
### Gene-specific text sequence configuration options,
### shared by 'Genomic Alignments' and 'Marked-up Sequence'
  return (
    'flank5_display' => {
      'type'     => 'NonNegInt',
      'required' => 'yes',
      'label'    => "5' Flanking sequence (upstream)",
      'name'     => 'flank5_display',
      'max'      => 1e6
    },
    'flank3_display' => {
      'type'     => 'NonNegInt',
      'required' => 'yes',
      'label'    => "3' Flanking sequence (downstream)",
      'name'     => 'flank3_display',
      'max'      => 1e6
    },
    'exon_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'exon_display',
      'label'  => 'Additional exons to display',
      'values' => [
        { 'value' => 'off',       'caption' => 'No exon markup'  },
        { 'value' => 'Ab-initio', 'caption' => 'Ab-initio exons' },
        { 'value' => 'core',      'caption' => 'Core exons'      },
      ],
    },
  );
}

sub OTHER_MARKUP_OPTIONS {
### Configuration options for aligned sequence markup,
### shared by 'Genomic Alignments' and 'Resequencing'
  return (
    'display_width' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'display_width',
      'label'  => 'Number of base pairs per row',
      'values' => [
        map { { 'value' => $_, 'caption' => "$_ bps" } } map { $_*15 } (2..12)
      ],
    },
    'strand' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'strand',
      'label'  => 'Strand',
      'values' => [
        { 'value' => '1',  'caption' => 'Forward' },
        { 'value' => '-1', 'caption' => 'Reverse' }
      ]
    },
    'codons_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'codons_display',
      'label'  => 'Codons',
      'values' => [
        { 'value' => 'all', 'caption' => 'START/STOP codons'  },
        { 'value' => 'off', 'caption' => 'Do not show codons' },
      ],
    },
    'title_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'title_display',
      'label'  => 'Display pop-up information on mouseover',
      'values' => [
        { 'value' => 'yes', 'caption' => 'Yes' },
        { 'value' => 'off', 'caption' => 'No'  },
      ],
    },
  );
}


################################################################################################

sub VARIATION_OPTIONS {
### Variation markup options for text sequence displays, 
### shared by transcript and gene snp views
  return (
    'variation' =>  {
      'opt_freq'       =>  [ 'on', 'By frequency'      ],
      'opt_cluster'    =>  [ 'on', 'By Cluster'        ],
      'opt_doublehit'  =>  [ 'on', 'By doublehit'      ],
      'opt_submitter'  =>  [ 'on', 'By submitter'      ],
      'opt_hapmap'     =>  [ 'on', 'Hapmap'            ],
      'opt_1000Genome' =>  [ 'on', '1000 genomes'      ],
      'opt_precious'   =>  [ 'on', 'Precious variants' ],
      'opt_noinfo'     =>  [ 'on', 'No information'    ],
    }, 
    'class' =>  {
      'opt_class_insertion'              =>  [ 'on', 'Insertions'             ],
      'opt_class_deletion'               =>  [ 'on', 'Deletions'              ],
      'opt_class_indel'                  =>  [ 'on', 'In-dels'                ],
      'opt_class_snp'                    =>  [ 'on', 'SNPs'                   ],
      'opt_class_cnv'                    =>  [ 'on', 'Copy number variants' ],
      'opt_class_substitution'           =>  [ 'on', 'Substitutions'          ],
      'opt_class_tandem_repeat'          =>  [ 'on', 'Tandem repeats'         ],
      'opt_class_'                       =>  [ 'on', 'Unclassified'           ],
	  
      'opt_class_somatic_insertion'      =>  [ 'on', 'Somatic insertions'             ],
      'opt_class_somatic_deletion'       =>  [ 'on', 'Somatic deletions'              ],
      'opt_class_somatic_indel'          =>  [ 'on', 'Somatic in-dels'                ],
      'opt_class_somatic_snv'            =>  [ 'on', 'Somatic SNVs'                   ],
      'opt_class_somatic_cnv'            =>  [ 'on', 'Somatic copy number variants' ],
      'opt_class_somatic_substitution'   =>  [ 'on', 'Somatic substitutions'          ],
      'opt_class_somatic_tandem_repeat'  =>  [ 'on', 'Somatic tandem repeats'         ],
      'opt_class_somatic_'               =>  [ 'on', 'Unclassified somatic mutations' ],
    }, 
    'type' => {
      'opt_transcript_ablation'               =>  [ 'on', 'Essential splice site',       1  ],
      'opt_splice_donor_variant'              =>  [ 'on', 'Splice donor',                3  ],
      'opt_splice_acceptor_variant'           =>  [ 'on', 'Splice acceptor',             3  ],
      'opt_stop_gained'                       =>  [ 'on', 'Stop gained',                 4  ],
      'opt_frameshift_variant'                =>  [ 'on', 'Frameshift',                  5  ],
      'opt_stop_lost'                         =>  [ 'on', 'Stop lost',                   6  ],
      'opt_initiator_codon_variant'           =>  [ 'on', 'Initiator codon',             7  ],
      'opt_inframe_insertion'                 =>  [ 'on', 'Inframe insertion',           10 ],
      'opt_inframe_deletion'                  =>  [ 'on', 'Inframe deletion',            11 ],
      'opt_missense_variant'                  =>  [ 'on', 'Missense',                    12 ],
      'opt_splice_region_variant'             =>  [ 'on', 'Splice region',               13 ],
      'opt_incomplete_terminal_codon_variant' =>  [ 'on', 'Incomplete terminal codon',   14 ],
      'opt_synonymous_variant'                =>  [ 'on', 'Synonymous',                  15 ],
      'opt_stop_retained'                     =>  [ 'on', 'Stop retained',               15 ],
      'opt_coding_sequence_variant'           =>  [ 'on', 'Coding sequence',             16 ],
      'opt_mature_mirna_variant'              =>  [ 'on', 'Mature miRNA',                17 ],
      'opt_5_prime_utr_variant'               =>  [ 'on', "5' UTR",                      18 ],
      'opt_3_prime_utr_variant'               =>  [ 'on', "3' UTR",                      19 ],
      'opt_intron_variant'                    =>  [ 'on', 'Intron',                      20 ],
      'opt_nmd_transcript_variant'            =>  [ 'on', 'NMD transcript',              21 ],
      'opt_non_coding_exon_variant'           =>  [ 'on', 'Non-coding exon',             22 ],
      'opt_nc_transcript_variant'             =>  [ 'on', 'Non-coding transcript',       23 ],
      'opt_upstream_gene_variant'             =>  [ 'on', 'Upstream',                    24 ],
      'opt_downstream_gene_variant'           =>  [ 'on', 'Downstream',                  25 ],
	  'opt_feature_truncation'                =>  [ 'on', 'Feature truncation',          36 ],
	  'opt_feature_elongation'                =>  [ 'on', 'Feature elongation',          37 ],
      'opt_sara'                              =>  [ 'on', 'SARA (same as ref.assembly)', 40 ],
    },
  );
}

sub MESSAGE_PRIORITY {
### Priority order for message boxes - errors, warnings, etc
  return (
    '_error',
    '_warning',
    '_info',
    '_hint'
  ); 
}

sub USERDATA_MESSAGES {
### Standard set of error messages used by user upload interface
  return (
    no_url => {
      'type'    => 'error', 
      'title'   => 'Input problem',
      'message' => 'No URL was entered. Please try again.',
    },
    no_response => {
      'type'    => 'error', 
      'title'   => 'File system error',
      'message' => 'We were unable to access your data file. If you continue to get this message, there may be an network issue, or your file may be too large for us to upload.',
    },
    file_format => {
      'type'    => 'error', 
      'title'   => 'Input problem',
      'message' => 'Your file does not appear to be in a valid format. Please try again.',
    },
    file_empty => {
      'type'    => 'error', 
      'title'   => 'Input problem',
      'message' => 'Your file appears to be empty. Please check that it contains correctly-formatted data.',
    },
    file_size => {
      'type'    => 'error', 
      'title'   => 'File system error',
      'message' => 'Your file is too big to upload. Please select a smaller file.',
    },
    file_save => {
      'type'    => 'error', 
      'title'   => 'File system error',
      'message' => 'Your data could not be saved. Please check the file contents and try again.'
    },
    load_file => {
      'type'    => 'error', 
      'title'   => 'File system error',
      'message' => 'There was an error retrieving your data from disk.'
    },
    save_file => {
      'type'    => 'error', 
      'title'   => 'Database error',
      'message' => 'Unable to save uploaded file contents to your account',
    },
    save_url => {
      'type'    => 'error', 
      'title'   => 'Database error',
      'message' => 'Unable to save remote URL to your account'
    },
    no_features => {
      'type'    => 'warning', 
      'title'   => 'Script warning',
      'message' => 'The script returned no features.',
    },
    location_unknown => {
      'type'    => 'warning', 
      'title'   => 'Input problem',
      'message' => "The selected region(s) lie outside the scope of this species' chromosomes.",
    },
    location_toolarge => {
      'type'    => 'warning', 
      'title'   => 'Script aborted',
      'message' => 'The region(s) you selected are too large and will return too much data for the web interface to cope with.'
    },
    hub_ok => {
      'type'    => 'info', 
      'title'   => 'Hub attached',
      'message' => 'Your hub attached successfully.',
    },
    hub_old_only => {
      'type'    => 'error', 
      'title'   => 'Track hub problem',
      'message' => 'This hub contains no data on any current assemblies. Please check our <a href="/info/website/archives/">archive list</a> for alternative sites.',
    },
    hub_old_and_new => {
      'type'    => 'warning', 
      'title'   => 'Multiple assemblies',
      'message' => 'Your hub includes multiple assemblies, so not all features will be shown. Alternative assemblies may available on archive sites.',
    },
    hub_other_only => {
      'type'    => 'warning', 
      'title'   => 'No data on this species',
      'message' => 'Your hub contains no data on the chosen species.</p>',
    },
    hub_preconfig => {
      'type'    => 'info', 
      'title'   => 'Hub already attached',
      'message' => 'This hub is attached by default.',
    },
    hub_user => {
      'type'    => 'info', 
      'title'   => 'Hub already attached',
      'message' => 'You have already attached this hub.'
    },
  );
}

sub ERROR_MESSAGES { 
### General server error messages - custom versions of
### standard Apache errors (e.g. 404)
  return (
    404 => [
      'Page not found' ,
      #'Much like this creature, the page you requested could not be found.',
      'Sorry, the page you requested was not found on this server.',
    ], 
    400 => [
      'Bad method' ,
      'Sorry, the way you were asking for the file was not recognised',
    ], 
    403 => [
      'No permission',
      'The webserver does not have permission to view that file'
    ], 
    401 => [
      'Not authorised',
      'You were not authorised to view that page, a username and password is required',
    ],
    ## bogus HTTP error for internal tracks sourced from files
    ## (Yes, it's a reference to the fictional US area code used in movies!)
    555 => [
      'Unavailable',
      #'This resource is temporarily unavailable - please check our blog for service updates',
      'This resource is temporarily unavailable owing to the Hinxton datacentre shutdown',
    ],
  );
}

1;
