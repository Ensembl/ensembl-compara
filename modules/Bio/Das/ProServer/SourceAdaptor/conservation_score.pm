#
# Bio::Das::ProServer::SourceAdaptor::conservation_score
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::conservation_score - Extension of the ProServer for e! conservation scores

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
You can add more than one other species separated by commas.

=head2 analysis

The method_link_type. This defines the type of score. E.g. GERP_CONSERVATION_SCORE
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

  [conservation_score]
  registry        = /home/foo/ProServer/eg/reg.pl
  state           = on
  adaptor         = compara
  database        = ensembl-compara-41
  this_species    = Homo sapiens
  other_species   = Mus musculus, Rattus norvegicus, Canis familiaris, Gallus gallus, Bos taurus, Monodelphis domestica
  analysis        = GERP_CONSTRAINED_ELEMENT
  description     = 7 way mlagan alignment
  group_type      = default

=cut

package Bio::Das::ProServer::SourceAdaptor::conservation_score;

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
    my $meta_con =
        $db->get_adaptor($dbname, 'compara', 'MetaContainer') or
            die "no metadbadaptor:$dbname, 'compara','MetaContainer' \n";

    my $mlss_adaptor =
        $db->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet') or
            die "can't get $dbname, 'compara', 'MethodLinkSpeciesSet'\n";

    my $cs_adaptor =
        $db->get_adaptor($dbname, 'compara', 'ConservationScore') or
            die "can't get $dbname, 'compara', 'ConservationScore'\n";

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

    my $stored_max_alignment_length;

    my $values = $meta_con->list_value_by_key("max_alignment_length");

    if(@$values) {
        $stored_max_alignment_length = $values->[0];
    }

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

    #Fetch conservation scores
    my $conservation_scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);

    ## Build the results array
    my @results = ();

    foreach my $score (@$conservation_scores) {

	unless (defined $score->diff_score) {
	    next;
	}

	#my $id = $score->genomic_align_block_id;

	my $id = $score->genomic_align_block_id ."_" . $score->position;
	my $label = "Conservation scores";

	# note will contain expected and observed scores and window size 
	my $note = sprintf("Expected %.3f Observed %.3f Diff %.3f Window Size %d Max", $score->expected_score, $score->observed_score, $score->diff_score, $score->window_size); 

	#my $start_pos = $start1 + $score->position;
	#my $end_pos = $start1 + $score->position + $score->window_size;
	my $start_pos = $start1 + $score->position - 1;
	my $end_pos = $start_pos + $score->window_size - 1;

	my $new_score = $score->diff_score()*-1;
	push @results, {
	    'id'    => $id,
	    'label' => $label,
	    'method'=> $method_link,
	    'start' => $start_pos,
	    'end'   => $end_pos,
	    'ori'   => '+',
	    'score' => $new_score,
	    'note'  => $note,
	    'typecategory' => 'Conservation scores',
	    'type'  => 'histogram'
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
        <CATEGORY id="Conservation scores">
           <TYPE id="histogram"><GLYPH><HISTOGRAM>
              <MIN>-3</MIN>
              <MAX>3</MAX>
              <HEIGHT>100</HEIGHT>
              <STEPS>50</STEPS>
              <COLOR1>red</COLOR1>
              <COLOR2>yellow</COLOR2>
              <COLOR3>blue</COLOR3>
            </HISTOGRAM></GLYPH></TYPE>
        </CATEGORY>
    </STYLESHEET>
</DASSTYLE>
EOT
}

1;
