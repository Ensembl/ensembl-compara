package EnsEMBL::Web::Constants;

use strict;
use warnings;
no warnings 'uninitialized';

sub ICON_MAPPINGS {
  my $component = shift || 'page';
  
  return {
    'config'    => { 'file' => 'setting.png',   'alt' => 'config',   'title' => "Configure this $component"          },
    'search'    => { 'file' => 'search.png',    'alt' => 'search',   'title' => "Search this $component"             },
    'download'  => { 'file' => 'download.png',  'alt' => 'download', 'title' => "Download data from this $component" },
    'image'     => { 'file' => 'picture.png',   'alt' => 'image',    'title' => "Export this image"                  },
    'userdata'  => { 'file' => 'page-user.png', 'alt' => 'data',     'title' => "Manage your custom tracks"          },
    'share'     => { 'file' => 'share.png',     'alt' => 'share',    'title' => "Share this $component"              },
  };
}

sub FORMATS {
  warn "!!! DEPRECATED - PLEASE USE 'EXPORT_FORMATS' INSTEAD";
  return &EXPORT_FORMATS;
}

sub EXPORT_FORMATS {
  return (
	  'png'  => { 'name' => 'PNG', 'longname' => 'Portable Network Graphics',   'extn' => 'png', 'mime' => 'image/png'              },
    'gif'  => { 'name' => 'GIF', 'longname' => 'Graphics Interchange Format', 'extn' => 'gif', 'mime' => 'image/gif'              },
	  'svg'  => { 'name' => 'SVG', 'longname' => 'Scalable Vector Graphics',    'extn' => 'svg', 'mime' => 'image/svg+xml'          },
	  'eps'  => { 'name' => 'EPS', 'longname' => 'Encapsulated Postscript',     'extn' => 'eps', 'mime' => 'application/postscript' },
	  'pdf'  => { 'name' => 'PDF', 'longname' => 'Portable Document Format',    'extn' => 'pdf', 'mime' => 'application/pdf'        },
	  'gff'  => { 'name' => 'GFF', 'longname' => 'General Feature Format',      'extn' => 'txt', 'mime' => 'text/plain'             }
  );
}

sub HOMOLOGY_TYPES {
  return {
    'BRH'  => 'Best Reciprocal Hit',
    'UBRH' => 'Unique Best Reciprocal Hit',
    'MBRH' => 'Multiple Best Reciprocal Hit',
    'RHS'  => 'Reciprocal Hit based on Synteny around BRH',
    'DWGA' => 'Derived from Whole Genome Alignment'
  };
}

sub GENE_JOIN_TYPES {
  return {
    'ortholog_one2one'          => 'orthologue',
    'apparent_ortholog_one2one' => 'orthologue',
    'ortholog_one2many'         => 'orthologue_multi',
    'ortholog_many2many'        => 'orthologue_multi',
    'possible_ortholog'         => 'possible_ortholog',
    'UBRH'                      => 'orthologue',
    'BRH'                       => 'orthologue',
    'MBRH'                      => 'orthologue',
    'RHS'                       => 'orthologue',
    'within_species_paralog'    => 'paralogue',
    'other_paralog'             => 'paralogue',
    'between_species_paralog'   => 'paralogue',
    'projection_unchanged'      => 'projection',
    'putative_gene_split'       => 'hidden',
    'contiguous_gene_split'     => 'hidden',
  }
}

sub ALIGNMENT_FORMATS {
  return (
    'fasta'    => 'FASTA',
    'msf'      => 'MSF',
    'clustalw' => 'CLUSTAL',
    'selex'    => 'Selex',
    'pfam'     => 'Pfam',
    'mega'     => 'Mega',
    'nexus'    => 'Nexus',
    'phylip'   => 'Phylip',
    'psi'      => 'PSI',
  );
}
sub SIMPLEALIGN_DEFAULT { return 'clustalw'; }

sub TREE_FORMATS {
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
    'njtree'                  => 'NJ tree',
    'phylip'                  => 'PHYLIP',
  );
}

sub FAMILY_EXTERNAL {
  return (
    'swissprot' => { 'name' => 'UniProt/Swiss-Prot' , 'key' => 'Uniprot/SWISSPROT' },
    'trembl'    => { 'name' => 'UniProt/TrEMBL',      'key' => 'Uniprot/SPTREMBL'  }
  );
}

# shared by 'Genomic Alignments', 'Marked-up Sequence' and 'Resequencing'
sub GENERAL_MARKUP_OPTIONS {
  return (
    'snp_display' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'snp_display',
      'label'  => 'Show variations',
      'values' => [
        { 'value' => 'off', 'name' => 'No'  },
        { 'value' => 'yes', 'name' => 'Yes' },
      ]
    },
    'line_numbering' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'line_numbering',
      'label'  => 'Line numbering',
      'values' => [
        { 'value' => 'sequence', 'name' => 'Relative to this sequence'      },
        { 'value' => 'slice',    'name' => 'Relative to coordinate systems' },
        { 'value' => 'off',      'name' => 'None'                           },
      ]
    },
    'exon_ori' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'exon_ori',
      'label'  => 'Orientation of additional exons',
      'values' => [
        { 'value' => 'fwd', 'name' => 'Display same orientation exons only'    },
        { 'value' => 'rev', 'name' => 'Display reverse orientation exons only' },
        { 'value' => 'all', 'name' => 'Display exons in both orientations'     },
      ],
    },
    'pop_filter' => {
      'type'   => 'DropDown', 
      'select' => 'select',
      'name'   => 'population_filter',
      'label'  => 'Filter variations by population',
      'notes'  => 'Warning: This could cause the page to take a long time to load',
      'values' => [{ 'value' => 'off', 'name' => 'None' }]
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
      'label'    => 'Filter variations by consequence type',
      'values'   => [{ 'value' => 'off', 'name' => 'No filter' }]
    }
  );
}

# shared by 'Genomic Alignments' and 'Marked-up Sequence'
sub GENE_MARKUP_OPTIONS {
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
        { 'value' => 'off',       'name' => 'No exon markup'  },
        { 'value' => 'Ab-initio', 'name' => 'Ab-initio exons' },
        { 'value' => 'core',      'name' => 'Core exons'      },
      ],
    },
  );
}

# shared by 'Genomic Alignments' and 'Resequencing'
sub OTHER_MARKUP_OPTIONS {
  return (
    'display_width' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'display_width',
      'label'  => 'Number of base pairs per row',
      'values' => [
        map { { 'value' => $_, 'name' => "$_ bps" } } map { $_*15 } (2..12)
      ],
    },
    'strand' => {
      'type'   => 'DropDown', 
      'select' => 'select',   
      'name'   => 'strand',
      'label'  => 'Strand',
      'values' => [
        { 'value' => '1',  'name' => 'Forward' },
        { 'value' => '-1', 'name' => 'Reverse' }
    ]
    },
    'codons_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'codons_display',
      'label'  => 'Codons',
      'values' => [
        { 'value' => 'all', 'name' => 'START/STOP codons'  },
        { 'value' => 'off', 'name' => 'Do not show codons' },
      ],
    },
    'title_display' => {
      'type'   => 'DropDown',
      'select' => 'select',
      'name'   => 'title_display',
      'label'  => 'Display pop-up information on mouseover',
      'values' => [
        { 'value' => 'all', 'name' => 'Yes' },
        { 'value' => 'off', 'name' => 'No'  },
      ],
    },
  );
}

# shared by transcript and gene snp views
sub VARIATION_OPTIONS {
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
      'opt_class_cnv'                    =>  [ 'on', 'Copy number variations' ],
      'opt_class_substitution'           =>  [ 'on', 'Substitutions'          ],
      'opt_class_tandem_repeat'          =>  [ 'on', 'Tandem repeats'         ],
      'opt_class_'                       =>  [ 'on', 'Unclassified'           ],
	  
      'opt_class_somatic_insertion'      =>  [ 'on', 'Somatic insertions'             ],
      'opt_class_somatic_deletion'       =>  [ 'on', 'Somatic deletions'              ],
      'opt_class_somatic_indel'          =>  [ 'on', 'Somatic in-dels'                ],
      'opt_class_somatic_snv'            =>  [ 'on', 'Somatic SNVs'                   ],
      'opt_class_somatic_cnv'            =>  [ 'on', 'Somatic copy number variations' ],
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
  return (
    '_error',
    '_warning',
    '_info',
    '_hint'
  ); 
}

sub USERDATA_MESSAGES {
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
    save_das => {
      'type'    => 'error', 
      'title'   => 'Database error',
      'message' => 'Unable to save DAS details to your account'
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
  );
}

sub ERROR_MESSAGES { 
  return (
    404 => [
      'Page not found' ,
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
      'You were not authorised to view that page, an username and password is required',
    ]
  );
}

1;
