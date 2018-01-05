=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon

=head1 DESCRIPTION

This RunnableDB calculates the dynamics of a GeneTree family (based on the tree obtained and the CAFE software) in terms of gains losses per branch tree. It needs a CAFE-compliant species tree.

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneGainLossCommon;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub load_split_genes {
    my ($self) = @_;
    my $member_id_to_gene_split_id;
    my $gene_split_id_to_member_ids;
    my $sql = "SELECT seq_member_id, gene_split_id FROM split_genes";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    my $n_split_genes = 0;
    while (my ($seq_member_id, $gene_split_id) = $sth->fetchrow_array()) {
        $n_split_genes++;
        $member_id_to_gene_split_id->{$seq_member_id} = $gene_split_id;
        push @{$gene_split_id_to_member_ids->{$gene_split_id}}, $seq_member_id;
    }
    if ($n_split_genes == 0) {
        $self->param('no_split_genes', 1);
    }
    $self->param('member_id_to_gene_split_id', $member_id_to_gene_split_id);
    $self->param('gene_split_id_to_member_ids', $gene_split_id_to_member_ids);

    return;
}

sub filter_split_genes {
    my ($self, $all_members) = @_;
    my $member_id_to_gene_split_id = $self->param('member_id_to_gene_split_id');
    my $gene_split_id_to_member_ids = $self->param('gene_split_id_to_member_ids');

    my %members_to_delete = ();

    my @filtered_members;
    for my $member (@$all_members) {
        my $seq_member_id = $member->dbID;
        if ($members_to_delete{$seq_member_id}) {
            delete $members_to_delete{$seq_member_id};
            print STDERR "$seq_member_id has been removed because of split_genes filtering\n" if ($self->debug());
            next;
        }
        if (exists $member_id_to_gene_split_id->{$seq_member_id}) {
            my $gene_split_id = $member_id_to_gene_split_id->{$seq_member_id};
            my @member_ids_to_delete = grep {$_ ne $seq_member_id} @{$gene_split_id_to_member_ids->{$gene_split_id}};
            for my $new_member_to_delete (@member_ids_to_delete) {
                $members_to_delete{$new_member_to_delete} = 1;
            }
        }
        push @filtered_members, $member;
    }
    if (scalar keys %members_to_delete) {
        my $msg = "Still have some members to delete!: \n";
        $msg .= Dumper \%members_to_delete;
        die $msg;
    }

    return [@filtered_members];
}

sub get_all_trees {
    my ($self, $species) = @_;
    my $adaptor = $self->param('adaptor');
    my $all_trees = $adaptor->fetch_all(-tree_type => 'tree', -clusterset_id => 'default');
    my %stn_id_lookup = map {$_->genome_db_id => $_->node_id} @{ $self->param('cafe_tree')->get_all_leaves };
    print STDERR scalar @$all_trees, " trees to process\n" if ($self->debug());
    return sub {
        # $self is the outer var 
        my $tree = shift @$all_trees;
        return undef unless ($tree);
        my $root_id = $tree->root_id;
        my $name = $root_id;
        my $full_tree_members = $tree->get_all_leaves();
        my $tree_members = $self->param('no_split_genes') ? $full_tree_members : $self->filter_split_genes($full_tree_members);

        my %species = map {$_ => 0} @$species;
        for my $member (@$tree_members) {
            $species{$stn_id_lookup{$member->genome_db_id}}++ if exists $stn_id_lookup{$member->genome_db_id};
        }

        $tree->release_tree();
        return ($name, $root_id, \%species);
    };
}


sub get_normalized_table {
    my ($self, $table, $n) = @_;
    my ($header, @table) = split /\n/, $table;
    my @species = split /\t/, $header;

    ## n_headers method has to be defined in the sub class,
    ## allowing for differentiation between 2-column names (ids, and names)
    ## as is needed by CAFE and 1-column names needed by badiRate
    my @headers = @species[0..$self->n_headers-1];
    @species = @species[$self->n_headers..$#species];

    my $data;
    my $fams;

    for my $row (@table) {
        chomp $row;
        my @flds = split/\t/, $row;
        push @$fams, [@flds];
        for my $i ($self->n_headers..$#flds) {
            push @{$data->{$species[$i-$self->n_headers]}}, $flds[$i];
        }
    }
    my $means_a;
    for my $sp (@species) {
        my $mean = mean(@{$data->{$sp}});
        my $stdev = stdev($mean, @{$data->{$sp}});
        #  $means->{$sp} = {mean => $mean, stdev => $stdev};
        push @$means_a, {mean => $mean, stdev => $stdev};
    }

    my $newTable = join "\t", @headers, @species;
    $newTable .= "\n";
    my $nfams = 0;
    for my $famdata (@$fams) {
        my $v = 0;
        for my $i (0 .. $#species) {
            my $vmean = $means_a->[$i]->{mean};
            my $vstdev = $means_a->[$i]->{stdev};
            my $vreal = $famdata->[$i+2];

            $v++ if (($vreal > ($vmean - $vstdev/$n)) && ($vreal < ($vmean + $vstdev/$n)));
        }
        if ($v == scalar(@species)) {
            $newTable .= join "\t", @$famdata;
            $newTable .= "\n";
            $nfams++;
        }
    }
    print STDERR "$nfams families written in tbl file\n" if ($self->debug());
    return $newTable;
}

sub mean {
    my (@items) = @_;
    return sum(@items) / (scalar @items);
}

sub sum {
    my (@items) = @_;
    my $res;
    for my $next (@items) {
        die unless (defined $next);
        $res += $next;
    }
    return $res;
}

sub stdev {
    my ($mean, @items) = @_;
    my $var = 0;
    my $n_items = scalar @items;
    for my $item (@items) {
        $var += ($mean - $item) * ($mean - $item);
    }
    return sqrt($var / (scalar @items));
}

1;
