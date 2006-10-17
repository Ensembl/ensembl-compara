#
# Bio::Das::ProServer::SourceAdaptor::compara
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::compara - Extension of the ProServer for e! genomic alignments

=head1 INHERITANCE

This module inherits attributes and methods from Bio::Das::ProServer::SourceAdaptor

=head1 DAS CONFIGURATION FILE

There are some specific parameters for this module you can use in the DAS server configuration file

=head2 registry

Your registryu configuration file to connect to the compara database

=head2 database

The species name in your Registry configuration file.

=head2 this_species

The main species. Features will be shown for this species.

=head2 other_species

The other species. This DAS track will show alignments between this_species and other_species.
You will have to skip this one for self-alignments. You can add more than one other species
separated by comas.

=head2 analysis

The method_link_type. This defines the type of alignments. E.g. TRANSLATED_BLAT, BLASTZ_NET...
See perldoc Bio::EnsEMBL::Compara::MethodLinkSpeciesSet for more details about the
method_link_type

=head2 group_type

The type of grouping used. The alignments can be grouped in the database. The DB supports
several grouping schema, each of them has a name. By default (in the e! API and in this
module), the group_type is "default". You can choose another group_type using this parameter.

=head2 Example

=head3 registry configuration file

  use strict;
  use Bio::EnsEMBL::Utils::ConfigRegistry;
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

  new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
      -host => 'ensembldb.ensembl.org',
      -user => 'anonymous',
      -port => 3306,
      -species => 'ensembl-compara-41',
      -dbname => 'ensembl_compara_41');


=head3 DAS server configuration file

  [general]
  hostname    = ecs4b.internal.sanger.ac.uk
  prefork     = 6
  maxclients  = 100
  port        = 9013

  [Hsap-Mmus-blastznet]
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  adaptor         = compara
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Mus musculus
  analysis        = BLASTZ_NET
  description     = Human-mouse blastz-net alignments
  group_type      = default

  [Mmus-Hsap-blastznet]
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  adaptor         = compara
  database        = ensembl-compara-41
  this_species    = Mus musculus
  other_species   = Homo sapiens
  analysis        = BLASTZ_NET
  description     = Mouse-Human blastz-net alignments
  group_type      = default

  [primates-mlagan-hs]
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  adaptor         = compara
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Pan troglodytes, Macaca mulatta
  analysis        = MLAGAN
  description     = Primates Mlagan alignments on human


=cut

package Bio::Das::ProServer::SourceAdaptor::compara;

use strict;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception;

use base qw( Bio::Das::ProServer::SourceAdaptor );

sub init
{
    my ($self) = @_;

    $self->{'capabilities'} = { 'features' => '1.0',
                                'stylesheet' => '1.0' };

    my $registry = $self->config()->{'registry'};
    unless (defined $registry) {
     throw("registry not defined\n");
    }

    if (not $Bio::EnsEMBL::Registry::registry_register->{'seen'}) {
        Bio::EnsEMBL::Registry->load_all($registry);
    }

    my $db      = "Bio::EnsEMBL::Registry";
    $db->no_version_check(1);
    my $dbname  = $self->config()->{'database'};

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
    my @other_species = split(/\s*\,\s*/, $self->config()->{'other_species'});
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
    my $species1_genome_db;
    my @other_species_genome_dbs;

    ## Get the Bio::EnsEMBL::Compara::GenomeDB object for the primary species
    foreach my $this_genome_db (@$genomedbs){
      if ($this_genome_db->name eq $species1) {
        $species1_genome_db = $this_genome_db;
      }
    }
    if (!defined($species1_genome_db)) {
      die "No species called $species1 in the database -- check spelling\n";
    }

    ## Get the Bio::EnsEMBL::Compara::GenomeDB objects for the remaining species
    foreach my $this_other_species (@other_species) {
      my $this_other_genome_db;
      foreach my $this_genome_db (@$genomedbs){
        if ($this_genome_db->name eq $this_other_species) {
          $this_other_genome_db = $this_genome_db;
          last;
        }
      }
      if (!defined($this_other_genome_db)) {
        die "No species called $this_other_species in the database -- check spelling\n";
      }
      push(@other_species_genome_dbs, $this_other_genome_db);
    }

    ## Fetch the Bio::EnsEMBL::Compara::DnaFrag object for the query segment
    my $dnafrag1 =
        $dnafrag_adaptor->fetch_by_GenomeDB_and_name($species1_genome_db, $chr1);

    return ( ) if (!defined $dnafrag1);

    ## Fetch the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
    my $method_link_species_set;
    $method_link_species_set =
        $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
            $method_link, [$species1_genome_db, @other_species_genome_dbs]);

    ## Fetch the alginments on the query segment
    my $genomic_align_blocks =
        $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set, $dnafrag1, $start1, $end1);

    ## Get the start and end coordinates for each group. The coordinates are indexed
    ## by species_name and chr_name to ensure the continuity in the coordinates.
    my $group_type = $self->config()->{'group_type'};
    my $group_coordinates;
    foreach my $gab (@$genomic_align_blocks) {
      my $genomic_align = $gab->reference_genomic_align;
      next if(!$genomic_align->genomic_align_group_by_type($group_type));
      my $group_id = $genomic_align->genomic_align_group_by_type($group_type)->dbID;
      foreach my $genomic_align2 (@{$gab->get_all_non_reference_genomic_aligns()}) {
        my $species_name = $genomic_align2->dnafrag->genome_db->name;
        my $chr_name = $genomic_align2->dnafrag->name;
        my $chr_start = $genomic_align2->dnafrag_start;
        my $chr_end = $genomic_align2->dnafrag_end;
        if (!defined($group_coordinates->{$group_id}->{$species_name}->{$chr_name})) {
          $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{start} = $chr_start;
          $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{end} = $chr_end;
        } else {
          if ($chr_start < $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{start}) {
            $chr_start = $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{start};
          }
          if ($chr_end > $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{end}) {
            $chr_end = $group_coordinates->{$group_id}->{$species_name}->{$chr_name}->{end};
          }
        }
      }
    }

    ## Build the results array
    my @results = ();

    foreach my $gab (@$genomic_align_blocks) {
      $genomic_align_block_adaptor->retrieve_all_direct_attributes($gab);

      my $genomic_align1 = $gab->reference_genomic_align();
      my $other_genomic_aligns = $gab->get_all_non_reference_genomic_aligns();
      my $group_id = $genomic_align1->genomic_align_group_by_type($group_type)?
          $genomic_align1->genomic_align_group_by_type($group_type)->dbID:undef;

      my $id = $gab->dbID;
      my $label;
      my $group_label;
      # note will contain the perc_id if it exists
      my $note = $gab->perc_id?$gab->perc_id.'% identity':undef;

      ## Set link, linktxt, grouplink, grouplinktxt
      my @links;
      my @link_txts;
      my @group_links;
      my @group_link_txts;
      foreach my $this_genomic_align (@{$gab->get_all_non_reference_genomic_aligns()}) {
        my ($species2, $name2, $start2, $end2, $group2) = (
            $this_genomic_align->dnafrag->genome_db->name(),
            $this_genomic_align->dnafrag->name(),
            $this_genomic_align->dnafrag_start(),
            $this_genomic_align->dnafrag_end(),
            $this_genomic_align->genomic_align_group_by_type($group_type),
          );
        my $ens_species = $species2;
        $ens_species =~ s/ /_/g;
        push(@links, sprintf($link_template, $ens_species, $name2, $start2, $end2, $species2));
        push(@link_txts, sprintf("%s:%d,%d in %s", $name2, $start2, $end2, $species2));
        next if (!defined($group_id));
        my $group_start2 = $group_coordinates->{$group_id}->{$species2}->{$name2}->{start};
        my $group_end2 = $group_coordinates->{$group_id}->{$species2}->{$name2}->{end};
        $group_label = "$name2: $group_start2-$group_end2";
        push(@group_links, sprintf($link_template, $ens_species, $name2,
            $group_start2, $group_end2));
        push(@group_link_txts, sprintf("%s:%d,%d in %s", $name2,
            $group_start2, $group_end2, $species2));
      }

      if (@other_species_genome_dbs < 2) {
        ## for pairwise and self-alignments
        my $ga = $gab->get_all_non_reference_genomic_aligns()->[0];
        $label = $ga->dnafrag->name.": ".$ga->dnafrag_start."-".$ga->dnafrag_end;
      } else {
        ## for multiple alignments
        $group_label = $group_id?"group $group_id":undef;
      }

      push @results, {
          'id'    => $id,
          'label' => $label,
          'method'=> $method_link,
          'start' => $genomic_align1->dnafrag_start,
          'end'   => $genomic_align1->dnafrag_end,
          'ori'   => ($genomic_align1->dnafrag_strand() == 1 ? '+' : '-'),
          'score' => $gab->score(),
          'note'  => $note,
          'link'  => [@links],
          'linktxt' => [@link_txts],
          'group' => $group_id,
          'grouplabel'=> $group_label,
          'grouplink' => [@group_links],
          'grouplinktxt' => [@group_link_txts],
          'typecategory' => 'Whole genome alignment',
          'type'  => 'Compara'
        };
    }

    return @results;
}

sub das_stylesheet
{
    my $self = shift;

    return <<EOT;
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
    <STYLESHEET version="1.0">
        <CATEGORY id="Whole genome alignment">
            <TYPE id="Compara">
                <GLYPH>
                    <BOX>
                        <FGCOLOR>blue</FGCOLOR>
                        <BGCOLOR>aquamarine2</BGCOLOR>
                    </BOX>
                </GLYPH>
            </TYPE>
        </CATEGORY>
    </STYLESHEET>
</DASSTYLE>
EOT
}

1;
