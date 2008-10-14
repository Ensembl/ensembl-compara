package EnsEMBL::Web::Constants;

use strict;
use warnings;
no warnings 'uninitialized';

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

sub TREE_FORMATS {
  return (
    'text'      => { 'caption' => 'Text dump', 'method' => 'string_tree',   'parameters' => [ 'scale'       ] },
    'newick'    => { 'caption' => 'Newick',    'method' => 'newick_format', 'parameters' => [ 'newick_mode' ], 'split' => ',', 'link' => 'http://en.wikipedia.org/wiki/Newick_format' },
    'nhx'       => { 'caption' => 'New Hampshire eXtended (NHX)',       'method' => 'nhx_format',    'parameters' => [ 'nhx_mode'    ], 'split' => ',', 'link' => 'http://www.phylosoft.org/forester/NHX.html' }
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

#shared by 'Genomic Alignments', 'Marked-up Sequence' and 'Resequencing'
sub GENERAL_MARKUP_OPTIONS {
    return (
	'snp_display' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'snp_display',
	    'label'    => 'Show variations',
	    'values'   => [
		{ 'value' =>'off',       'name' => 'No' },
		{ 'value' =>'snp',       'name' => 'Yes' },
		{ 'value' =>'snp_link' , 'name' => 'Yes and show links' },
	    ]
	},
	'line_numbering' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'line_numbering',
	    'label'    => 'Line numbering',
	    'values'   => [
		{ 'value' =>'sequence' , 'name' => 'Relative to this sequence' },
		{ 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
		{ 'value' =>'off'      , 'name' => 'None' },
	    ]
	},
	'exon_ori' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'exon_ori',
	    'label'    => "Orientation of additional exons",
	    'values'   => [
		{ 'value' =>'fwd' , 'name' => 'Display same orientation exons only' },
		{ 'value' =>'rev' , 'name' => 'Display reverse orientation exons only' },
		{ 'value' =>'all' , 'name' => 'Display exons in both orientations' },
	    ],
	},
    );
}

#shared by 'Genomic Alignments' and 'Marked-up Sequence'
sub GENE_MARKUP_OPTIONS {
    return (
	'flank5_display' => {
	    'type' => 'NonNegInt', 'required' => 'yes',
	    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
	},
	'flank3_display' => {
	    'type' => 'NonNegInt', 'required' => 'yes',
	    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
	},
	'exon_display' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'exon_display',
	    'label'    => 'Additional exons to display',
	    'values'   => [
		{ 'value' => 'off',           'name' => 'No exon markup' },
		{ 'value' => 'Ab-initio',     'name' => 'Ab-initio exons' },
		{ 'value' => 'core',          'name' => "Core exons" },
	    ],
	},
    );
}

#shared by 'Genomic Alignments' and 'Resequencing'
sub OTHER_MARKUP_OPTIONS {
    return (
	'display_width' => {
	    'type' => 'NonNegInt', 'required' => 'yes',
	    'label' => "Alignment width",  'name' => 'display_width',
	},
	'codons_display' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'codons_display',
	    'label'    => 'Codons',
	    'values'   => [
		{ 'value' =>'all' , 'name' => 'START/STOP codons' },
		{ 'value' =>'off' , 'name' => "Do not show codons" },
	    ],
	},
	'title_display' => {
	    'type'     => 'DropDown', 'select'   => 'select',
	    'required' => 'yes',      'name'     => 'title_display',
	    'label'    => 'Title display',
	    'values'   => [
		{ 'value' =>'all' , 'name' => 'Include `title` tags' },
		{ 'value' =>'off' , 'name' => 'None' },
	    ],
	},
    );
}


1;
