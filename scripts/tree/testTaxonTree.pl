#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use DBI;
use Getopt::Long;

use Bio::AlignIO;

use Bio::EnsEMBL::Utils::IO qw/:slurp :spurt/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'speciesList'} = ();
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;
$self->{'cdna'} = 0;
$self->{'scale'} = 10;
$self->{'extrataxon_sequenced'} = undef;
$self->{'multifurcation_deletes_node'} = undef;
$self->{'multifurcation_deletes_all_subnodes'} = undef;
$self->{'njtree_output_filename'} = undef;
$self->{'no_other_files'} = undef;
$self->{'no_print_tree'}  = undef;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'        => \$help,
           'url=s'       => \$url,
           'tre=s'       => \$self->{'newick_file'},
           'tree_id=i'   => \$self->{'tree_id'},
           'gene=s'      => \$self->{'gene_stable_id'},
           'reroot=i'    => \$self->{'new_root_id'},
           'align'       => \$self->{'print_align'},
           'cdna'        => \$self->{'cdna'},
           'tag=s'     => \$self->{'tag'},

           'create_species_tree'     => \$self->{'create_species_tree'},
           'extrataxon_sequenced=s'  => \$self->{'extrataxon_sequenced'},
           'multifurcation_deletes_node=s' => \$self->{'multifurcation_deletes_node'},
           'multifurcation_deletes_all_subnodes=s' => \$self->{'multifurcation_deletes_all_subnodes'},
           'njtree_output_filename=s'   => \$self->{'njtree_output_filename'},  # we need to be able to feed the filename from outside to make some automation possible
           'no_other_files'             => \$self->{'no_other_files'},          # and shut up the rest of it :)
           'no_print_tree'              => \$self->{'no_print_tree'},           # so all output goes to STDERR
           'scale=f'     => \$self->{'scale'},
          );

if ($help) { usage(); }

if ($url) {
  $self->{'comparaDBA'} = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( -URL => $url );
}
unless(defined($self->{'comparaDBA'})) {
  warn "Could not create compara_dba from url '$url'\n\n";
  usage();
} 

if($self->{'tree_id'}) {
  my $treeDBA = $self->{'comparaDBA'}->get_GeneTreeAdaptor;
  my $tree = $treeDBA->fetch_by_dbID($self->{'tree_id'});
  $self->{'root'} = $tree->root;
}

if ($self->{'tree_id'}) {
    print_protein_tree($self);
} elsif ($self->{'gene_stable_id'}) {
    fetch_protein_tree_with_gene($self, $self->{'gene_stable_id'});
} elsif ($self->{'newick_file'}) {
    parse_newick($self);
} elsif ($self->{'new_root_id'}) {
    reroot($self);
} elsif ($self->{'print_align'}) {
    dumpTreeMultipleAlignment($self);
} elsif ($self->{'create_species_tree'}) {
    create_species_tree($self);
} else {
    fetch_compara_ncbi_taxa($self);
}

#cleanup memory
if($self->{'root'}) {
  warn("ABOUT TO MANUALLY release tree\n") if ($self->{'debug'});
  $self->{'root'}->release_tree;
  $self->{'root'} = undef;
  warn("DONE\n") if ($self->{'debug'});
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  warn "testTaxonTree.pl [options]\n";
  warn "  -help                  : print this help\n";
  warn "  -url <url>             : connect to compara at url\n";
  warn "  -tree_id <id>          : print tree with node_id\n";
  warn "  -name <string>         : search for <name> and print tree from that node\n";
  warn "  -align                 : print multiple alignment\n";
  warn "  -scale <num>           : scale factor for printing tree (def: 100)\n";
  warn "  -mini                  : minimize tree\n";
  warn "testTaxonTree.pl v1.1\n";
  
  exit(1);  
}



sub fetch_compara_ncbi_taxa {
  my $self = shift;
  
  warn("fetch_compara_ncbi_taxa\n");
  
  my $root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
    -COMPARA_DBA    => $self->{'comparaDBA'},
    -RETURN_NCBI_TREE       => 1,
  );

  $root->print_tree($self->{'scale'});

  $self->{'root'} = $root;
}

sub create_species_tree {
  my $self = shift;

  warn("create_species_tree\n");

  my @extrataxon_sequenced;
  if($self->{'extrataxon_sequenced'}) { 
    my $temp = $self->{'extrataxon_sequenced'};
    @extrataxon_sequenced = split ('_',$temp);
  }
  my @multifurcation_deletes_node;
  if($self->{'multifurcation_deletes_node'}) { 
    my $temp = $self->{'multifurcation_deletes_node'};
    @multifurcation_deletes_node = split ('_',$temp);
  }
  my @multifurcation_deletes_all_subnodes;
  if($self->{'multifurcation_deletes_all_subnodes'}) { 
    my $temp = $self->{'multifurcation_deletes_all_subnodes'};
    @multifurcation_deletes_all_subnodes = split ('_',$temp);
  }

  my $root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
    -COMPARA_DBA    => $self->{'comparaDBA'},
    -RETURN_NCBI_TREE       => 1,
    -EXTRATAXON_SEQUENCED   => \@extrataxon_sequenced,
    -MULTIFURCATION_DELETES_NODE    => \@multifurcation_deletes_node,
    -MULTIFURCATION_DELETES_ALL_SUBNODES    => @multifurcation_deletes_all_subnodes,
  );

unless($self->{'no_print_tree'}) {
  $root->print_tree($self->{'scale'});
}

  my $outname = $self->{'comparaDBA'}->dbc->dbname;
  $outname .= ".".$self->{'tag'} if (defined($self->{'tag'}));
  my $num_leaves = scalar(@{$root->get_all_leaves});
  $outname = $num_leaves . "." . $outname;
  my $newick_common;
  eval {$newick_common = $root->newick_format("full_common");};
  unless ($@) {
    warn("\n\n$newick_common\n\n");
    $newick_common =~ s/\ /\_/g;

    unless($self->{'no_other_files'}) {
        spurt("newick_common.$outname.nh", $newick_common);
    }
  }
  my $newick = $root->newick_format;
  warn("\n\n$newick\n\n");

    unless($self->{'no_other_files'}) {
        spurt("newick.$outname.nh", $newick);
    }

  my $newick_simple = $newick;
  $newick_simple =~ s/\:\d\.\d+//g;
  $newick_simple =~ s/\ /\_/g;

  warn "$newick_simple\n\n";

    unless($self->{'no_other_files'}) {
        spurt("newick_simple.$outname.nh", $newick_simple);
    }

  my $species_short_name = $root->newick_format('species_short_name');
  warn("$species_short_name\n\n");

    unless($self->{'no_other_files'}) {
        spurt("species_short_name.$outname.nh", $species_short_name);
    }

  my $njtree_tree = $root->newick_format('ncbi_taxon');
  warn "==== Your njtree file njtree.$outname.nh ====\n";
  warn "$njtree_tree\n\n";

    unless($self->{'no_other_files'}) {
        spurt("njtree.$outname.nh". $njtree_tree);
    }

    if($self->{'njtree_output_filename'}) {   # we need to feed the filename from outside for some automation
        spurt($self->{'njtree_output_filename'}, $njtree_tree);
    }

  my $s = join (":", map {$_->name} (@{$root->get_all_leaves}));
  $s =~ s/\ /\_/g;
  warn "$s\n";

  $self->{'root'} = $root;
}


sub print_protein_tree {
  my $self = shift;

  my $tree = $self->{'root'};

  $tree->tree->print_tree($self->{'scale'});
  warn sprintf("%d proteins\n", scalar(@{$tree->get_all_leaves}));
  
  my $newick = $tree->newick_format('simple');
  warn("$newick\n");

}

sub fetch_protein_tree_with_gene {
  my $self = shift;
  my $gene_stable_id = shift;

  my $member = $self->{'comparaDBA'}->get_GeneMemberAdaptor->fetch_by_stable_id($gene_stable_id);
  print $member->toString(), "\n";
  print $member->get_canonical_SeqMember->toString(), "\n";

  my $treeDBA = $self->{'comparaDBA'}->get_GeneTreeAdaptor;
  my $tree = $treeDBA->fetch_default_for_Member($member);
  $tree->print_tree($self->{'scale'});
}


sub parse_newick {
  my $self = shift;
  
  warn "load from file ". $self->{'newick_file'}. "\n";
  my $newick = slurp( $self->{'newick_file'} );
  my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  $tree->print_tree($self->{'scale'});

}

sub reroot {
  my $self = shift;
  my $node_id = $self->{'new_root_id'}; 

  my $treeDBA = $self->{'comparaDBA'}->get_GeneTreeNodeAdaptor;
  my $node = $treeDBA->fetch_node_by_node_id($node_id);  
  warn "tree at ". $node->root->node_id ."\n";
  my $tree = $treeDBA->fetch_node_by_node_id($node->root->node_id);  
  $tree->print_tree($self->{'scale'});
  
  my $new_root = $tree->find_node_by_node_id($node_id);
  return unless $new_root;

  my $tmp_root = Bio::EnsEMBL::Compara::NestedSet->new;
  $tmp_root->merge_children($tree);

  $new_root->re_root;
  $tree->merge_children($new_root);

  $tree->build_leftright_indexing;
  $tree->print_tree($self->{'scale'});

  $treeDBA->store($tree);
  $treeDBA->delete_node($new_root);

}



sub dumpTreeMultipleAlignment
{
  my $self = shift;
  
  warn("missing tree\n") unless($self->{'root'});
  
  my $tree = $self->{'root'};
    
  $self->{'file_root'} = "proteintree_". $tree->node_id;
  $self->{'file_root'} =~ s/\/\//\//g;  # converts any // in path to /

  my $clw_file = $self->{'file_root'} . ".aln";

  if($self->{'debug'}) {
    my $leafcount = scalar(@{$tree->get_all_leaves});  
    warn "dumpTreeMultipleAlignmentToWorkdir : $leafcount members\n";
    warn "clw_file = '$clw_file'\n";
  }

  # "interleaved" is BioPerl's default way of printing phylip alignments
  $tree->print_alignment_to_file($clw_file,
      -FORMAT => 'phylip',
      -ID_TYPE => 'MEMBER',
      $self->{'cdna'} ? (-SEQ_TYPE => 'cds') : (),
  );
}


