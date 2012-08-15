=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::Readme

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates a general README.{emf} file and a specific README for the multiple alignment being dumped

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::Readme;

use strict;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Cwd;

sub fetch_input {
    my $self = shift;

}

sub run {
    my $self = shift;

    #
    #Copy README.{format} to output_dir eg README.emf
    #Currently there is only a README.emf
    #
    my $from = $INC{"Bio/EnsEMBL/Compara/RunnableDB/DumpMultiAlign/Readme.pm"};
    my $format = $self->param('format');
    $from =~ s/Readme\.pm$/README.$format/; 

    my $to = $self->param('output_dir');
    my $cmd = "cp $from $to";

    #Check README file and directory exist (do not for maf)
    if (-e $from && -e $to) { 
	if(my $return_value = system($cmd)) {
	    $return_value >>= 8;
	    die "system( $cmd ) failed: $return_value";
	}
    }

    #Create specific README file
    $self->_create_specific_readme();

}

=head2 write_output

=cut

sub write_output {
    my $self = shift @_;

}

#
#Internal methods
#

#
#Create specific README file
#
sub _create_specific_readme {
    my ($self) = @_;
    #
    #Load registry
    #
    if ($self->param('reg_conf')) {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'),1);
    } elsif ($self->param('db_url')) {
	my $db_urls = $self->param('db_url');
	foreach my $db_url (@$db_urls) {
	    Bio::EnsEMBL::Registry->load_registry_from_url($db_url);
	}
    } else {
	Bio::EnsEMBL::Registry->load_all();
    }

    #Note this is using the database set in $self->param('compara_db') rather than the underlying compara database.
    my $compara_dba = $self->compara_dba;

    #Get meta_container adaptor
    my $meta_container = $compara_dba->get_MetaContainer;

    #Get method_link_species_set
    my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));

    #If dumping conservation scores, need to find associated multiple alignment
    #mlss
    if (($mlss->method->type) eq "GERP_CONSERVATION_SCORE") {
	$mlss = $mlss_adaptor->fetch_by_dbID($mlss->get_value_for_tag('msa_mlss_id'));
    }

    #Get tree and ordered set of genome_dbs
    my ($newick_species_tree, $species_set) = $self->_get_species_tree($mlss);
    my $method_link = $mlss->method->type;
    my $filename = $self->param('output_dir') . "/README." . lc($method_link) . "_" . @$species_set . "_way";

    #Get first schema_version
    my $schema_version = $meta_container->list_value_by_key('schema_version')->[0];

    if ($mlss->method->type eq "PECAN") {
	$self->_create_specific_pecan_readme($compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree);
    } elsif ($mlss->method->type eq "EPO") {
	$self->_create_specific_epo_readme($compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree);
    } elsif ($mlss->method->type eq "EPO_LOW_COVERAGE") {
	$self->_create_specific_epo_low_coverage_readme($compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree, $mlss_adaptor);
    } 

}

#
# Get the species tree either from a file or the database. 
# Prune if necessary. 
# Convert genome_db_ids to species names if necessary
# Return species_tree and ordered list of genome_dbs
#
sub _get_species_tree {
    my ($self, $mlss) = @_;

    my $ordered_species;

    #Try to get tree from mlss_tag table
    my $newick_species_tree = $mlss->get_value_for_tag('species_tree');
    
    #If this fails, try to get from file
    if (!$newick_species_tree && $self->param('species_tree_file') ne "") {
	open(TREE_FILE, $self->param('species_tree_file')) or $self->throw("Cannot open file ".$self->('species_tree_file'));
	$newick_species_tree = join("", <TREE_FILE>);
	close(TREE_FILE);
    }

    $newick_species_tree =~ s/^\s*//;
    $newick_species_tree =~ s/\s*$//;
    $newick_species_tree =~ s/[\r\n]//g;

    my $species_tree =
      Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_species_tree);

    my $genome_dbs = $mlss->species_set_obj->genome_dbs;

    my %leaves_names;
    foreach my $genome_db (@$genome_dbs) {
	my $name = $genome_db->name;
	#$name =~ tr/ /_/;
	next if ($name eq "ancestral_sequences");
	$leaves_names{$genome_db->dbID} = $name;
	$leaves_names{$name} = $genome_db;
    }

    foreach my $leaf (@{$species_tree->get_all_leaves}) {
	my $leaf_name = lc($leaf->name);
	unless (defined $leaves_names{$leaf_name}) {
	    $leaf->disavow_parent;
	    $species_tree = $species_tree->minimize_tree;
	}
	if ($leaf_name =~ /\d+/) {
	    $leaf->name($leaves_names{$leaf_name});
	}
	if (defined $leaves_names{$leaf_name}) {
	    push @$ordered_species, $leaves_names{$leaf_name};
	}
    }
    $newick_species_tree = $species_tree->newick_format("simple");
    return ($newick_species_tree, $ordered_species);
}

#
#Create EPO README file
#
sub _create_specific_epo_readme {
    my ($self, $compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree) = @_;

    my $species = $self->param('species');
    my @tree_list = split(//, $newick_species_tree);

    open FILE, ">$filename" || die ("Cannot open $filename");
    print FILE "This directory contains all the " . @$species_set . " way Enredo-Pecan-Ortheus (EPO) multiple
alignments corresponding to the Release " . $schema_version . " of Ensembl (see
http://www.ensembl.org for further details and credits about the
Ensembl project).\n\n";
    print FILE "The set of species is:\n";
    foreach my $species (@$species_set) {
	printf FILE "%s (%s)\n", $species->name, $species->assembly;
    }
    print FILE "\nThe species tree was:\n";
    foreach my $token (@tree_list) {
	print FILE "$token";
	print FILE "\n" if ($token eq "(");
	print FILE "\n" if ($token eq ",");
    }

    print FILE "\n\nFirst, Enredo is used to build a set of co-linear regions between the
genomes. Then Pecan aligns these whole set of sequences. Last, Ortheus
uses the Pecan alignments to infer the ancestral sequences.

Enredo is a graph-based method. The initial graph is built from a mapping of
a set of anchors on every genome. Note that each anchor can map several times
on a single genome. Enredo uses this information to define co-linear regions.
Read more about Enredo: http://www.ebi.ac.uk/~jherrero/downloads/enredo/

Pecan is a global multiple sequence alignment program that makes practical
the probabilistic consistency methodology for significant numbers of
sequences of practically arbitrary length. As input it takes a set of
sequences and a phylogenetic tree. The parameters and heuristics it employs
are highly user configurable, it is written entirely in Java and also
requires the installation of Exonerate.
Read more about Pecan: http://www.ebi.ac.uk/~bjp/pecan/

Ortheus is a probabilistic method for the inference of ancestor (a.k.a tree)
alignments. The main contribution of Ortheus is the use of a phylogenetic
model incorporating gaps to infer insertion and deletion events.
Read more about Ortheus: http://www.ebi.ac.uk/~bjp/ortheus/

Alignments are grouped by $species chromosome. Each file contains up to " . $self->param('split_size') . " alignments. The file named *.others_*." . $self->param('format') . ".gz contain alignments that do not
include any $species region. Alignments containing duplications in $species are
dumped once per duplicated segment.\n";

    if ($self->param('format') eq "emf") {
	print FILE "An emf2maf parser is available with the ensembl compara API, in the
scripts/dumps directory. Alternatively you can download it using the web CVS
frontend: http://cvs.sanger.ac.uk/cgi-bin/viewcvs.cgi/*checkout*/ensembl-compara/scripts/dumps/emf2maf.pl\n";
    }

    print FILE "Please note that MAF format does not support conservation scores.\n";

    close(FILE);
}

#
#Create EPO_LOW_COVERAGE README file
#
sub _create_specific_epo_low_coverage_readme {
    my ($self, $compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree, $mlss_adaptor) = @_;

    my $species = $self->param('species');
    my @tree_list = split(//, $newick_species_tree);
    my $high_coverage_mlss = $mlss_adaptor->fetch_by_dbID($self->param('high_coverage_mlss_id'));
    my $high_coverage_species_set = $high_coverage_mlss->species_set_obj->genome_dbs;

    my %high_coverage_species;
    foreach my $species (@$high_coverage_species_set) {
	$high_coverage_species{$species} = 1;
    }

    open FILE, ">$filename" || die ("Cannot open $filename");
    print FILE "This directory contains all the " . @$species_set . "way Enredo-Pecan-Ortheus (EPO) multiple\n";
    print FILE "alignments corresponding to the Release ". $schema_version . "of Ensembl (see 
http://www.ensembl.org for further details and credits about the
Ensembl project).\n\n";

    print FILE "The core set of species used for the " . @$high_coverage_species_set . "-way EPO alignment:\n";

    #species_set is ordered so want to print out lists in the correct
    #phylogenetic order
    foreach my $species (@$species_set) {
	if (defined($high_coverage_species{$species})) {
	    printf FILE "%s (%s)\n", $species->name, $species->assembly;
	}
    }

    print FILE "\n\nAnd the extra 2X genomes are:\n";
    foreach my $species (@$species_set) {
	if (!defined $high_coverage_species{$species}) {
	    printf FILE "%s (%s)\n", $species->name, $species->assembly;
	}
    }

    print FILE "\nThe species tree we used is:\n";
    foreach my $token (@tree_list) {
	print FILE "$token";
	print FILE "\n" if ($token eq "(");
	print FILE "\n" if ($token eq ",");
    }
    
    print FILE "\n\nTo build the " . @$high_coverage_species_set . "-way alignment, first, Enredo is used to build a set of
co-linear regions between the genomes and then Pecan aligns these regions. 
Next, Ortheus uses the Pecan alignments to infer the ancestral sequences. Then
the 2X genomes were mapped to the $species sequence using their pairwise 
BlastZ-net alignments. Any insertions in the 2X genomes were removed (ie no 
gaps were introduced into the $species sequence). 

Enredo is a graph-based method. The initial graph is built from a mapping of 
a set of anchors on every genome. Note that each anchor can map several times 
on a single genome. Enredo uses this information to define co-linear regions. 
Read more about Enredo: http://www.ebi.ac.uk/~jherrero/downloads/enredo/

Pecan is a global multiple sequence alignment program that makes practical 
the probabilistic consistency methodology for significant numbers of 
sequences of practically arbitrary length. As input it takes a set of 
sequences and a phylogenetic tree. The parameters and heuristics it employs 
are highly user configurable, it is written entirely in Java and also 
requires the installation of Exonerate. 
Read more about Pecan: http://www.ebi.ac.uk/~bjp/pecan/

Ortheus is a probabilistic method for the inference of ancestor (a.k.a tree) 
alignments. The main contribution of Ortheus is the use of a phylogenetic 
model incorporating gaps to infer insertion and deletion events. 
Read more about Ortheus: http://www.ebi.ac.uk/~bjp/ortheus/

GERP scores the conservation of each position in the alignment and defines
constrained elements based on these conservation scores.
Read more about Gerp: http://mendel.stanford.edu/SidowLab/downloads/gerp/index.html
Alignments are grouped by $species chromosome. Each file contains up to " . $self->param('split_size') . " 
alignments. The file named *.others_*." . $self->param('format') . ".gz contain alignments that do 
not include any $species region.\n";

    if ($self->param('format') eq "emf") {
	print FILE "An emf2maf parser is available with the ensembl compara API, in the scripts/dumps 
directory. Alternatively you can download it using the web CVS frontend:
http://cvs.sanger.ac.uk/cgi-bin/viewcvs.cgi/*checkout*/ensembl-compara/scripts/dumps/emf2maf.pl\n";
    }

    close FILE;
}

#
#Create PECAN README file
#
sub _create_specific_pecan_readme {
    my ($self, $compara_dba, $mlss, $species_set, $filename, $schema_version, $newick_species_tree) = @_;

    my @tree_list = split(//, $newick_species_tree);

    open FILE, ">$filename" || die ("Cannot open $filename");
    print FILE "This directory contains all the " . @$species_set . " way Pecan multiple alignments corresponding\n";
    print FILE "to Release " . $schema_version . " of Ensembl (see http://www.ensembl.org for further details\n";
    print FILE "and credits about the Ensembl project).\n\n";
    print FILE  "The set of species was:\n";
    foreach my $species (@$species_set) {
	printf FILE "%s (%s)\n", $species->name, $species->assembly;
    }
    print FILE "\nThe species tree was:\n";
    foreach my $token (@tree_list) {
	print FILE "$token";
	print FILE "\n" if ($token eq "(");
	print FILE "\n" if ($token eq ",");
    }

    print FILE "\n\nFirst, Mercator is used to build a synteny map between the genomes and then
Pecan builds alignments in these syntenic regions. Pecan is a global multiple 
sequence alignment program that makes practical the probabilistic consistency 
methodology for significant numbers of sequences of practically arbitrary 
length. As input it takes a set of sequences and a phylogenetic tree. The 
parameters and heuristics it employs are highly user configurable, it is 
written entirely in Java and also requires the installation of Exonerate. 
Read more about Pecan: http://www.ebi.ac.uk/~bjp/pecan/. 

Alignments are grouped by human chromosome. Each file contains up to " . $self->param('split_size') . "
alignments. The file named *.others_*." . $self->param('format') . ".gz contain alignments that do 
not include any human region.\n";

    if ($self->param('format') eq "emf") {
	print FILE "An emf2maf parser is available with the ensembl compara API, in the scripts/dumps
directory. Alternatively you can download it using the web CVS frontend:
http://cvs.sanger.ac.uk/cgi-bin/viewcvs.cgi/*checkout*/ensembl-compara/scripts/dumps/emf2maf.pl\n";
    }

    print FILE "Please note that MAF format does not support conservation scores.\n";
    close FILE;

}

1;
