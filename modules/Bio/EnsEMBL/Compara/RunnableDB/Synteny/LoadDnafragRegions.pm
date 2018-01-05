
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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Synteny::BuildSynteny

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::LoadDnafragRegions;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::IO qw/iterate_file/;

use Bio::EnsEMBL::Compara::SyntenyRegion;
use Bio::EnsEMBL::Compara::DnaFragRegion;


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $synteny_mlss_id = $self->param_required('synteny_mlss_id');
    my $synteny_mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($synteny_mlss_id);
    $self->param('synteny_mlss', $synteny_mlss);

    my $existing_synteny_regions = $self->compara_dba->get_SyntenyRegionAdaptor->fetch_all_by_MethodLinkSpeciesSet($synteny_mlss);
    die "There are already some SyntenyRegions for the MLSS $synteny_mlss_id in the database\n" if scalar(@$existing_synteny_regions);
}


sub run {
    my $self = shift;

    my $synteny_mlss_id = $self->param('synteny_mlss_id');
    my $qy_species = $self->param_required('ref_species');
    my ($gdb1, $gdb2) = @{$self->param('synteny_mlss')->species_set->genome_dbs()};
    my ($qy_gdb, $tg_gdb) = $gdb1->name eq $qy_species ? ($gdb1,$gdb2) : ($gdb2,$gdb1);

    my $dfa = $self->compara_dba->get_DnaFragAdaptor();
    my $sra = $self->compara_dba->get_SyntenyRegionAdaptor();

    my $line_number = 1;
    my $filename = $self->param_required('input_file');
    iterate_file($filename, sub {
        my $line= shift;
        chomp $line;
        if ($line =~ /^(\S+)\t.*\t.*\t(\d+)\t(\d+)\t.*\t(-1|1)\t.*\t(\S+)\t(\d+)\t(\d+)$/) {#####This will need to be changed
            my ($qy_chr,$qy_start,$qy_end,$rel,$tg_chr,$tg_start,$tg_end) = ($1,$2,$3,$4,$5,$6,$7);

            my $qy_dnafrag = $dfa->fetch_by_GenomeDB_and_name($qy_gdb, $qy_chr);
            my $tg_dnafrag = $dfa->fetch_by_GenomeDB_and_name($tg_gdb, $tg_chr);

            # print STDERR "1: $qy_chr, 2: $tg_chr, qy_end: " .$qy_dnafrag->end.", tg_end: ". $tg_dnafrag->end."\n";

            my $qy_dfr = new Bio::EnsEMBL::Compara::DnaFragRegion(
                -DNAFRAG_ID     => $qy_dnafrag->dbID,
                -DNAFRAG_START  => $qy_start,
                -DNAFRAG_END    => $qy_end,
                -DNAFRAG_STRAND => 1,
            );
            my $tg_dfr = new Bio::EnsEMBL::Compara::DnaFragRegion(
                -DNAFRAG_ID     => $tg_dnafrag->dbID,
                -DNAFRAG_START  => $tg_start,
                -DNAFRAG_END    => $tg_end,
                -DNAFRAG_STRAND => $rel,
            );

            my $sr = new Bio::EnsEMBL::Compara::SyntenyRegion(
                -REGIONS                     => [$qy_dfr, $tg_dfr],
                -METHOD_LINK_SPECIES_SET_ID  => $synteny_mlss_id,
            );

            $sra->store($sr);

            print STDERR "synteny region line number $line_number loaded\n";
            $line_number++;
        } else {
            die "The input file '$filename' has a wrong format at line $line_number\n";
        }
    });
}


1;
