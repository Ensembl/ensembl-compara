=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a gene tree as input,
run any arbitrary command on it, and store the result back.

The Runnable requires
 - gene_tree_id: the root_id of the gene tree on which to run the command
 - cmd: the command to run

The command has to be defined using the following parameters:
 - #gene_tree_file#: current gene tree
 - #species_tree_file#: the reference species tree
 - #alignment_file#: the alignment file
 - #tag:XYZ#: the value of the tag "XYZ" of the gene-tree

By default, the standard output of the job is captured and is expected
to be a Newick/NHX tree. This is overriden by any of the parameters:
 - output_file: file to read instead of the standard output
 - read_tags: if 1, the output is parsed as lines of "key: value" that
              are stored as tags. Otherwise, it is assumed to be a tree

Other parameters:
 - check_split_genes: whether we want to group the split genes in fake gene entries
 - minimum_genes: minimum number of genes on which to run the command
 - maximum_genes: maximum number of genes on which to run the command
 - command_tag_runtime: gene-tree tag to store the runtime of the command
 - cdna: 1 if the alignment file contains the CDS sequences (otherwise: the protein sequences)
 - ryo_species_tree: Roll-Your-Own format string for the species-tree

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Utils::Cigars;

use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;
use File::Glob;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub param_defaults {
    return {
        'cdna'              => 1,
        'check_split_genes' => 1,
        'read_tags'         => 0,
        'do_transactions'   => 1,
        'ryo_species_tree'  => '%{o}',
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

    $self->param('gene_tree', $gene_tree);
    $self->param('mlss_id',   $gene_tree->method_link_species_set_id);

    $gene_tree->preload();
    $gene_tree->print_tree(10) if($self->debug);

    # default parameters
    $self->param('minimum_genes', 0   ) unless $self->input_job->param_exists('minimum_genes');
    $self->param('maximum_genes', 1e9 ) unless $self->input_job->param_exists('maximum_genes');
    $self->param('split_genes',   {}  );
    $self->param('command_run',   0   );
}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;
}


sub write_output {
    my $self = shift;

    if ($self->param('command_run')) {
        if ($self->param('read_tags')) {
            $self->store_tags($self->param('gene_tree'), $self->param('tags'));
        } else {
            $self->store_genetree($self->param('gene_tree'), []);
        }
        $self->param('gene_tree')->store_tag($self->param('command_tag_runtime'), $self->param('runtime_msec')) if $self->input_job->param_exists('command_tag_runtime');
    }
}


sub post_cleanup {
  my $self = shift;

  if(my $gene_tree = $self->param('gene_tree')) {
    $gene_tree->release_tree;
    $self->param('gene_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub run_generic_command {
    my $self = shift;

    my $gene_tree = $self->param('gene_tree');
    my $newick;

    my $starttime = time()*1000;

    my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($gene_tree);
    $self->param('alignment_file', $input_aln);

    warn sprintf("Number of elements: %d leaves, %d split genes\n", scalar(@{$gene_tree->get_all_Members}), scalar(keys %{$self->param('split_genes')}));

    my $number_actual_genes = scalar(@{$gene_tree->get_all_Members}) - scalar(keys %{$self->param('split_genes')});

    if (($number_actual_genes < $self->param('minimum_genes')) or ($number_actual_genes > $self->param('maximum_genes'))) {
        $self->warning("There are $number_actual_genes genes in this tree. Not running the command");
        return;
    }

    $self->param('gene_tree_file', $self->get_gene_tree_file($self->param('gene_tree')));
    $self->param('species_tree_file', $self->get_species_tree_file());

    foreach my $tag ($gene_tree->get_all_tags()) {
        $self->param("tag:$tag", $gene_tree->get_value_for_tag($tag));
    }

    my $cmd = sprintf('cd %s; %s', $self->worker_temp_directory, $self->param_required('cmd'));
    my $run_cmd = $self->run_command($cmd);
    if ($run_cmd->exit_code) {
        $self->throw(sprintf('"$full_cmd" resulted in an error code="%d. stderr is:"', $run_cmd->cmd, $run_cmd->exit_code, $run_cmd->err));
    }

    my $output = $self->param('output_file') ? $self->_slurp($self->param('output_file')) : $run_cmd->out;

    if ($self->param('read_tags')) {
        $self->param('tags', $self->get_tags($output));
    } else {
        #parse the tree into the data structure:
        $self->parse_newick_into_tree( $output, $self->param('gene_tree') );
    }

    $self->param('command_run', 1);
    $self->param('runtime_msec', time()*1000-$starttime);
}


sub get_gene_tree_file {
    my ($self, $gene_tree) = @_;

    # horrible hack: we replace taxon_id with species_tree_node_id
    foreach my $leaf (@{$gene_tree->root->get_all_leaves}) {
        $leaf->taxon_id($leaf->genome_db->species_tree_node_id);
    }
    my $gene_tree_file = sprintf('%s/gene_tree_%d.nhx', $self->worker_temp_directory, $gene_tree->root_id);
    open( my $speciestree, '>', $gene_tree_file) or die "Could not open '$gene_tree_file' for writing : $!";
    print $speciestree $gene_tree->newick_format('ryo','%{-m}%{"_"-x}:%{d}');;
    close $speciestree;

    return $gene_tree_file;
}

sub _load_species_tree_string_from_db {
    my ($self) = @_;
    my $species_tree = $self->param('gene_tree')->species_tree($self->param('label') || 'default');
    $species_tree->attach_to_genome_dbs();
    $self->param('species_tree_string', $species_tree->root->newick_format('ryo', $self->param('ryo_species_tree')))
}



sub get_tags {
    my ($self, $output) = @_;

    my %tags = ();
    foreach my $line (split /\n/, $output) {
        chomp $line;
        if ($line =~ /([^:]*):(.*)/) {
            $tags{$1} = $2;
        }
    }
    return \%tags;
}


sub store_tags {
    my ($self, $gene_tree, $tags) = @_;
    while ( my ($tag, $value) = each %$tags ) {
        $gene_tree->store_tag($tag, $value);
    }
}




1;
