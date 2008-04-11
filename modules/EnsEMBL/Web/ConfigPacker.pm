package EnsEMBL::Web::ConfigPacker;

use strict;
use EnsEMBL::Web::ConfigPacker_base;

our @ISA = qw(EnsEMBL::Web::ConfigPacker_base);

sub _munge_databases {
  my $self = shift;
  my %tables = qw(
    core ENSEMBL_DB
    cdna ENSEMBL_CDNA
    vega ENSEMBL_VEGA
    otherfeatures ENSEMBL_OTHERFEATURES
  );
  foreach my $db ( keys %tables ) {
    $self->_summarise_core_tables( $db, $tables{$db} );
  }

  $self->_summarise_variation_db(        );
  $self->_summarise_funcgen_db(          );
}

sub _munge_databases_multi {
  my $self = shift;
  $self->_summarise_website_db(    );
  $self->_summarise_compara_db(    );
  $self->_summarise_ancestral_db(  );
  $self->_summarise_go_db(         );
}

sub _munge_config_tree {
  my $self = shift;
#---------- munge the results obtained from the database queries
#           of the website and the meta tables
  $self->_munge_meta(       );
  $self->_munge_website(    );

#---------- parse the DAS configuration
  $self->_configure_das(    );
#---------- parse the BLAST configuration
  $self->_configure_blast(  );
}

sub _munge_config_tree_multi {
}


sub _summarise_generic {
  my( $self, $db_name, $dbh ) = @_;
  my $t_aref = $dbh->selectall_arrayref( 'show table status' );
#---------- Table existance and row counts
  foreach my $row ( @$t_aref ) {
    $self->db_details($db_name)->{'tables'}{$row->[0]}{'rows'} = $row->[4];
  }
#---------- Meta coord system table...
  if( $self->_table_exists( $db_name, 'meta_coord' )) {
    $t_aref = $dbh->selectall_arrayref(
      'select table_name,max_length
         from meta_coord'
    );
    foreach my $row ( @$t_aref ) {
      $self->db_details($db_name)->{'tables'}{$row->[0]}{'coord_systems'}{$row->[1]}=$row->[2];
    }
  }
#---------- Meta table (everything except patches)
  if( $self->_table_exists( $db_name, 'meta' ) ) {
    $t_aref  = $dbh->selectall_arrayref(
      'select meta_key,meta_value,meta_id 
         from meta
        where meta_key != "patch"
        order by meta_key, meta_id'
    );
    my $hash = {};
    foreach my $r( $t_aref) {
      push @{ $hash->{$_->[0]} }, $_->[1];
    }
    $self->db_details($db_name)->{'meta_info'} = $hash;
  }
}

sub _summarise_core_tables {
  my $self   = shift;
  my $db_key = shift;
  my $db_name = shift;
  my $dbh    = $self->db_connect( $db_name );
  return unless $dbh;
  push @{ $self->db_tree->{'core_like_databases'} }, $db_name;

  $self->_summarise_generic( $db_name, $dbh );
##
## Grab each of the analyses - will use these in a moment...
##
  my $t_aref = $dbh->selectall_arrayref(
    'select a.analysis_id, a.logic_name,
            ad.display_label, ad.description,
            ad.displayable, ad.web_data
       from analysis a left join analysis_description as ad on a.analysis_id=ad.analysis_id'
  );
   my $analysis = {};
   foreach my $a_aref (@$t_aref) {
    $analysis->{ $a_aref->[0] } = {
      'logic_name'  => $a_aref->[1],
      'name'        => $a_aref->[2],
      'description' => $a_aref->[3],
      'displayable' => $a_aref->[4],
      'web_data'    => $a_aref->[5]?eval($a_aref->[5]):{}
    };
  }
## 
## Let us get analysis information about each feature type...
##
  foreach my $table ( qw(
	dna_align_feature protein_align_feature simple_feature
        protein_feature marker_feature qtl_feature
	repeat_feature ditag_feature oligo_feature
        transcript gene prediction_transcript unmapped_object
  )) {
    my $res_aref = $dbh->selectall_arrayref(
      "select analysis_id,count(*) from $table group by analysis_id"
    );
    foreach my $T ( @$res_aref ) {
      my $a_ref = $analysis->{$T->[0]};
      warn "Missing analysis entry $table - $T->[0]\n" unless $a_ref;
      my $value = {
        'name'  => $a_ref->{'name'},
        'desc'  => $a_ref->{'description'},
        'disp'  => $a_ref->{'displayable'},
        'web'   => $a_ref->{'web_data'},
        'count' => $T->[1]
      };
      $self->db_details($db_name)->{'tables'}{$table}{'analyses'}{$a_ref->{'logic_name'}} = $value;
    }
  }

#---------- Additional queries - by type...

#
# * Check to see if we have any interpro? - not sure why may drop...
#

#
# * Oligos
#
  $t_aref = $dbh->selectall_arrayref(
    'select aa.name, count(*)
       from oligo_array as aa, oligo_probe as ap
      where aa.oligo_array_id = ap.oligo_array_id
      group by aa.name'
  );
  foreach my $row (@$t_aref) {
    $self->db_details($db_name)->{'tables'}{'oligo_probe'}{'arrays'}{$row->[0]} = $row->[1];
  }
#  
# * Repeats
#
  $t_aref = $dbh->selectall_arrayref(
    'select rf.analysis_id,rc.repeat_type, count(*)
       from repeat_consensus as rc, repeat_feature as rf
      where rc.repeat_consensus_id = rf.repeat_consensus_id
      group by analysis_id, repeat_type'
  );
  foreach my $row (@$t_aref) {
    my $a_ref = $analysis->{$row->[0]};
    $self->db_details($db_name)->{'tables'}{'repeat_feature'}{'analyses'}{$a_ref->{'logic_name'}}{'types'}{$row->[1]} = $row->[2];
  }
#
# * Misc-sets
#
  $t_aref = $dbh->selectall_arrayref(
    'select ms.code, ms.name, ms.description, count(*) as N, ms.max_length
       from misc_set as ms, misc_feature_misc_set as mfms
      where mfms.misc_set_id = ms.misc_set_id
      group by ms.misc_set_id'
  );
  $self->db_details($db_name)->{'tables'}{'misc_features'}{'sets'} = { map {
    ( $_->[0] => { 'name' => $_->[1], 'desc' => $_->[2], 'count' => $_->[3], 'max_length' => $_->[4] })
  } @$t_aref };

#---------- Now for the core only ones.......

  if( $db_name eq 'core' ) {
#
# * Co-ordinate systems..
#
    my $row =  $dbh->selectrow_arrayref(
      'select sr.name, sr.length 
         from seq_region as sr, coord_system as cs 
        where cs.name in( "chromosome", "group" ) and
              cs.coord_system_id = sr.coord_system_id 
        order by sr.length
         desc limit 1'
    );
    if( $row ) {
      $self->db_tree->{'MAX_CHR_NAME'  } = $row->[0];
      $self->db_tree->{'MAX_CHR_LENGTH'} = $row->[1];
    } else {
      $self->db_tree->{'MAX_CHR_NAME'  } = undef;
      $self->db_tree->{'MAX_CHR_LENGTH'} = undef;
    }
  }

#----------
  $dbh->disconnect();
}

sub _summarise_variation_db {
  my $self    = shift;
  my $db_name = 'ENSEMBL_VARIATION';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  my $t_aref = $dbh->selectall_arrayref( 'select name from source' );
#---------- Add in information about the sources from the source table
  $self->db_details($db_name)->{'sources'} = map { ($_,1) } @$t_aref;
  $dbh->disconnect();
}

sub _summarise_funcgen_db {
  my $self    = shift;
  my $db_name = 'ENSEMBL_FUNCGEN';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
#---------- Currently have to do nothing additional to this!!
  $dbh->disconnect();
}

#========================================================================#
# The following functions munge the multi-species databases              #
# * note that summarise_website_db actually stores the results of some   #
#   of its queries in the species trees not in the multi tree!           #
#========================================================================#
sub _summarise_website_db {
  my $self    = shift;
  my $db_name = 'ENSEMBL_WEBSITE';
  my $dbh     = $self->db_connect( $db_name );

#---- Species info for current ensembl
  my $t_aref = $dbh->selectall_arrayref(
    'select s.name, s.species_id, s.vega, rs.assembly_name, rs.pre_name
       from release_species as rs, species as s
      where s.species_id = rs.species_id and rs.release_id = ?',
    {}, $SiteDefs::ENSEMBL_VERSION
  );
  foreach my $row ($t_aref) {
    $self->db_tree->{'species_info'}{$row->[0]} = {
      'id'       => $row->[1],
      'vega'     => $row->[2],
      'assembly' => $row->[3],
      'pre'      => $row->[4]
    };
  }
#---- Species info for previous ensembl
  my $t_aref = $dbh->selectall_arrayref(
    'select s.name, rs.assembly_name, rs.pre_name
       from release_species as rs, species as s
      where s.species_id = rs.species_id and rs.release_id = ?',
    {}, $SiteDefs::ENSEMBL_VERSION - 1
  );
  foreach my $row ($t_aref) {
    $self->db_tree->{'species_info'}{$row->[0]}{'prev_assembly'} = $row->[1];
    $self->db_tree->{'species_info'}{$row->[0]}{'prev_pre'}      = $row->[2];
  }
#---- Species info for all archived ensembls..
  $t_aref = $dbh->selectall_arrayref(
    'select s.name, rs.release_id, rs.assembly_name, e.archive, e.online
       from release_species as rs, species as s, ens_release as e
      where s.species_id = rs.species_id and rs.release_id = e.release_id and
            rs.assembly_name != ""
      order by s.name, rs.release_id'
  );
  foreach my $row ($t_aref) {
    $self->db_tree->{'archive_info'}{$row->[0]}{'assemblies'}{$row->[1]} = $row->[2];
    $self->db_tree->{'archive_info'}{$row->[0]}{'online'}{    $row->[1]} = $row->[3] if $row->[4] eq 'Y';
  }
}

sub _summarise_compara_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_COMPARA';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
#---------- Lets first look at all the multiple alignments
  my $res_aref = $dbh->selectall_arrayref( ## We've done the DB hash...So lets get on with the multiple alignment hash;
    'select ml.class, ml.type, gd.name, mlss.name,
            mlss.method_link_species_set_id, ss.species_set_id
	     from method_link ml, method_link_species_set mlss,
            genome_db gd, species_set ss 
      where mlss.method_link_id = ml.method_link_id and
            mlss.species_set_id=ss.species_set_id and 
            ss.genome_db_id = gd.genome_db_id and
            ml.class in (
              "ConservationScore.conservation_score",
              "GenomicAlignBlock.constrained_element",
              "GenomicAlignBlock.multiple_alignment",
              "GenomicAlignTree.tree_alignment"
            )
  ');
  my $constrained_elements = {};
  my %valid_species = map {($_,1)} keys %{$self->full_tree};
  foreach my $row (@$res_aref) {
    my( $class, $type, $species, $name, $id, $species_set_id ) =
      ($row->[0], uc($row->[1]), $row->[2], $row->[3], $row->[4], $row->[5]);
    my $KEY = 'ALIGNMENTS';
    if( $class =~ /ConservationScore/ ||
        $type =~ /CONSERVATION_SCORE/ ) {
      $KEY = "CONSERVATION_SCORES";
      $name = "Conservation scores";
    } elsif( $class =~ /constrained_element/ ||
             $type =~ /CONSTRAINED_ELEMENT/ ) {
      $KEY = "CONSTRAINED_ELEMENTS";
      $constrained_elements->{$species_set_id} = $id;
      $name = "Constrained elements";
    } elsif( $class =~ /tree_alignment/ or
             $type  =~ /ORTHEUS/ ) {
      unless( exists $self->db_tree->{$KEY}{$id} ) {
        $self->db_tree->{$KEY}{$id}{'species'}{"Ancestral_sequences"}=1;
      }
    }
    $species =~ tr/ /_/;
    $self->db_tree->{$KEY}{$id}{'id'}                = $id;
    $self->db_tree->{$KEY}{$id}{'name'}              = $name;
    $self->db_tree->{$KEY}{$id}{'type'}              = $type;
    $self->db_tree->{$KEY}{$id}{'class'}             = $class;
    $self->db_tree->{$KEY}{$id}{'species_set_id'}    = $species_set_id;
    $self->db_tree->{$KEY}{$id}{'species'}{$species} = 1;
  }
  foreach my $species_set_id (keys %$constrained_elements) {
    my $constr_elem_id = $constrained_elements->{$species_set_id};
    foreach my $id (keys %{$self->db_tree->{'ALIGNMENTS'}}) {
      if( $self->db_tree->{'ALIGNMENTS'}{$id}{'species_set_id'} == $species_set_id) {
        $self->db_tree->{'ALIGNMENTS'}{$id}{'constrained_element'} = $constr_elem_id;
      }
    }
  }

  $res_aref = $dbh->selectall_arrayref(q(
    select meta_key, meta_value FROM meta where meta_key LIKE "gerp_%"
  ));
  foreach my $row ( @$res_aref ) {
    my ($meta_key, $meta_value) = ($row->[0], $row->[1]);
    my ($conservation_score_id) = $meta_key =~ /gerp_(\d+)/;
    next if (!$conservation_score_id);
    $self->db_tree->{'ALIGNMENTS'}{$meta_value}{'conservation_score'} = $conservation_score_id;
  }
  my %sections = (
    'SYNTENY'             => 'GENE_MULTIPLE',
    'ENSEMBL_ORTHOLOGUES' => 'GENE',
    'HOMOLOGOUS_GENE'     => 'GENE',
    'HOMOLOGOUS'          => 'GENE',
  );
# We've done the DB hash... So lets get on with the DNA, SYNTENY and GENE hashes;
  $res_aref = $dbh->selectall_arrayref(qq(
    select ml.type, gd1.name, gd2.name
      from genome_db gd1, genome_db gd2, species_set ss1, species_set ss2,
           method_link ml, method_link_species_set mls1,
           method_link_species_set mls2
     where mls1.method_link_species_set_id = mls2.method_link_species_set_id and
           ml.method_link_id = mls1.method_link_id and
           ml.method_link_id = mls2.method_link_id and
           gd1.genome_db_id != gd2.genome_db_id and
           mls1.species_set_id = ss1.species_set_id and
           mls2.species_set_id = ss2.species_set_id and
           ss1.genome_db_id = gd1.genome_db_id and
           ss2.genome_db_id = gd2.genome_db_id
  ));
  my $self_comparisons = 0;
		  #see if there are any intraspecies alignments (ie a self compara)
  my $res_aref_2 = $dbh->selectall_arrayref(qq(
    select ml.type, gd.name, gd.name, count(*) as count
      from method_link_species_set as mls, method_link as ml,
           species_set as ss, genome_db as gd 
     where mls.species_set_id = ss.species_set_id and
           ss.genome_db_id = gd.genome_db_id and
           mls.method_link_id = ml.method_link_id and
           ml.type not like '%PARALOGUES'
     group by mls.method_link_species_set_id, mls.method_link_id
    having count = 1
  ));
  foreach my $row (@$res_aref_2) {
    $self_comparisons = 1;
    push @$res_aref,$row;
  }
  foreach my $row ( @$res_aref ) {
    my ( $species1, $species2 ) = ( $row->[1], $row->[2] );
    $species1 =~ tr/ /_/;
    $species2 =~ tr/ /_/;
    my $KEY = $sections{uc($row->[0])} || uc( $row->[0] );
    $self->db_tree->{$KEY}{$species1}{$species2} = $valid_species{ $species2 };
  }
#		  &eprof_dump(\*STDERR);		
  $dbh->disconnect();
}

sub _summarise_ancestral_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_DB';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _summarise_go_db {
  my $self = shift;
  my $db_name = 'ENSEMBL_GO';
  my $dbh     = $self->db_connect( $db_name );
  return unless $dbh;
  $self->_summarise_generic( $db_name, $dbh );
  $dbh->disconnect();
}

sub _munge_meta {
}

sub _munge_website {
}

sub _configure_das {
}

sub _configure_blast {
}

1;
