package Bio::Das::ProServer::SourceAdaptor::compara;

use strict;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::DnaDnaAlignFeature;

use base qw( Bio::Das::ProServer::SourceAdaptor );

sub init
{
    my ($self) = @_;

    $self->{'capabilities'} = { 'features' => '1.0' };

#    my $registry = $ENV{'PWD'}.'/reg.pl';
    my $registry = $self->config()->{'registry'};
    unless (defined $registry) {
      die "registry not defined\n";
    }
    print "registry: $registry\n";
    if (not $Bio::EnsEMBL::Registry::registry_register->{'seen'}) {
        Bio::EnsEMBL::Registry->load_all($registry);
    }

    my $db      = "Bio::EnsEMBL::Registry";
    my $dbname  = $self->config()->{'database'};

    $db->no_version_check(1);

    $self->{'compara'}{'meta_con'} =
        $db->get_adaptor($dbname, 'compara', 'MetaContainer') or
            die "no metadbadaptor:$dbname, 'compara','MetaContainer' \n";

    $self->{'compara'}{'mlss_adaptor'} =
        $db->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet') or
            die "can't get $dbname, 'compara', 'MethodLinkSpeciesSet'\n";

    $self->{'compara'}{'dnafrag_adaptor'} =
        $db->get_adaptor($dbname, 'compara', 'DnaFrag') or
            die "can't get $dbname, 'compara', 'DnaFrag'\n";

    $self->{'compara'}{'genomic_align_block_adaptor'} =
        $db->get_adaptor($dbname, 'compara', 'GenomicAlignBlock') or
            die "can't get $dbname, 'compara', 'GenomicAlignBlock'\n";

    $self->{'compara'}{'genomic_align_adaptor'} =
        $db->get_adaptor($dbname, 'compara', 'GenomicAlign') or
            die "can't get $dbname, 'compara', 'GenomicAlign'\n";

    $self->{'compara'}{'genomic_align_group_adaptor'} =
        $db->get_adaptor($dbname, 'compara', 'GenomicAlignGroup') or
            die "can't get $dbname, 'compara', 'GenomicAlignGroup'\n";


    my $genome_db_adaptor =
        $db->get_adaptor($dbname, 'compara', 'GenomeDB') or
            die "can't get $dbname, 'compara', 'GenomeDB'\n";

    $self->{'compara'}{'genomedbs'} = $genome_db_adaptor->fetch_all();
}

sub build_features
{
    my ($self, $opts) = @_;

    my $daschr      = $opts->{'segment'} || return ( );
    my $dasstart    = $opts->{'start'} || return ( );
    my $dasend      = $opts->{'end'} || return ( );

    my $species1    = $self->config()->{'this_species'};
    my $species2    = $self->config()->{'other_species'};
    my $chr1        = $daschr;
    my $start1      = $dasstart;
    my $end1        = $dasend;

    my $method_link = $self->config()->{'analysis'};

    my $link_template = $self->config()->{'link_template'} || 'http://www.ensembl.org/';

    $link_template .= '%s/contigview?chr=%s;vc_start=%d;vc_end=%d';

    my $meta_con    = $self->{'compara'}{'meta_con'};

    my $stored_max_alignment_length;

    my $values = $meta_con->list_value_by_key("max_alignment_length");

    if(@$values) {
        $stored_max_alignment_length = $values->[0];
    }

    my $mlss_adaptor                = $self->{'compara'}{'mlss_adaptor'};
    my $dnafrag_adaptor             = $self->{'compara'}{'dnafrag_adaptor'};
    my $genomic_align_block_adaptor =
        $self->{'compara'}{'genomic_align_block_adaptor'};
    my $genomic_align_adaptor       =
        $self->{'compara'}{'genomic_align_adaptor'};
    my $genomic_align_group_adaptor =
        $self->{'compara'}{'genomic_align_group_adaptor'};

    my $genomedbs = $self->{'compara'}{'genomedbs'};
    my $sps1_gdb;
    my $sps2_gdb;

    foreach my $gdb (@$genomedbs){
        if ($gdb->name eq $species1) {
            $sps1_gdb = $gdb;
        } elsif($gdb->name eq $species2) {
            $sps2_gdb = $gdb;
        }
    }

    unless(defined $sps2_gdb && defined $sps1_gdb) {
        die "no $species1 or no $species2 -- check spelling\n";
    }

    my $dnafrag1 =
        $dnafrag_adaptor->fetch_by_GenomeDB_and_name($sps1_gdb, $chr1);

    return ( ) if (!defined $dnafrag1);

    my $method_link_species_set =
        $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
            $method_link, [$sps1_gdb, $sps2_gdb]);

    my $genomic_align_blocks =
        $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set, $dnafrag1, $start1, $end1);

    my @results = ();
    my $ensspecies = $species2;
    $ensspecies =~ tr/ /_/;

    my $grouping = $self->config()->{'group'} || 'by_group_chr';

    foreach my $gab (@$genomic_align_blocks) {
        $genomic_align_block_adaptor->retrieve_all_direct_attributes($gab);

        my $genomic_align1          = $gab->reference_genomic_align();
        my $other_genomic_aligns    =
            $gab->get_all_non_reference_genomic_aligns();

        my $genomic_align2          = $other_genomic_aligns->[0];

        my ($start2,$end2,$name2,$group2) = (
            $genomic_align2->dnafrag_start(),
            $genomic_align2->dnafrag_end(),
            $genomic_align2->dnafrag->name(),
            defined $genomic_align2->genomic_align_groups->[0]?$genomic_align2->genomic_align_groups->[0]->dbID():undef
        );

        my $group;
        my $grouplabel;

        if ($grouping eq 'by_group_chr') {
            $group = sprintf('%s:%s', $group2, $name2);
            $grouplabel = sprintf('group %s, chr %s', $group2, $name2);
        } elsif ($grouping eq 'by_group') {
            $group = sprintf('%s', $group2);
            $grouplabel = sprintf('group %s', $group2);
        } elsif ($grouping eq 'by_chr') {
            $group = sprintf('%s', $name2);
            $grouplabel = sprintf('chr %s', $name2);
        }
        if (defined $group && defined $grouplabel) {
          push @results, {
                          'id'    => $gab->dbID,
                          'source'=> 'Compara',
                          'type'  => 'alignment',
                          'method'=> $method_link,
                          'start' => $genomic_align1->dnafrag_start,
                          'end'   => $genomic_align1->dnafrag_end,
                          'ori'   => ($genomic_align1->dnafrag_strand() == 1 ? '+' : '-'),
                          'score' => $gab->score(),
                          'note'  => sprintf('%d%% identity with %s:%d,%d in %s',
                                             $gab->perc_id?$gab->perc_id:0,
                                             $name2, $start2, $end2,
                                             $species2),
                          'link'  => sprintf($link_template,
                                             $ensspecies, $name2, $start2, $end2),
                          'linktxt'   => sprintf("%s:%d,%d in %s",
                                                 $name2, $start2, $end2, $species2),
                          'group' => $group,
                          'grouplabel'=> $grouplabel,
                         }
        } else {
          push @results, {
                          'id'    => $gab->dbID,
                          'type'  => $method_link,
                          'method'=> 'Compara',
                          'start' => $genomic_align1->dnafrag_start,
                          'end'   => $genomic_align1->dnafrag_end,
                          'ori'   => ($genomic_align1->dnafrag_strand() == 1 ? '+' : '-'),
                          'score' => $gab->score(),
                          'note'  => sprintf('%d%% identity with %s:%d,%d in %s',
                                             $gab->perc_id?$gab->perc_id:0,
                                             $name2, $start2, $end2,
                                             $species2),
                          'link'  => sprintf($link_template,
                                             $ensspecies, $name2, $start2, $end2),
                          'linktxt'   => sprintf("%s:%d,%d in %s",
                                                 $name2, $start2, $end2, $species2),
                         }
        }
    }

    return @results;
}

1;
