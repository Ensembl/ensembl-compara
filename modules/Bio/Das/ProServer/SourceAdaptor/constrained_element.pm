#
# Bio::Das::ProServer::SourceAdaptor::constrained_element
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::constrained_element - Extension of the ProServer for e! constrained elements

=head1 INHERITANCE

This module inherits attributes and methods from Bio::Das::ProServer::SourceAdaptor

=head1 DAS CONFIGURATION FILE

There are some specific parameters for this module you can use in the DAS server configuration file

=head2 registry

Your registry configuration file to connect to the compara database

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
  transport       = ensembl
  adaptor         = compara
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Mus musculus
  analysis        = BLASTZ_NET
  description     = Human-mouse blastz-net alignments

  [Mmus-Hsap-blastznet]
  transport       = ensembl
  adaptor         = compara
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  database        = ensembl-compara-41
  this_species    = Mus musculus
  other_species   = Homo sapiens
  analysis        = BLASTZ_NET
  description     = Mouse-Human blastz-net alignments

  [primates-mlagan-hs]
  transport       = ensembl
  adaptor         = compara
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Pan troglodytes, Macaca mulatta
  analysis        = MLAGAN
  description     = Primates Mlagan alignments on human

  [human-platypus-bz]
  transport       = ensembl
  adaptor         = compara
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Ornithorhynchus anatinus
  analysis        = BLASTZ_NET
  description     = Human-platypus blastz alignments


=cut

package Bio::Das::ProServer::SourceAdaptor::constrained_element;

use strict;
use Bio::EnsEMBL::Registry;
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

}

sub build_features
{
    my ($self, $opts) = @_;

    my $db      = "Bio::EnsEMBL::Registry";
    $db->no_version_check(1);
    my $dbname  = $self->config()->{'database'};

    #need to put adaptors here and not in init 
    my $mlss_adaptor =
        $db->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet') or
            die "can't get $dbname, 'compara', 'MethodLinkSpeciesSet'\n";

    my $ce_adaptor =
        $db->get_adaptor($dbname, 'compara', 'ConstrainedElement') or
            die "can't get $dbname, 'compara', 'ConstrainedElement'\n";

    my $species  = $self->config()->{'this_species'};
    my $slice_adaptor =
        $db->get_adaptor($species, 'core', 'Slice') or
            die "can't get $species, 'core', 'Slice'\n";  

    my $genome_db_adaptor =
        $db->get_adaptor($dbname, 'compara', 'GenomeDB') or
            die "can't get $dbname, 'compara', 'GenomeDB'\n";

    my $genomedbs = $genome_db_adaptor->fetch_all();

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
    $self->{'compara'}->{'link_template'} = $link_template;

    my $stored_max_alignment_length;

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

    ## Fetch the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
    my $method_link_species_set;
    $method_link_species_set =
        $mlss_adaptor->fetch_by_method_link_type_GenomeDBs(
            $method_link, [$species1_genome_db, @other_species_genome_dbs]);

    ##Fetch the Bio::EnsEMBL::Slice object
    my $slice = $slice_adaptor->fetch_by_region(undef, $chr1, $start1, $end1);

     #Fetch constrained elements
    my $constrained_elements = $ce_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);

    ## Build the results array
    my $results = ();

    foreach my $elem (@$constrained_elements) {
	my $label = "Constrained elements";
	my $start_pos = $elem->slice->start + $elem->start - 1;
	my $end_pos = $elem->slice->start + $elem->end - 1;
	my $ori = "+";
	my $score = $elem->score;

	my $id = "cons_elems " . $elem->dbID;

	#my $note = "Score $score p_value " . $elem->p_value . " " . $elem->taxonomic_level;
	my $note = "Score $score p_value " . $elem->p_value;

	push @$results, {
			  'id'    => $id,
			  'label' => $label,
			  'method'=> $method_link_species_set->method_link_type,
			  'start' => $start_pos,
			  'end'   => $end_pos,
			  'ori'   => $ori,
			  'score' => $score,
			  'note'  => $note,
			  'typecategory' => 'Constrained element',
			  'type'  => $method_link_species_set->name,
			 };

    }

    return @$results;
}

sub das_stylesheet
{
    my $self = shift;

    return <<EOT;
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
    <STYLESHEET version="1.0">
        <CATEGORY id="Constrained element">
            <TYPE id="default">
                <GLYPH>
                    <BOX>
                        <FGCOLOR>blue</FGCOLOR>
                        <BGCOLOR>aquamarine2</BGCOLOR>
                        <BUMP>no</BUMP>
                        <LABEL>no</LABEL>
                    </BOX>
                </GLYPH>
            </TYPE>
        </CATEGORY>
    </STYLESHEET>
</DASSTYLE>
EOT
}

1;
