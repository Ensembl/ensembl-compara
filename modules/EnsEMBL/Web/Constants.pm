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
    'newick'    => { 'caption' => 'Newick format',    'method' => 'newick_format', 'parameters' => [ 'newick_node' ], 'split' => ',', 'link' => 'http://en.wikipedia.org/wiki/Newick_format' },
    'nhx'       => { 'caption' => 'New Hampshire eXtended format (NHX)',       'method' => 'nhx_format',    'parameters' => [ 'nhx_mode'    ], 'split' => ',', 'link' => 'http://www.phylosoft.org/forester/NHX.html' }
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

1;
